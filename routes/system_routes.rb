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
      # BUG FIX: same class of bug as the '/admin/*' filter fixed elsewhere
      # in this file - `is_admin?` requires a `user_id` argument
      # (lib/helpers/app_helpers.rb) and was called with none, raising
      # ArgumentError on every single request to this endpoint instead of
      # ever actually checking admin status.
      halt 403, { error: "Forbidden" }.to_json unless is_admin?(current_user_id)
      content_type :json
      HealthCheckService.check.to_json
    end

    # Performance metrics (admin only)
    app.get "/metrics/performance" do
      halt 403, { error: "Forbidden" }.to_json unless is_admin?(session[:user_id])
      content_type :json
      PerformanceProfiler.summary.to_json
    end

    app.get "/errors" do
      halt 403, "Forbidden" unless is_admin?(session[:user_id])
      content_type :json
      {
        recent_errors: ErrorHandler::Logger.recent(50),
        error_rate_5m: ErrorHandler::Logger.error_rate(300),
        critical_errors_5m: ErrorHandler::Logger.critical_errors(300),
        error_patterns: ErrorHandler::ErrorPatterns.top_errors(10)
      }.to_json
    end

    # (`/api/notifications` also duplicated in routes/metrics_routes.rb,
    # which is `register`ed first in app.rb so it always won here anyway -
    # removed this dead copy; see the BUG FIX note on the surviving
    # version in metrics_routes.rb for what was actually broken.)

      # -----------------------
      # Admin Authorization Filter (P0 Security Fix)
      # -----------------------
      #
      # BUG FIX: `is_admin?` (lib/helpers/app_helpers.rb) requires a
      # `user_id` argument - this called it with zero args, so every
      # single request matching '/admin/*' (any admin sub-route, e.g.
      # `DELETE /admin/meme/:url` - note this pattern does NOT match bare
      # `/admin` itself, which is separately protected by `require_admin!`
      # in routes/admin_routes.rb) raised ArgumentError instead of ever
      # actually checking admin status. A real, live, silently-broken P0
      # security filter - it never worked, it just happened to crash
      # closed (500) rather than open, so no unauthorized access actually
      # occurred, but no authorized admin request could work either.
      app.before '/admin/*' do
        halt 403, { error: "Forbidden - Admin access required" }.to_json unless is_admin?(current_user_id)
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
