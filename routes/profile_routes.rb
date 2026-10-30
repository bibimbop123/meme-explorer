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
        @history_cleared = session.delete(:history_cleared_notice) == true
        @preferences_reset = session.delete(:preferences_reset_notice) == true
      
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
            liked_rows = results.map { |row| row.transform_keys(&:to_s) }
            if liked_rows.any?
              begin
                urls = liked_rows.map { |r| r['meme_url'] }.compact.uniq
                stats_rows = MemeExplorer::App::DB.execute(
                  'SELECT url, title, subreddit FROM meme_stats WHERE url IN (?)',
                  [urls]
                ) || []
                stats_by_url = stats_rows.each_with_object({}) do |r, h|
                  row = r.transform_keys(&:to_s)
                  h[row['url']] = row
                end
                catalog_rows = MemeExplorer::App::DB.execute(
                  'SELECT media_url, id FROM meme_catalog WHERE media_url IN (?) AND removed_at IS NULL',
                  [urls]
                ) || []
                catalog_by_url = catalog_rows.each_with_object({}) do |r, h|
                  row = r.transform_keys(&:to_s)
                  h[row['media_url']] = row['id']
                end
                liked_rows.each do |r|
                  cid = catalog_by_url[r['meme_url']]
                  r['viewer_path'] = "/meme/#{cid}" if cid && cid.match?(/\A[a-f0-9]{64}\z/)
                  meta = stats_by_url[r['meme_url']]
                  next unless meta
                  r['meme_title'] = meta['title'] if meta['title'] && !meta['title'].to_s.strip.empty? && meta['title'] != 'Unknown'
                  r['meme_subreddit'] = meta['subreddit'] if meta['subreddit'] && !meta['subreddit'].to_s.strip.empty? && meta['subreddit'] != 'unknown'
                end
              rescue => e
                AppLogger.warn("Liked metadata enrichment skipped: #{e.class}")
              end
            end
            liked_rows
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
        @liked = (EngagementService.user_liked?(user_id: current_user_id, meme_url: @image_src) rescue false)
        @saved_meme_id = saved_id
        if (saved_sub = saved_meme["meme_subreddit"].to_s.strip.downcase).match?(/\A[a-z0-9_]{1,32}\z/)
          session[:liked_subreddits] ||= {}
          session[:liked_subreddits][saved_sub] = [session[:liked_subreddits][saved_sub].to_f, 1.3].max.round(2)
        end
        page = params[:saved_page].to_s
        page = '1' unless page.match?(/\A[1-9][0-9]{0,8}\z/)
        @saved_return_path = "/profile?saved_page=#{page}#saved-card-#{saved_id}"
        query = params[:saved_q]
        if query.is_a?(String) && query.length <= 200 && !query.strip.empty?
          @saved_return_path = "/profile?saved_page=#{page}&saved_q=#{Rack::Utils.escape(query.strip)}#saved-card-#{saved_id}"
        end

        erb :saved_meme
      end

      # Self-serve browsing history reset on /profile
      app.post "/profile/clear-history" do
        headers 'Cache-Control' => 'no-store, private'
        require_auth!
        MemeExplorer::ViewingHistoryService.clear_history(feed_session_id)
        MemeExplorer::ViewingHistoryService.clear_history("user:#{current_user_id}") if current_user_id
        session[:history_cleared_notice] = true
        redirect "/profile", 303
      end

      # Self-serve reset of learned account & session subreddit preferences
      app.post "/profile/reset-preferences" do
        headers 'Cache-Control' => 'no-store, private'
        require_auth!
        MemeExplorer::App::DB.execute('DELETE FROM user_subreddit_preferences WHERE user_id = ?', [current_user_id])
        session.delete(:liked_subreddits)
        session[:preferences_reset_notice] = true
        redirect "/profile", 303
      end

      # Remove a liked meme directly from /profile
      app.post "/profile/unlike" do
        headers 'Cache-Control' => 'no-store, private'
        require_auth!
        url = params[:url].to_s.strip
        if url.empty? || url.bytesize > 4096
          halt 400, json_request? ? { error: 'URL required' }.to_json : 'URL required'
        end

        result = EngagementService.set_like(
          user_id: current_user_id,
          meme_url: url,
          desired: false,
          session: session,
          db: ::DB
        )

        if json_request?
          content_type :json
          status(result[:success] ? 200 : 503)
          return result.to_json
        end

        liked_page = params[:liked_page].to_s.match?(/\A[1-9][0-9]{0,8}\z/) ? params[:liked_page].to_s : '1'
        saved_page = params[:saved_page].to_s.match?(/\A[1-9][0-9]{0,8}\z/) ? params[:saved_page].to_s : '1'
        redirect "/profile?saved_page=#{saved_page}&liked_page=#{liked_page}#liked-memes", 303
      end

      # Self-serve JSON data export (GDPR/CCPA data portability)
      app.get "/profile/export.json" do
        headers 'Cache-Control' => 'no-store, private'
        require_auth!
        user_id = current_user_id
        user = UserService.find_by_id(user_id)
        halt 404, { error: 'User not found' }.to_json unless user

        saved = MemeExplorer::App::DB.execute(
          'SELECT meme_url, meme_title, meme_subreddit, saved_at FROM saved_memes WHERE user_id = ? ORDER BY saved_at DESC',
          [user_id]
        ) || []
        liked = MemeExplorer::App::DB.execute(
          'SELECT meme_url, created_at AS liked_at FROM user_liked_memes WHERE user_id = ? ORDER BY created_at DESC',
          [user_id]
        ) || []
        prefs = MemeExplorer::App::DB.execute(
          'SELECT subreddit, preference_score, times_liked, last_updated FROM user_subreddit_preferences WHERE user_id = ? ORDER BY preference_score DESC',
          [user_id]
        ) || []

        attachment "meme_explorer_data_#{Time.now.utc.strftime('%Y%m%d')}.json"
        content_type :json
        {
          exported_at: Time.now.utc.iso8601,
          account: {
            id: user['id'].to_i,
            email: user['email'],
            reddit_username: user['reddit_username'],
            role: user['role'],
            created_at: user['created_at']
          },
          saved_memes: saved.map { |r| r.transform_keys(&:to_s) },
          liked_memes: liked.map { |r| r.transform_keys(&:to_s) },
          subreddit_preferences: prefs.map { |r| r.transform_keys(&:to_s) }
        }.to_json
      end

      # Self-serve account deletion (Privacy Policy Section 8/10/11 compliance)
      app.post "/profile/delete-account" do
        headers 'Cache-Control' => 'no-store, private'
        require_auth!
        unless params[:confirm_delete].to_s == 'DELETE'
          halt 400, 'Please confirm account deletion by typing DELETE.'
        end
        user_id = current_user_id
        browsing_id = session[:feed_session_id]

        MemeExplorer::App::DB.transaction do
          MemeExplorer::App::DB.execute('UPDATE meme_activity_log SET user_id = NULL WHERE user_id = ?', [user_id])
          MemeExplorer::App::DB.execute('DELETE FROM users WHERE id = ?', [user_id])
        end
        MemeExplorer::App::DB.execute('DELETE FROM email_subscriptions WHERE user_id = ?', [user_id]) rescue nil

        begin
          MemeExplorer::ViewingHistoryService.clear_history(browsing_id) if browsing_id
          MemeExplorer::ViewingHistoryService.clear_history("user:#{user_id}") if user_id
          DiscoveryPreferencesStore.revoke(browsing_id) if browsing_id
        rescue StandardError
          AppLogger.warn('Session store cleanup skipped during account deletion')
        end

        session.clear
        request.session_options[:drop] = true if request.session_options
        redirect '/', 303
      end
    end
  end
end
