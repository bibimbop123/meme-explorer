# frozen_string_literal: true
# routes/user_api_routes.rb - extracted from app.rb

module Routes
  module UserApiRoutes
    def self.registered(app)
    app.get "/profile" do
      # Check session safely
      user_id = current_user_id
      halt 401, "Not logged in" unless user_id

      # Wrap Redis or DB calls in safe error handling
      begin
        @user = get_user(user_id)

        # Ensure @user is not nil - provide default structure
        if @user.nil?
          halt 500, "User not found in database"
        end

        @saved_memes = get_user_saved_memes(user_id) || []

        # Get user's liked memes from user_meme_stats
        @liked_memes = begin
          results = DB.execute(
            "SELECT meme_url, liked_at FROM user_meme_stats WHERE user_id = ? AND liked = 1 ORDER BY liked_at DESC",
            [user_id]
          ) || []
          results.map { |row| row.transform_keys(&:to_s) }
        rescue => e
          AppLogger.error("Error fetching liked memes: #{e.message}")
          []
        end

      rescue => e
        # Log the error and return proper error response
        AppLogger.error("Profile Error: #{e.class}: #{e.message}")
        AppLogger.info("backtrace", lines: e.backtrace.join("\n"))
        halt 500, "Error loading profile: #{e.message}"
      end

      # Count stats
      @saved_count = @saved_memes.size
      @liked_count = @liked_memes.size

      erb :profile
    end


    app.post "/api/save-meme" do
      require_auth!

      url = params[:url]
      title = params[:title]
      subreddit = params[:subreddit]

      halt 400, { error: "URL required" }.to_json unless url

      save_meme(current_user_id, url, title, subreddit)

      content_type :json
      { saved: true, message: "Meme saved" }.to_json
    end

    app.post "/api/unsave-meme" do
      require_auth!

      url = params[:url]
      halt 400, { error: "URL required" }.to_json unless url

      unsave_meme(current_user_id, url)

      content_type :json
      { unsaved: true, message: "Meme unsaved" }.to_json
    end

    # -----------------------
    # Push Notification API (Priority 1)
    # -----------------------
    app.post "/api/subscribe-push" do
      require_auth!

      begin
        subscription_data = JSON.parse(request.body.read)
        subscription_json = subscription_data.to_json

        # Store subscription in database (SQLite-compatible)
        # Check if subscription already exists
        existing = DB.execute(
          "SELECT id FROM push_subscriptions WHERE user_id = ? AND subscription_data = ?",
          [current_user_id, subscription_json]
        ).first

        if existing
          # Update existing subscription timestamp
          DB.execute(
            "UPDATE push_subscriptions SET updated_at = CURRENT_TIMESTAMP WHERE id = ?",
            [existing['id']]
          )
        else
          # Insert new subscription
          DB.execute(
            "INSERT INTO push_subscriptions (user_id, subscription_data, created_at, updated_at) 
             VALUES (?, ?, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)",
            [current_user_id, subscription_json]
          )
        end

        AppLogger.info("✅ Push subscription saved for user #{session[:user_id]}")

        content_type :json
        { success: true, message: "Push subscription saved" }.to_json
      rescue => e
        AppLogger.error("❌ Push subscription error: #{e.message}")
        halt 500, { error: "Failed to save subscription", details: e.message }.to_json
      end
    end

    # Test endpoint for admins to send test notifications
    app.post "/api/test-push" do
      require_auth!
      halt 403 unless is_admin?

      begin
        PushNotificationService.send_custom(
          current_user_id,
          "🔥 Test Notification",
          "Your push notifications are working perfectly!",
          "/random"
        )

        content_type :json
        { success: true, message: "Test notification sent" }.to_json
      rescue => e
        AppLogger.error("❌ Test push error: #{e.message}")
        halt 500, { error: e.message }.to_json
      end
    end

    # -----------------------
    # Surprise Rewards API (Priority 2)
    # -----------------------
    app.get "/api/surprise-rewards/check" do
      require_auth!

      begin
        # Check if user has pending reward
        reward = session.delete(:pending_surprise_reward)

        content_type :json
        { reward: reward }.to_json
      rescue => e
        AppLogger.error("❌ Surprise reward check error: #{e.message}")
        halt 500, { error: e.message }.to_json
      end
    end

    app.get "/api/surprise-rewards/active-boosts" do
      require_auth!

      begin
        boosts = SurpriseRewardsService.active_boosts(current_user_id)

        content_type :json
        { boosts: boosts }.to_json
      rescue => e
        AppLogger.error("❌ Active boosts error: #{e.message}")
        halt 500, { error: e.message }.to_json
      end
    end

    app.get "/saved/:id" do
      # FIX: IDOR vulnerability - require authentication and authorization
      require_auth!

      saved_id = params[:id].to_i
      saved_meme = DB.execute(
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

    # -----------------------
    # Monitoring Routes (Phase 3)
    # -----------------------

    # Quick health check for load balancers
    end
  end
end
