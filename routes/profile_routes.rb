# routes/profile_routes.rb
# User profile and saved memes management

module Routes
  module ProfileRoutes
    def self.registered(app)
      # User profile page with ENHANCED ENGAGEMENT STATS
      app.get "/profile" do
        headers 'Cache-Control' => 'no-store, private'
        require_auth!
        user_id = current_user_id
        raw_page = params[:saved_page] || '1'
        halt 400, 'Saved page must be a positive integer.' unless raw_page.is_a?(String) && raw_page.match?(/\A[1-9][0-9]{0,8}\z/)
        @saved_page = raw_page.to_i
        raw_liked_page = params[:liked_page] || '1'
        halt 400, 'Likes page must be a positive integer.' unless raw_liked_page.is_a?(String) && raw_liked_page.match?(/\A[1-9][0-9]{0,8}\z/)
        @liked_page = raw_liked_page.to_i
        @saved_query = params[:saved_q] || ''
        halt 400, 'Saved search must be text up to 200 characters.' unless @saved_query.is_a?(String) && @saved_query.length <= 200
        @saved_query = @saved_query.strip
        @saved_query_suffix = @saved_query.empty? ? '' : "&saved_q=#{Rack::Utils.escape(@saved_query)}"
      
        # Wrap Redis or DB calls in safe error handling
        begin
          @user = get_user(user_id)
          
          # Ensure @user is not nil - provide default structure
          if @user.nil?
            halt 500, "User not found in database"
          end
          
          # Get user's saved memes from saved_memes table
          @saved_memes = begin
            @saved_count = UserService.get_saved_memes_count(user_id)
            search_sql = @saved_query.empty? ? '' : " AND (POSITION(LOWER(?) IN LOWER(COALESCE(meme_title, ''))) > 0 OR POSITION(LOWER(?) IN LOWER(COALESCE(meme_subreddit, ''))) > 0)"
            search_args = @saved_query.empty? ? [] : [@saved_query, @saved_query]
            @saved_matches = if @saved_query.empty?
              @saved_count
            else
              MemeExplorer::App::DB.execute("SELECT COUNT(*) AS count FROM saved_memes WHERE user_id = ?#{search_sql}", [user_id, *search_args]).first['count'].to_i
            end
            @saved_pages = [(@saved_matches / 24.0).ceil, 1].max
            @saved_page = [@saved_page, @saved_pages].min
            results = MemeExplorer::App::DB.execute(
              "SELECT id, meme_url, meme_title, meme_subreddit, saved_at FROM saved_memes WHERE user_id = ?#{search_sql} ORDER BY saved_at DESC, id DESC LIMIT ? OFFSET ?",
              [user_id, *search_args, 24, (@saved_page - 1) * 24]
            ) || []
            results.map { |row| row.transform_keys(&:to_s) }
          rescue => e
            AppLogger.error("Error fetching saved memes: #{e.message}")
            @saved_load_error = true
            []
          end
          
          # Get user's liked memes from user_liked_memes table (source of truth)
          @liked_memes = begin
            count_row = MemeExplorer::App::DB.execute('SELECT COUNT(*) AS count FROM user_liked_memes WHERE user_id = ?', [user_id]).first
            @liked_count = count_row['count'].to_i
            @liked_pages = [(@liked_count / 24.0).ceil, 1].max
            @liked_page = [@liked_page, @liked_pages].min
            results = MemeExplorer::App::DB.execute(
              "SELECT meme_url, created_at as liked_at FROM user_liked_memes WHERE user_id = ? ORDER BY created_at DESC, id DESC LIMIT ? OFFSET ?",
              [user_id, 24, (@liked_page - 1) * 24]
            ) || []
            results.map { |row| row.transform_keys(&:to_s) }
          rescue => e
            AppLogger.error("Error fetching liked memes: #{e.message}")
            @liked_load_error = true
            []
          end
          
          # Get comprehensive engagement stats from EngagementService
          @engagement_stats = ::EngagementService.user_stats(
            user_id: user_id,
            db: ::DB
          )
      
        rescue => e
          # Log the error and return proper error response
          AppLogger.error("Profile Error: #{e.class}: #{e.message}")
          AppLogger.info("backtrace", lines: e.backtrace.join("\n"))
          halt 500, "Unable to load your profile right now. Please try again later."
        end
      
        # Count stats (with fallback to engagement service)
        
        # Add comprehensive stats for display
        @total_xp = @engagement_stats[:total_xp] || 0
        @level = @engagement_stats[:level] || 1
        @weekly_rank = @engagement_stats[:weekly_rank]
        @current_streak = @engagement_stats[:current_streak] || 0
      
        erb :profile
      end

      # Save a meme to user's collection with FULL INTEGRATION
      app.post "/api/save-meme" do
        unless logged_in?
          request.body.rewind
          candidate = begin
            request.media_type == 'application/json' ? JSON.parse(request.body.read) : params
          rescue JSON::ParserError
            nil
          end
          id = candidate['content_id'] if candidate.is_a?(Hash)
          session.delete(:pending_save)
          if id.is_a?(String) && id.match?(/\A[a-f0-9]{64}\z/)
            begin
              session[:pending_save] = { 'id' => id, 'expires_at' => Time.now.to_i + 1800 } if MemeIdentityService.find(id)
            rescue => e
              AppLogger.warn('Pending save lookup unavailable', error: e.class.name)
            end
          end
          halt 401, { error: 'Sign in to save', pending_save: !!session[:pending_save] }.to_json
        end
        require_auth!

        payload = params
        if request.media_type == 'application/json'
          begin
            request.body.rewind
            payload = JSON.parse(request.body.read)
            halt 400, { error: 'JSON object required' }.to_json unless payload.is_a?(Hash)
          rescue JSON::ParserError
            halt 400, { error: 'Invalid JSON' }.to_json
          end
        end
        url = payload['url'] || payload[:url]
        title = payload['title'] || payload[:title] || 'Unknown'
        subreddit = payload['subreddit'] || payload[:subreddit] || 'unknown'

        # BUG FIX: `unless url` only rejects nil/false - an empty string
        # ('') is truthy in Ruby, so `POST /api/save-meme` with `url: ''`
        # sailed straight through to EngagementService.track_save with a
        # blank meme_url instead of being rejected as the missing-URL case
        # it actually is.
        halt 400, { error: "URL required" }.to_json if url.to_s.strip.empty?

        # Use EngagementService for comprehensive tracking with gamification, leaderboard, and metrics
        result = ::EngagementService.track_save(
          user_id: current_user_id,
          meme_url: url,
          title: title,
          subreddit: subreddit,
          saved_now: true,
          session: session,
          db: ::DB
        )

        # BUG FIX: this used to hardcode `saved: true` regardless of
        # `result[:success]` - meaning if EngagementService.track_save
        # failed (as it always did until the saved_memes column-name fix
        # in lib/services/engagement_service.rb), the response still
        # claimed success and the client had no way to know the save
        # never actually happened.
        response = {
          success: result[:success],
          saved: result[:success] ? true : false,
          message: result[:success] ? "Meme saved" : "Failed to save meme"
        }
        if result[:success]
          begin
            saved_row = UserService.is_meme_saved?(current_user_id, url)
            response[:saved_id] = saved_row['id'].to_i if saved_row
          rescue => e
            # Saving already succeeded; missing navigation metadata must not
            # misrepresent that mutation as a failed save.
            AppLogger.warn('Saved detail identity unavailable', error: e.class.name)
          end
        end
        
        # Include XP and level-up info if available
        if result[:xp_awarded] && result[:xp_awarded] > 0
          response[:xp_awarded] = result[:xp_awarded]
          response[:level_up] = result[:level_up]
          response[:new_level] = result[:new_level] if result[:level_up]
          AppLogger.info("✅ [XP] Awarded #{result[:xp_awarded]} XP for save")
        end

        content_type :json
        response.to_json
      end

      # Remove a meme from user's collection with FULL INTEGRATION
      app.post "/api/unsave-meme" do
        require_auth!

        payload = params
        if request.media_type == 'application/json'
          begin
            request.body.rewind
            payload = JSON.parse(request.body.read)
            halt 400, { error: 'JSON object required' }.to_json unless payload.is_a?(Hash)
          rescue JSON::ParserError
            halt 400, { error: 'Invalid JSON' }.to_json
          end
        end
        url = payload['url'] || payload[:url]
        # Same empty-string bug fix as /api/save-meme above.
        halt 400, { error: "URL required" }.to_json if url.to_s.strip.empty?

        # Use EngagementService for comprehensive tracking
        result = ::EngagementService.track_save(
          user_id: current_user_id,
          meme_url: url,
          saved_now: false,
          session: session,
          db: ::DB
        )

        content_type :json
        {
          success: result[:success],
          unsaved: !!result[:success],
          message: result[:success] ? 'Meme unsaved' : 'Could not remove meme'
        }.to_json
      end

      # View a specific saved meme
      app.get "/saved/:id" do
        headers 'Cache-Control' => 'no-store, private'
        # FIX: IDOR vulnerability - require authentication and authorization
        require_auth!
        
        saved_id = params[:id].to_i
        saved_meme = MemeExplorer::App::DB.execute(
          "SELECT * FROM saved_memes WHERE id = ? AND user_id = ?", 
          [saved_id, current_user_id]
        ).first

        halt 404, "Meme not found" unless saved_meme

        @meme = {
          "title" => saved_meme["meme_title"],
          "url" => saved_meme["meme_url"],
          "subreddit" => saved_meme["meme_subreddit"]
        }
        @image_src = saved_meme["meme_url"]
        @likes = get_meme_likes(@image_src)
        @saved_meme_id = saved_id
        page = params[:saved_page].to_s
        page = '1' unless page.match?(/\A[1-9][0-9]{0,8}\z/)
        @saved_return_path = "/profile?saved_page=#{page}#saved-card-#{saved_id}"
        query = params[:saved_q]
        if query.is_a?(String) && query.length <= 200 && !query.strip.empty?
          @saved_return_path = "/profile?saved_page=#{page}&saved_q=#{Rack::Utils.escape(query.strip)}#saved-card-#{saved_id}"
        end

        erb :saved_meme
      end
    end
  end
end
