# frozen_string_literal: true
# routes/system_routes.rb - extracted from app.rb

module Routes
  module SystemRoutes
    def self.registered(app)
    app.get "/health" do
      content_type :json
      HealthCheckService.quick_check.to_json
    end

    # Detailed health check (admin only)
    app.get "/health/detailed" do
      halt 403, { error: "Forbidden" }.to_json unless is_admin?
      content_type :json
      HealthCheckService.check.to_json
    end

    # Performance metrics (admin only)
    app.get "/metrics/performance" do
      halt 403, { error: "Forbidden" }.to_json unless is_admin?
      content_type :json
      PerformanceProfiler.summary.to_json
    end

    app.get "/errors" do
      halt 403, "Forbidden" unless is_admin?
      content_type :json
      {
        recent_errors: ErrorHandler::Logger.recent(50),
        error_rate_5m: ErrorHandler::Logger.error_rate(300),
        critical_errors_5m: ErrorHandler::Logger.critical_errors(300),
        error_patterns: ErrorHandler::ErrorPatterns.top_errors(10)
      }.to_json
    end

    app.get "/api/notifications" do
      require_auth!
      user_id = current_user_id

      # Get user notifications (saved count changes, likes, etc.)
      content_type :json
      {
        user_id: user_id,
        saved_count: get_user_saved_memes_count(user_id),
        timestamp: Time.now.iso8601,
        message: "Your profile is up to date"
      }.to_json
    end

      # -----------------------
      # Admin Authorization Filter (P0 Security Fix)
      # -----------------------
      app.before '/admin/*' do
    halt 403, { error: "Forbidden - Admin access required" }.to_json unless is_admin?
      end

      # -----------------------
      # Admin Authorization Filter (P0 Security Fix)
      # -----------------------


      # -----------------------
      # Admin Authorization Filter (P0 Security Fix)
      # -----------------------


    # -----------------------
    # Admin Routes
    # -----------------------
    end
  end
end
