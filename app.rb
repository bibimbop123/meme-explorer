
require "sinatra/base"
require "puma"
require "yaml"
require "json"
require "redis"
require "rack/attack"
require "securerandom"
# Full Rack::Attack config lives in config/rack_attack.rb (per-endpoint limits, proper headers)
# Loaded after all requires so Rack::Attack is available
require_relative "./config/rack_attack"
require "uri"
require "time"
require "active_support"
require "active_support/cache"
require "active_support/core_ext/numeric/time"
require "active_support/core_ext/integer/time"
require "active_support/core_ext/object/blank"
require "net/http"
# thread and ostruct are Ruby stdlib — no explicit require needed in Ruby 3.2+
require "oauth2"
require "httparty"
require "bcrypt"
require 'dotenv/load'
require 'colorize'
require 'timeout'
require 'rack/csrf'

require_relative "./db/setup"
require_relative "./lib/error_handler"
require_relative "./lib/app_logger"       # single require — removed duplicate below
require_relative "./config/application"
require_relative "./config/constants"
require_relative "./config/app_constants"
require_relative "./config/schema"
require_relative "./lib/cache_manager"
require_relative "./lib/helpers/auth_helpers"
require_relative "./lib/helpers/personality_content"
require_relative "./lib/helpers/meme_navigation_helpers"
require_relative "./lib/helpers/meme_helpers"
require_relative "./lib/helpers/gamification_helpers"
require_relative "./lib/helpers/gallery_helpers"
require_relative "./lib/helpers/ad_helpers"
require_relative "./lib/helpers/seo_helpers"
require_relative "./lib/helpers/curated_collections_helper"
require_relative "./lib/helpers/refined_meme_helper"
require_relative "./lib/helpers/app_helpers"
require_relative "./lib/helpers/meme_pool_helpers"
require_relative "./lib/helpers/reddit_media_helpers"
require_relative "./lib/helpers/db_transaction_helpers"
require_relative "./lib/helpers/query_optimization_helpers"
require_relative "./lib/services/seo_service"
require_relative "./lib/services/metrics_tracker_service"
require_relative "./lib/middleware/request_id_middleware"
require_relative "./lib/services/smart_media_renderer_service"
require_relative "./lib/services/placeholder_image_service"
require_relative "./lib/services/image_health_service"
require_relative "./lib/services/activity_tracker_service"
require_relative "./lib/services/view_tracker_service"
require_relative "./lib/services/engagement_service"
require_relative "./lib/services/leaderboard_service"
require_relative "./lib/services/auth_service"
require_relative "./lib/services/user_service"
require_relative "./lib/services/redis_service"
require_relative "./lib/services/ab_testing_service"
require_relative "./lib/services/trending_service"
require_relative "./lib/services/meme_service"
require_relative "./lib/services/push_notification_service"
require_relative "./lib/services/surprise_rewards_service"
require_relative "./lib/services/reddit_fetcher_service"
require_relative "./lib/services/inline_reddit_fetcher"
# Route files — loaded before registration block
require_relative "./routes/auth"
require_relative "./routes/reactions"
require_relative "./routes/battles"
require_relative "./routes/legal_routes"
require_relative "./routes/ab_testing"
require_relative "./routes/home"
require_relative "./routes/random_meme"
require_relative "./routes/memes"
require_relative "./routes/meme_stats"
require_relative "./routes/search_routes"
require_relative "./routes/trending_routes"
require_relative "./routes/trending_api"
require_relative "./routes/profile_routes"
require_relative "./routes/admin_routes"
require_relative "./routes/metrics_routes"
require_relative "./routes/behavioral_tracking"
require_relative "./routes/algorithm_metrics"
require_relative "./routes/seo_routes"
require_relative "./routes/enhanced_random"
require_relative "./routes/session_metrics"
# NOTE: collections.rb, personalization.rb, health.rb use bare DSL (pre-module style)
# They are loaded inside the App class body below via class_eval (see Route Registration block)
require_relative "./routes/utility_routes"
require_relative "./routes/leaderboard_routes"
require_relative "./routes/user_api_routes"
require_relative "./routes/system_routes"
require_relative "./routes/admin_inline_routes"
require_relative "./lib/middleware/request_timer"
require_relative "./lib/middleware/security_headers"
require_relative 'lib/helpers/cdn_helpers'
require_relative 'lib/concerns/http_caching'
require_relative 'lib/concerns/performance_profiler'
require_relative 'lib/services/health_check_service'
require_relative 'lib/db_helpers'

require "digest"

# Load Sidekiq and workers
begin
  require_relative "./config/initializers/sidekiq"
  require_relative "./app/workers/cache_refresh_worker"
  require_relative "./app/workers/image_health_worker"
  require_relative "./app/workers/leaderboard_calculation_worker"
  require_relative "./app/workers/database_cleanup_worker"
  require_relative "./app/workers/activity_aggregation_worker"
  require_relative "./app/workers/streak_reminder_worker"
  require_relative "./app/workers/session_cleanup_worker"
  AppLogger.info("✅ Sidekiq workers loaded")
rescue LoadError => e
  AppLogger.warn("⚠️  Sidekiq not available: #{e.message}")
end

# Load thread pool for analytics (MEMORY LEAK FIX)
require_relative "./config/initializers/thread_pool"

# Sentry Error Tracking (if configured)
begin
  require 'sentry-ruby'
  require_relative './config/sentry'
rescue LoadError
  AppLogger.error("⚠️  Sentry not available - error tracking disabled")
end


# REMOVED: Global warning suppression (security risk)

# Track server start time for /health endpoint
# Freeze start time as a namespaced constant — not a global variable
module MemeExplorer
  START_TIME = Time.now.freeze
end

# -----------------------
# Module Wrapper for Services
# -----------------------
module MemeExplorer
  # Main Sinatra Application
  class App < Sinatra::Base
  # -----------------------
  # Redis & DB
  # -----------------------
  # REDIS initialization moved to db/setup.rb for centralized connection management
  # This eliminates duplicate connection leak (see SENIOR_DEV_REDIS_AUDIT_2026.md)
  DB = ::DB
  
  # Thread safety handled by CacheManager

  # Rack::Attack — full config in config/rack_attack.rb (required at file top)
  # Per-endpoint limits, proper retry headers, localhost safelist all live there.
  use Rack::Attack

  # -----------------------
  # CSRF Protection
  # -----------------------
  # ✅ SECURITY FIX: Only skip GET OAuth callback, never skip POST operations
  use Rack::CSRF, raise: true, skip: ['GET:/auth/reddit/callback']

  # -----------------------
  # Request ID Middleware (Week 2: Tracing)
  # -----------------------
  use RequestIdMiddleware
  
  # -----------------------
  # Request Timing Middleware (P2: Monitoring)
  # -----------------------
  use RequestTimer
  
  # -----------------------
  # Security Headers Middleware (Phase 0: Security Hardening)
  # -----------------------
  use SecurityHeaders

  # -----------------------
  # Constants
  # -----------------------
  POPULAR_SUBREDDITS = YAML.load_file("data/subreddits.yml")["popular"]
  ALL_POPULAR_SUBS = POPULAR_SUBREDDITS.sample(50)
    MEME_CACHE = CacheManager.new
    MEMES = YAML.load_file("data/memes.yml") rescue []
  # Thread-safe metrics using Concurrent::AtomicFixnum
require 'concurrent'
METRICS = {
  total_requests: Concurrent::AtomicFixnum.new(0),
  total_duration_ms: Concurrent::AtomicFixnum.new(0)
}

  # -----------------------
  # Configuration
  # -----------------------
  configure do
    # Validate environment configuration before starting
    begin
      ConfigSchema.validate!
    rescue ConfigurationError => e
      AppLogger.error("Configuration validation failed", error: e.message)
      AppLogger.error("❌ Fatal: #{e.message}")
      exit 1
    end
    
    set :server, :puma
    # Session is configured in config.ru via Rack::Session::Cookie
    # (httponly, same_site: :lax, secure in production, SESSION_SECRET)
    # DO NOT add enable :sessions here — double session middleware breaks auth.

    begin
      AppConstants.validate!  # Validates TIER_WEIGHTS sum to 100
    rescue ConfigurationError => e
      AppLogger.error("Configuration validation failed", error: e.message)
      AppLogger.error("Fatal: Configuration error: #{e.message}")
      exit 1
    end
  end
  
  # SESSION_SECRET: Require explicit value in production (no fallback)
  configure :production do
    secret = ENV.fetch("SESSION_SECRET") do
      raise "SESSION_SECRET environment variable must be set in production!"
    end
    set :session_secret, secret
  end
  
  configure :development, :test do
    # Use persistent secret file to maintain sessions across restarts
    secret_file = File.join(Dir.pwd, '.session_secret')
    
    if File.exist?(secret_file)
      secret = File.read(secret_file).strip
    else
      secret = SecureRandom.hex(32)
      File.write(secret_file, secret)
      AppLogger.warn("⚠️  Generated persistent session secret in #{secret_file}")
      AppLogger.info("    Add .session_secret to .gitignore if not already present")
    end
    
    set :session_secret, ENV.fetch("SESSION_SECRET", secret)
  end


  # OAuth2 Reddit Configuration
  REDDIT_OAUTH_CLIENT_ID = ENV.fetch("REDDIT_CLIENT_ID", "")
  REDDIT_OAUTH_CLIENT_SECRET = ENV.fetch("REDDIT_CLIENT_SECRET", "")
  REDDIT_REDIRECT_URI = ENV.fetch("REDDIT_REDIRECT_URI") do
    if ENV['RACK_ENV'] == 'production'
      "https://meme-explorer.onrender.com/auth/reddit/callback"
    else
      "http://localhost:#{ENV.fetch('PORT', 8080)}/auth/reddit/callback"
    end
  end
  
  # Expose OAuth settings for auth routes
  configure do
    set :reddit_oauth_client_id, REDDIT_OAUTH_CLIENT_ID
    set :reddit_oauth_client_secret, REDDIT_OAUTH_CLIENT_SECRET
    set :reddit_redirect_uri, REDDIT_REDIRECT_URI
    # Redis connection for OAuth token storage
    set :redis, RedisService.connection rescue nil
  end

  # Load tier configuration
  TIER_CONFIG = YAML.load_file("data/subreddits.yml") rescue {}
  TIER_WEIGHTS = AppConstants::TIER_WEIGHTS
  TOTAL_TIER_WEIGHT = AppConstants::TOTAL_TIER_WEIGHT

  # ✅ REFACTORING: Cache preload now handled by Sidekiq CachePreloadWorker
  # See: app/workers/cache_preload_worker.rb and config/sidekiq.yml
  # Runs on @reboot with proper error handling, retry logic, and monitoring
  AppLogger.debug("ℹ️  [CACHE] Cache preload handled by CachePreloadWorker (Sidekiq @reboot)")
  AppLogger.debug("ℹ️  [CACHE] Cache refresh handled by CacheRefreshWorker (every 30 minutes)")
  
  # Trigger cache preload worker immediately (non-blocking)
  begin
    CachePreloadWorker.perform_async if defined?(CachePreloadWorker)
  rescue => e
    AppLogger.warn("⚠️  Could not trigger CachePreloadWorker: #{e.message}")
  end

  # Database cleanup now handled by DatabaseCleanupWorker via Sidekiq scheduler
  # See config/sidekiq.yml for schedule configuration

  # -----------------------
  # Request Lifecycle
  # -----------------------
  before do
    @start_time = Time.now
    @seen_memes = begin
      cookie_data = request.cookies["seen_memes"]
      JSON.parse(cookie_data) if cookie_data
    rescue => e
      AppLogger.error("⚠️ Cookie parsing error: #{e.class}")
      []
    end || []
    
    # GAMIFICATION: Track streak and level for logged-in users
    if session[:user_id]
      begin
        # Ensure user_id is an integer for DB queries
        user_id = current_user_id
        @streak_data = update_streak(user_id)
        @user_level = get_user_level(user_id)
      rescue => e
        AppLogger.error("⚠️ Gamification error: #{e.message}")
        @streak_data = nil
        @user_level = nil
      end
    end
    
    # 🔥 ACTIVITY TRACKING: Track ALL visitors (not just logged-in users)
    # Skip tracking for static assets, API endpoints, and health checks
    unless request.path.start_with?('/css', '/js', '/images', '/videos', '/favicon', '/health', '/metrics.json')
      begin
        # Generate unique visitor ID using proper session ID (NOT object_id!)
        # session.object_id changes on every request - BUG!
        # Use Rack session ID which persists across requests
        visitor_id = session[:user_id] || request.session_options[:id] || SecureRandom.hex(16)
        
        # Store session ID in session for consistency if not already present
        session[:visitor_id] ||= visitor_id
        
        # Get client IP for additional fingerprinting
        client_ip = request.ip
        
        # Track visitor as active (5-min window) with IP-based deduplication
        ActivityTrackerService.mark_active(
          session[:visitor_id], 
          page: request.path.split('/')[1] || 'home',
          ip_address: client_ip
        )
      rescue => e
        # Don't break the app if tracking fails
        AppLogger.error("⚠️ Activity tracking error: #{e.message}")
      end
    end
  end

  after do
    # Defensively calculate duration - handle nil @start_time
    begin
      if @start_time.is_a?(Time) && Time.now.is_a?(Time)
        duration = ((Time.now.to_i - @start_time.to_i) * 1000).round(2)
      else
        duration = 0
      end
    rescue => e
      AppLogger.error("After hook duration calc error: #{e.class}")
      duration = 0
    end
    
    begin
      METRICS[:total_requests].increment
METRICS[:total_duration_ms].update { |v| v + duration.to_i }
    rescue => e
      AppLogger.error("After hook metrics error: #{e.class}")
    end

    begin
      response.set_cookie(
        "seen_memes",
        value: @seen_memes.to_json,
        path: "/",
        expires: Time.now + 60 * 60 * 24 * 30,
        httponly: true
      )
    rescue => e
      AppLogger.error("After hook cookie error: #{e.class}")
    end
  end

  # -----------------------
  # Static Methods — extracted to lib/services/inline_reddit_fetcher.rb
  # -----------------------
  # Thin shims kept for backward compat with any callers using MemeExplorer::App.fetch_*
  def self.fetch_reddit_memes_authenticated(access_token, subreddits = nil, limit = 15)
    subreddits ||= POPULAR_SUBREDDITS
    InlineRedditFetcher.fetch_authenticated(access_token, subreddits, limit: limit)
  end

  def self.fetch_reddit_memes_static(subreddits = nil, limit = 100)
    subreddits ||= POPULAR_SUBREDDITS
    InlineRedditFetcher.fetch_static(subreddits, limit: limit)
  end

  def self.extract_image_url_static(post_data)
    InlineRedditFetcher.send(:extract_image_url, post_data)
  end

  def self.extract_gallery_images_static(post_data)
    InlineRedditFetcher.send(:extract_gallery_images, post_data)
  end


  # -----------------------
  # Gamification, Gallery, Ad & Personality Helpers
  # -----------------------
  helpers AuthHelpers           # current_user, require_auth!, require_admin!
  helpers PersonalityContent    # personality-based content helpers
  helpers MemeNavigationHelpers # navigate_meme_unified, is_valid_meme?, get_time_based_pools, etc.
  helpers GamificationHelpers
  helpers GalleryHelpers
  helpers AdHelpers
  helpers SeoHelpers
  helpers RefinedMemeHelper
  helpers CDNHelpers
  helpers HTTPCaching
  helpers AppHelpers
  helpers MemePoolHelpers
  helpers RedditMediaHelpers


  # -----------------------
  # Load bare-DSL route files inside the App class context
  # These files use plain get/post calls (pre-module style) and must be
  # eval'd inside Sinatra::Base, not required at the top level.
  # -----------------------
  module_eval(File.read(File.join(__dir__, 'routes/collections.rb')))
  module_eval(File.read(File.join(__dir__, 'routes/personalization.rb')))
  # health.rb wraps itself in MemeExplorer::App — load after class is open
  load File.join(__dir__, 'routes/health.rb')

  # -----------------------
  # Route Registration
  # Every route lives in routes/*.rb — none inline in app.rb
  # -----------------------
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
  register Routes::UtilityRoutes
  register Routes::LeaderboardRoutes
  register Routes::UserApiRoutes
  register Routes::SystemRoutes
  register Routes::AdminInlineRoutes

  end  # End of App class
end  # End of MemeExplorer module
