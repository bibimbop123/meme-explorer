# frozen_string_literal: true
# routes/admin_inline_routes.rb - extracted from app.rb

module Routes
  module AdminInlineRoutes
    def self.registered(app)
    # BUG FIX (reliability audit): this file used to duplicate BOTH
    # `GET /admin` and `DELETE /admin/meme/:url` from routes/admin_routes.rb
    # - and because this file (`AdminInlineRoutes`) is `register`ed AFTER
    # `AdminRoutes` in app.rb, these weaker/broken copies silently won in
    # the live app, not just in tests:
    #   - `GET /admin` here called `is_admin?` with ZERO arguments, but
    #     `is_admin?(user_id)` (lib/helpers/app_helpers.rb) requires one -
    #     every single request to `/admin` raised ArgumentError/500
    #     instead of ever rendering the dashboard for any admin, ever.
    #     admin_routes.rb's version correctly uses `require_admin!`
    #     (checks UserService.is_admin? against the real current user).
    #   - `DELETE /admin/meme/:url` used a named Sinatra param, which
    #     never matches path segments containing `/` - but every real
    #     meme URL contains slashes after the scheme, and Rack decodes
    #     `%2F`-encoded slashes back to literal `/` in PATH_INFO before
    #     Sinatra ever routes the request, so this could never actually
    #     match a real meme URL to delete, even with the client already
    #     `encodeURIComponent`-ing it (views/admin.erb's `deleteMeme()`).
    # Removed both dead/broken duplicates entirely - admin_routes.rb's
    # `GET /admin` already exists and works correctly. The DELETE route is
    # re-added below, fixed to use a splat (`*`) instead of `:url`, which
    # DOES capture everything after `/admin/meme/`, slashes included.
    app.delete "/admin/meme/*" do
      require_admin!

      # BUG FIX: Sinatra/Rack normalizes consecutive slashes in the
      # PATH_INFO before routing, collapsing a URL like
      # "http://example.com/meme.jpg" down to "http:/example.com/meme.jpg"
      # (single slash) by the time it reaches `params[:splat]` - so even
      # with the `*` splat fix (which solves the separate problem of `:url`
      # not matching slashes at all), the captured value never exactly
      # matched any real stored URL, and every delete silently affected
      # zero rows (no SQL error, just a no-op). Restore the doubled slash
      # after the scheme specifically, rather than guessing at general
      # slash-collapsing - only "scheme://" ever legitimately contains a
      # doubled slash in a URL.
      url = params[:splat]&.first&.sub(%r{\A(https?:)/([^/])}, '\1//\2')
      # BUG FIX: `unless url` only rejects nil - an empty splat capture
      # (e.g. a bare "/admin/meme/" with nothing after it) is `""`, which
      # is truthy in Ruby, so this sailed through to two no-op DELETEs
      # and a false "deleted: true" instead of the 400 it should return.
      halt 400, "URL required" if url.to_s.strip.empty?

      DB.execute("DELETE FROM meme_stats WHERE url = ?", [url])
      DB.execute("DELETE FROM saved_memes WHERE meme_url = ?", [url])

      content_type :json
      { deleted: true, message: "Meme deleted" }.to_json
    end

    # -----------------------
    # Content Feedback API (Chunk 4)
    # -----------------------
    app.post '/api/report-broken-content' do
      content_type :json

      begin
        data = JSON.parse(request.body.read)
        url = data['url']
        page = data['page']

        halt 400, { success: false, error: 'URL required' }.to_json unless url

        # Record failure with user feedback flag
        if defined?(ImageHealthService)
          ImageHealthService.record_failure(
            url,
            reason: 'User reported broken content',
            status_code: nil,
            duration_ms: nil
          )

          AppLogger.info("👤 [USER FEEDBACK] Broken content reported: #{url} (from #{page})")

          { success: true, message: 'Thank you for your feedback!' }.to_json
        else
          halt 500, { success: false, error: 'Service unavailable' }.to_json
        end
      rescue JSON::ParserError => e
        halt 400, { success: false, error: 'Invalid JSON' }.to_json
      rescue => e
        AppLogger.error("❌ [USER FEEDBACK] Error: #{e.message}")
        halt 500, { success: false, error: 'Server error' }.to_json
      end
    end

    # -----------------------
    # Activity Tracking API
    # -----------------------
    app.get '/api/activity-stats' do
      content_type :json

      begin
        # ActivityTrackerService removed during Elon audit
        stats = { active_users: 0, viewing_users: 0, redis_available: false }
        stats.to_json
      rescue => e
        AppLogger.error("❌ [Activity Stats] Error: #{e.message}")
        { 
          active_users: 0, 
          viewing_users: 0, 
          redis_available: false,
          error: e.message 
        }.to_json
      end
    end

    # -----------------------
    # Load Additional Routes
    # -----------------------
    # -----------------------
    # AdSense Verification & Health Check
    # -----------------------

    app.get '/adsense-verification' do
      content_type :html

      health = {
        status: 'operational',
        timestamp: Time.now.iso8601,
        uptime_seconds: (Time.now - MemeExplorer::START_TIME).to_i,
        site_url: request.base_url,
        adsense_ready: true,
        checks: {
          database: (DB.execute("SELECT 1").any? rescue false),
          meme_pool: (MEME_CACHE[:memes]&.size || 0) > 0,
          ads_enabled: !ENV['GOOGLE_ADSENSE_CLIENT'].nil?
        }
      }

      erb :adsense_verification, locals: { health: health }
    end
    end
  end
end
