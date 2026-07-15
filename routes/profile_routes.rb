# routes/profile_routes.rb
# User profile and saved memes management

module Routes
  module ProfileRoutes
    def self.registered(app)
      # User profile page with ENHANCED ENGAGEMENT STATS
      app.get "/profile" do
        require_auth!
        user_id = current_user_id
      
        # Wrap Redis or DB calls in safe error handling
        begin
          @user = get_user(user_id)
          
          # Ensure @user is not nil - provide default structure
          if @user.nil?
            halt 500, "User not found in database"
          end
          
          # Get user's saved memes from saved_memes table
          @saved_memes = begin
            results = MemeExplorer::App::DB.execute(
              "SELECT id, meme_url, meme_title, meme_subreddit, created_at as saved_at FROM saved_memes WHERE user_id = ? ORDER BY created_at DESC LIMIT 50",
              [user_id]
            ) || []
            results.map { |row| row.transform_keys(&:to_s) }
          rescue => e
            AppLogger.error("Error fetching saved memes: #{e.message}")
            []
          end
          
          # Get user's liked memes from user_liked_memes table (source of truth)
          @liked_memes = begin
            results = MemeExplorer::App::DB.execute(
              "SELECT meme_url, created_at as liked_at FROM user_liked_memes WHERE user_id = ? ORDER BY created_at DESC LIMIT 50",
              [user_id]
            ) || []
            results.map { |row| row.transform_keys(&:to_s) }
          rescue => e
            AppLogger.error("Error fetching liked memes: #{e.message}")
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
          halt 500, "Error loading profile: #{e.message}"
        end
      
        # Count stats (with fallback to engagement service)
        @saved_count = @saved_memes.size
        @liked_count = @liked_memes.size
        
        # Add comprehensive stats for display
        @total_xp = @engagement_stats[:total_xp] || 0
        @level = @engagement_stats[:level] || 1
        @weekly_rank = @engagement_stats[:weekly_rank]
        @current_streak = @engagement_stats[:current_streak] || 0
      
        erb :profile
      end

      # Save a meme to user's collection with FULL INTEGRATION
      app.post "/api/save-meme" do
        require_auth!

        url = params[:url]
        title = params[:title] || 'Unknown'
        subreddit = params[:subreddit] || 'unknown'

        halt 400, { error: "URL required" }.to_json unless url

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

        response = {
          success: result[:success],
          saved: true,
          message: "Meme saved"
        }
        
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

        url = params[:url]
        halt 400, { error: "URL required" }.to_json unless url

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
          unsaved: true,
          message: "Meme unsaved"
        }.to_json
      end

      # View a specific saved meme
      app.get "/saved/:id" do
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

        erb :saved_meme
      end
    end
  end
end
