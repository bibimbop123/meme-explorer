# frozen_string_literal: true
# routes/admin_inline_routes.rb - extracted from app.rb

module Routes
  module AdminInlineRoutes
    def self.registered(app)
    get "/admin" do
      halt 403, "Forbidden" unless is_admin?

      @total_memes = DB.get_first_value("SELECT COUNT(*) FROM meme_stats").to_i
      @total_likes = DB.get_first_value("SELECT SUM(likes) FROM meme_stats").to_i
      @total_users = DB.get_first_value("SELECT COUNT(*) FROM users").to_i
      @total_saved_memes = DB.get_first_value("SELECT COUNT(*) FROM saved_memes").to_i
      @top_memes = DB.execute("SELECT title, url, likes, subreddit FROM meme_stats ORDER BY likes DESC LIMIT 10")

      erb :admin
    end

    delete "/admin/meme/:url" do
      halt 403, "Forbidden" unless is_admin?

      url = params[:url]
      halt 400, "URL required" unless url

      DB.execute("DELETE FROM meme_stats WHERE url = ?", [url])
      DB.execute("DELETE FROM saved_memes WHERE meme_url = ?", [url])

      content_type :json
      { deleted: true, message: "Meme deleted" }.to_json
    end

    # -----------------------
    # Content Feedback API (Chunk 4)
    # -----------------------
    post '/api/report-broken-content' do
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
    get '/api/activity-stats' do
      content_type :json

      begin
        stats = ActivityTrackerService.stats
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
    require_relative './routes/auth'
    require_relative './routes/reactions'
    require_relative './routes/battles'
    require_relative './routes/ab_testing'

    # P2 Week 2: Refactored route modules
    require_relative './routes/home'
    require_relative './routes/random_meme'
    require_relative './routes/memes'
    require_relative './routes/meme_stats'
    require_relative './routes/search_routes'
    require_relative './routes/trending_routes'
    require_relative './routes/trending_api'
    require_relative './routes/profile_routes'
    require_relative './routes/admin_routes'
    require_relative './routes/metrics_routes'
    require_relative './routes/behavioral_tracking'
    require_relative './routes/algorithm_metrics'
    require_relative './routes/seo_routes'
    require_relative './routes/enhanced_random'
    require_relative './routes/session_metrics'
    require_relative './routes/legal_routes'

    AuthRoutes.register(self)
    ReactionsRoutes.register(self)
    BattlesRoutes.register(self)
    LegalRoutes.register(self)
    register Routes::ABTesting
    register Routes::Home
    register Routes::RandomMeme
    register Routes::Memes
    register Routes::MemeStats
    register Routes::SearchRoutes
    register Routes::TrendingRoutes
    register Routes::TrendingAPI
    register Routes::ProfileRoutes
    register Routes::AdminRoutes
    register Routes::MetricsRoutes
    register Routes::BehavioralTracking
    register Routes::AlgorithmMetrics
    register Routes::Seo
    register Routes::EnhancedRandom
    register Routes::SessionMetrics

    # -----------------------
    # AdSense Verification & Health Check
    # -----------------------

    get '/adsense-verification' do
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

    # -----------------------

    # Start server
    # -----------------------
    run! if app_file == $0
    end  # End of App class
    end
  end
end
