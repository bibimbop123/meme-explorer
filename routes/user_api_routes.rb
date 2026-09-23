# frozen_string_literal: true
# routes/user_api_routes.rb - extracted from app.rb
#
# BUG FIX (reliability audit): this file used to duplicate `/profile`,
# `/api/save-meme`, `/api/unsave-meme`, and `/saved/:id` - real, working
# versions of all four already exist in routes/profile_routes.rb, which is
# `register`ed earlier in app.rb (see the `Route Registration` block), so
# Sinatra always dispatched to profile_routes.rb's handlers and these copies
# here were dead code, unreachable by any real request. Worse: they called
# `save_meme`, `unsave_meme`, and `get_user_saved_memes` - three methods
# that are not defined ANYWHERE in this codebase (grep confirms zero
# `def save_meme`/`def unsave_meme`/`def get_user_saved_memes`). If route
# registration order in app.rb ever changed, these would immediately start
# raising NoMethodError on every save/unsave/profile request instead of
# silently doing nothing, as they do today. Removed entirely rather than
# left as a landmine - profile_routes.rb is the one real implementation.
module Routes
  module UserApiRoutes
    def self.registered(app)
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
      # BUG FIX: same class of bug fixed elsewhere this session -
      # `is_admin?` requires a `user_id` argument (lib/helpers/app_helpers.rb)
      # and was called with none, raising ArgumentError on every request
      # instead of ever actually checking admin status.
      halt 403 unless is_admin?(current_user_id)

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

    # (`/saved/:id` also removed here as part of the same dead-code cleanup -
    # see the file-header comment above. profile_routes.rb defines the one
    # real, reachable version.)

    # -----------------------
    # Monitoring Routes (Phase 3)
    # -----------------------

    # Quick health check for load balancers
    end
  end
end
