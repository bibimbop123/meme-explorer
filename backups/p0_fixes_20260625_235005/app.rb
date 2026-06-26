
require "sinatra/base"
require "puma"
require "yaml"
require "json"
require "redis"
require "rack/attack"
require "securerandom"
require "uri"
require "time"
require "active_support"
require "active_support/cache"
require "sqlite3"
require "net/http"
require "thread"
require "ostruct"
require "oauth2"
require "httparty"
require "bcrypt"
require 'dotenv/load'
require 'colorize'
require 'timeout'
require 'rack/csrf'

require_relative "./db/setup"
require_relative "./lib/error_handler"
require_relative "./lib/app_logger"
require_relative "./config/application"
require_relative "./config/constants"
require_relative "./config/app_constants"
require_relative "./config/schema"
require_relative "./lib/app_logger"
require_relative "./lib/cache_manager"
require_relative "./lib/helpers/meme_helpers"
require_relative "./lib/helpers/gamification_helpers"
require_relative "./lib/helpers/gallery_helpers"
require_relative "./lib/helpers/personality_content"
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
  puts "✅ Sidekiq workers loaded"
rescue LoadError => e
  puts "⚠️  Sidekiq not available: #{e.message}"
end

# Load thread pool for analytics (MEMORY LEAK FIX)
require_relative "./config/initializers/thread_pool"

# Sentry Error Tracking (if configured)
begin
  require 'sentry-ruby'
  require_relative './config/sentry'
rescue LoadError
  puts "⚠️  Sentry not available - error tracking disabled"
end


# REMOVED: Global warning suppression (security risk)

# Track server start time for /health endpoint
$start_time = Time.now

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

  # -----------------------
  # Rack::Attack
  # -----------------------
  Rack::Attack.cache.store = ActiveSupport::Cache::MemoryStore.new
  
  class Rack::Attack
    safelist("allow-localhost") { |req| ["127.0.0.1", "::1"].include?(req.ip) }
    throttle("req/ip", limit: 60, period: 60) { |req| req.ip unless req.path.start_with?("/assets") }
    self.throttled_responder = lambda do |_env|
      [429, { "Content-Type" => "application/json" }, [{ error: "Too many requests" }.to_json]]
    end
  end
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
      puts "❌ Fatal: #{e.message}"
      exit 1
    end
    
    set :server, :puma
    enable :sessions
    set :session_expire_after, MemeExplorerConfig::SESSION_EXPIRE_AFTER
    set :cookie_options, MemeExplorerConfig::COOKIE_OPTIONS
    
    begin
      MemeExplorerConfig.validate!
    rescue ConfigurationError => e
      AppLogger.error("Configuration validation failed", error: e.message)
      puts "Fatal: Configuration error: #{e.message}"
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
      puts "⚠️  Generated persistent session secret in #{secret_file}"
      puts "    Add .session_secret to .gitignore if not already present"
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
  TIER_WEIGHTS = MemeExplorerConfig::TIER_WEIGHTS
  TOTAL_TIER_WEIGHT = MemeExplorerConfig::TOTAL_TIER_WEIGHT

  # ✅ REFACTORING: Cache preload now handled by Sidekiq CachePreloadWorker
  # See: app/workers/cache_preload_worker.rb and config/sidekiq.yml
  # Runs on @reboot with proper error handling, retry logic, and monitoring
  puts "ℹ️  [CACHE] Cache preload handled by CachePreloadWorker (Sidekiq @reboot)"
  puts "ℹ️  [CACHE] Cache refresh handled by CacheRefreshWorker (every 30 minutes)"
  
  # Trigger cache preload worker immediately (non-blocking)
  begin
    CachePreloadWorker.perform_async if defined?(CachePreloadWorker)
  rescue => e
    puts "⚠️  Could not trigger CachePreloadWorker: #{e.message}"
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
      puts "⚠️ Cookie parsing error: #{e.class}"
      []
    end || []
    
    # GAMIFICATION: Track streak and level for logged-in users
    if session[:user_id]
      begin
        # Ensure user_id is an integer for DB queries
        user_id = session[:user_id].to_i
        @streak_data = update_streak(user_id)
        @user_level = get_user_level(user_id)
      rescue => e
        puts "⚠️ Gamification error: #{e.message}"
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
        puts "⚠️ Activity tracking error: #{e.message}"
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
      puts "After hook duration calc error: #{e.class}"
      duration = 0
    end
    
    begin
      METRICS[:total_requests].increment
METRICS[:total_duration_ms].update { |v| v + duration.to_i }
    rescue => e
      puts "After hook metrics error: #{e.class}"
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
      puts "After hook cookie error: #{e.class}"
    end
  end

  # -----------------------
  # Static Methods (for background thread)
  # -----------------------
  def self.fetch_reddit_memes_authenticated(access_token, subreddits = nil, limit = 15)
    require "httparty"
    
    memes = []
    subreddits = subreddits.sample(8) if subreddits&.size.to_i > 8
    
    subreddits.each do |subreddit|
      begin
        url = "https://oauth.reddit.com/r/#{subreddit}/top?t=week&limit=#{limit}"
        
        response = HTTParty.get(url,
          headers: {
            "Authorization" => "Bearer #{access_token}",
            "User-Agent" => "MemeExplorer/1.0 (by YourRedditUsername)"
          },
          timeout: 15
        )
        
        if response.success?
          data = response.parsed_response
          
          data["data"]["children"].each do |post|
            post_data = post["data"]
            next if post_data["is_self"]
            
            # Check if gallery post
            is_gallery = post_data["is_gallery"] == true
            gallery_images = nil
            
            if is_gallery
              gallery_images = extract_gallery_images_static(post_data)
            end
            
            # Skip videos unless they're galleries
            next if post_data["is_video"] && !is_gallery
            
            image_url = if gallery_images && gallery_images.any?
                          gallery_images.first["url"]
                        else
                          post_data["url"]
                        end
            
            next unless image_url
            
            meme = {
              "title" => post_data["title"],
              "url" => image_url,
              "subreddit" => post_data["subreddit"],
              "likes" => post_data["ups"] || 0,
              "permalink" => post_data["permalink"]
            }
            
            # Add gallery data if present
            if is_gallery && gallery_images && gallery_images.any?
              meme["is_gallery"] = true
              meme["gallery_images"] = gallery_images
            end
            
            memes << meme
          end
        end
        sleep 1
      rescue => e
        puts "Error fetching from r/#{subreddit} (authenticated): #{e.message}"
      end
    end
    
    memes
  end

  def self.fetch_reddit_memes_static(subreddits = nil, limit = 100)
    memes = []
    subreddits ||= YAML.load_file("data/subreddits.yml")["popular"]
    subreddits = subreddits.sample(40) if subreddits.size > 40

    user_agents = [
      "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
      "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
      "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"
    ]

    subreddits.each do |subreddit|
      begin
        url = "https://www.reddit.com/r/#{subreddit}/top.json?t=week&limit=#{limit}"
        uri = URI(url)
        
        response = Net::HTTP.start(uri.host, uri.port, use_ssl: true, read_timeout: 10, open_timeout: 10) do |http|
          request = Net::HTTP::Get.new(uri.request_uri)
          request["User-Agent"] = user_agents.sample
          request["Accept"] = "application/json"
          http.request(request)
        end
        
        if response.code == "200"
          data = JSON.parse(response.body)
          data["data"]["children"].each do |post|
            post_data = post["data"]
            next if post_data["is_self"]
            
            # Check if gallery post
            is_gallery = post_data["is_gallery"] == true
            gallery_images = nil
            
            if is_gallery
              gallery_images = extract_gallery_images_static(post_data)
            end
            
            # Skip videos unless they're galleries
            next if post_data["is_video"] && !is_gallery
            
            image_url = if gallery_images && gallery_images.any?
                          gallery_images.first["url"]
                        else
                          post_data["url"]
                        end
            
            next unless image_url
            
            meme = {
              "title" => post_data["title"],
              "url" => image_url,
              "subreddit" => post_data["subreddit"],
              "likes" => post_data["ups"] || 0
            }
            
            # Add gallery data if present
            if is_gallery && gallery_images && gallery_images.any?
              meme["is_gallery"] = true
              meme["gallery_images"] = gallery_images
            end
            
            memes << meme
          end
        end
        sleep 0.5
      rescue => e
        # Silently skip errors
      end
    end
    
    memes
  end

  def self.extract_image_url_static(post_data)
    if post_data["url"]&.match?(/^https:\/\/i\.redd\.it\//)
      return post_data["url"]
    end

    if post_data["url"]&.match?(/^https:\/\/(i\.)?imgur\.com\//)
      return post_data["url"]
    end

    if post_data["preview"]&.dig("images", 0, "source", "url")
      url = post_data["preview"]["images"][0]["source"]["url"]
      return url.gsub("&amp;", "&") if url
    end

    nil
  end

  def self.extract_gallery_images_static(post_data)
    return nil unless post_data

    if post_data["is_gallery"] && post_data["gallery_data"] && post_data["media_metadata"]
      gallery_items = post_data["gallery_data"]["items"] || []
      media_metadata = post_data["media_metadata"] || {}

      images = []
      gallery_items.each do |item|
        media_id = item["media_id"]
        next unless media_id

        media_info = media_metadata[media_id]
        next unless media_info

        # Get the highest quality image
        image_url = media_info.dig("s", "u") || media_info.dig("s", "gif") || media_info.dig("s", "mp4")
        next unless image_url

        # Clean up URL encoding
        image_url = image_url.gsub('&amp;', '&')

        images << {
          "url" => image_url,
          "caption" => item["caption"] || "",
          "media_id" => media_id
        }
      end

      return images if images.any?
    end

    nil
  end

  # -----------------------
  # Gamification, Gallery, Ad & Personality Helpers
  # -----------------------
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
  
  # Include personality content methods
  helpers do
    include PersonalityContent

  # -----------------------
  # Helpers
  # -----------------------
    # Safely get meme image - prioritize API URLs over local files
    def meme_image_src(m)
      return "/images/funny1.jpeg" unless m.is_a?(Hash)
      m["url"].to_s.strip != "" ? m["url"] : (m["file"].to_s.strip != "" ? m["file"] : "/images/funny1.jpeg")
    end

    # Fallback meme - shown while API is loading or content unavailable
    def fallback_meme
      { 
        "title" => "Loading memes from the cosmos...", 
        "file" => "/images/funny1.jpeg", 
        "subreddit" => "loading",
        "is_placeholder" => true
      }
    end

    # Ensure subreddit string
    def sanitize_subreddit(sub)
      return "local" if sub.nil? || sub.strip.empty?
      sub.downcase
    end

    # Unified Navigation with Intelligent Pool + Spaced Repetition
    # Consolidates navigate_meme and navigate_meme_v3 into single optimized method
    def navigate_meme_unified(direction: "next")
      user_id = session[:user_id] rescue nil
      
      # Choose pool strategy based on user state
      memes = if user_id
        # New users (< 10 views) get fresh cache, established users get personalized pool
        exposure_count = DB.execute("SELECT COUNT(*) FROM user_meme_exposure WHERE user_id = ?", [user_id]).first[0].to_i
        is_new_user = exposure_count < 10
        
        if is_new_user
          random_memes_pool  # Fresh API memes for onboarding
        else
          get_time_based_pools(user_id, 100)  # Intelligent pool with spaced repetition
        end
      else
        random_memes_pool  # Anonymous users get standard pool
      end
      
      return nil if memes.empty?

      # Initialize session tracking
      session[:meme_history] ||= []
      session[:last_subreddit] ||= nil
      last_meme_url = session[:meme_history].last

      # Find valid meme with smart filtering
      new_meme = nil
      attempts = 0
      max_attempts = [memes.size, 30].min
      
      while attempts < max_attempts
        candidate = memes.sample
        candidate_id = candidate["url"] || candidate["file"]
        candidate_subreddit = candidate["subreddit"]&.downcase
        
        # Check spaced repetition for logged-in users
        if user_id && should_exclude_from_exposure(user_id, candidate_id)
          attempts += 1
          next
        end
        
        # Validation checks
        if candidate_id && 
           candidate_id != last_meme_url && 
           is_valid_meme?(candidate) &&
           candidate_subreddit != session[:last_subreddit]
          new_meme = candidate
          break
        end
        attempts += 1
      end

      # Fallback: try random pool if nothing found in primary pool
      if new_meme.nil? && user_id
        memes = random_memes_pool
        attempts = 0
        max_attempts = [memes.size, 30].min
        
        while attempts < max_attempts
          candidate = memes.sample
          candidate_id = candidate["url"] || candidate["file"]
          candidate_subreddit = candidate["subreddit"]&.downcase
          
          if candidate_id && 
             candidate_id != last_meme_url && 
             is_valid_meme?(candidate) &&
             candidate_subreddit != session[:last_subreddit]
            new_meme = candidate
            break
          end
          attempts += 1
        end
      end

      return nil unless new_meme

      # Normalize meme data
      meme_identifier = new_meme["url"] || new_meme["file"]
      new_meme["url"] = meme_identifier if !new_meme["url"]
      new_meme["permalink"] ||= ""
      
      # Track view in meme_stats
      meme_title = new_meme["title"] || "Unknown"
      meme_subreddit = new_meme["subreddit"] || "local"
      DB.execute(
        "INSERT INTO meme_stats (url, title, subreddit, views, likes) VALUES (?, ?, ?, 1, 0) ON CONFLICT(url) DO UPDATE SET views = views + 1, updated_at = CURRENT_TIMESTAMP",
        [meme_identifier, meme_title, meme_subreddit]
      ) rescue nil
      
      # Update session history
      session[:meme_history] << meme_identifier
      session[:meme_history] = session[:meme_history].last(50)  # Hard cap: 50 (reduced from 100)
      session[:last_subreddit] = meme_subreddit&.downcase

      # Track exposure for analytics and spaced repetition
      if user_id
        DB.execute(
          "INSERT INTO user_meme_exposure (user_id, meme_url, shown_count) VALUES (?, ?, 1) ON CONFLICT(user_id, meme_url) DO UPDATE SET shown_count = shown_count + 1, last_shown = CURRENT_TIMESTAMP",
          [user_id, meme_identifier]
        ) rescue nil
      end

      new_meme
    end

    # Update user preference when they like a meme
    def update_user_preference(user_id, subreddit)
      return unless user_id && subreddit
      
      subreddit = subreddit.downcase
      DB.execute(
        "INSERT INTO user_subreddit_preferences (user_id, subreddit, preference_score, times_liked) VALUES (?, ?, 1.0, 1) ON CONFLICT(user_id, subreddit) DO UPDATE SET preference_score = preference_score + 0.2, times_liked = times_liked + 1, last_updated = CURRENT_TIMESTAMP",
        [user_id, subreddit]
      ) rescue nil
    end

    # Spaced repetition - allow re-showing memes after decay
    def should_exclude_from_exposure(user_id, meme_url)
      return false unless user_id
      
      begin
        exposure = DB.execute(
          "SELECT last_shown, shown_count FROM user_meme_exposure WHERE user_id = ? AND meme_url = ?",
          [user_id, meme_url]
        ).first
        
        return false unless exposure
        return false if exposure.nil?
        
        last_shown_str = exposure["last_shown"].to_s.strip
        return false if last_shown_str.empty?
        
        last_shown = Time.parse(last_shown_str) rescue nil
        return false unless last_shown.is_a?(Time)
        
        shown_count_val = exposure["shown_count"]
        return false if shown_count_val.nil?
        
        shown_count = shown_count_val.to_i
        hours_to_wait = 4 ** (shown_count - 1)
        
        current_time = Time.now
        return false unless current_time.is_a?(Time)
        
        time_diff_seconds = (current_time.to_i - last_shown.to_i).to_f
        time_since_shown = time_diff_seconds / 3600.0
        
        time_since_shown < hours_to_wait
      rescue => e
        puts "Error in should_exclude_from_exposure: #{e.class}: #{e.message}"
        false
      end
    end

    # Validate meme before display
    def is_valid_meme?(meme)
      return false unless meme.is_a?(Hash)
      
      if meme["file"]
        File.exist?(File.join("public", meme["file"]))
      elsif meme["url"]
        meme["url"].match?(/^https?:\/\//)
      else
        false
      end
    end

    # Get memes from cache or MEMES (thread-safe) - MIGRATED TO RedisService (Phase 3 Week 1)
    def get_cached_memes
      # Use RedisService.fetch with automatic fallback to memory cache
      memes = RedisService.fetch("memes:latest", ttl: 300) do
        # Fallback: get from memory cache or static data
        MEME_CACHE.get(:memes) || MEMES
      end

      # Filter out invalid memes
      memes.reject! do |m|
        file_missing = m["file"] && !File.exist?(File.join(settings.public_folder, m["file"]))
        url_invalid  = m["url"] && !m["url"].match?(/^https?:\/\//)
        file_missing || url_invalid
      end

      # Update memory cache
      MEME_CACHE.set(:memes, memes)
      memes
    rescue => e
      puts "❌ get_cached_memes error: #{e.class} - #{e.message}"
      MEME_CACHE.get(:memes) || MEMES
    end

    # Phase 1: Weighted random selection by score
    def weighted_random_select(memes)
      return nil if memes.empty?
      
      # Calculate weights: score = sqrt(likes * 2 + views)
      weights = memes.map do |m|
        score = Math.sqrt((m["likes"].to_i * 2 + m["views"].to_i).to_f)
        [score, 0.1].max  # Minimum weight of 0.1 for unknown memes
      end
      
      total_weight = weights.sum
      return memes.sample if total_weight == 0
      
      # Normalize weights and select
      r = rand * total_weight
      cumulative = 0
      memes.each_with_index do |meme, idx|
        cumulative += weights[idx]
        return meme if cumulative >= r
      end
      
      memes.last
    end

    # Get likes safely - MIGRATED TO RedisService (Phase 3 Week 1)
    def get_meme_likes(url)
      return 0 unless url
      
      # Use RedisService.fetch with automatic DB fallback
      RedisService.fetch("meme:likes:#{url}", ttl: 300) do
        # Fallback: query database if Redis unavailable or cache miss
        # PostgreSQL requires params as an array
        row = DB.execute("SELECT likes FROM meme_stats WHERE url = ?", [url]).first
        row ? row["likes"].to_i : 0
      end
    end

    # Toggle like for meme (only count once per session)
    def toggle_like(url, liked_now, session)
      return 0 unless url
      
      session[:meme_like_counts] ||= {}
      was_liked_before = session[:meme_like_counts][url] || false
      user_id = session[:user_id]
      
      # Only update DB on first like/unlike transition
      if liked_now && !was_liked_before
        # First time liking in this session
        # Update global meme_stats
        DB.execute("INSERT OR IGNORE INTO meme_stats (url, likes) VALUES (?, 0)", [url])
        DB.execute("UPDATE meme_stats SET likes = likes + 1, updated_at = CURRENT_TIMESTAMP WHERE url = ?", [url])
        
        # Update user-specific meme_stats (if user logged in)
        if user_id
          DB.execute(
            "INSERT OR IGNORE INTO user_meme_stats (user_id, meme_url, liked, liked_at) VALUES (?, ?, 1, CURRENT_TIMESTAMP)",
            [user_id, url]
          )
          DB.execute(
            "UPDATE user_meme_stats SET liked = 1, liked_at = CURRENT_TIMESTAMP, unliked_at = NULL, updated_at = CURRENT_TIMESTAMP WHERE user_id = ? AND meme_url = ?",
            [user_id, url]
          )
          
          # GAMIFICATION: Award XP for liking + update leaderboard
          begin
            xp_result = add_xp(user_id, :like_meme)
            session[:last_xp_gain] = xp_result if xp_result
            update_weekly_leaderboard(user_id, 1)
          rescue => e
            puts "⚠️ XP/Leaderboard error: #{e.message}"
          end
        end
        session[:meme_like_counts][url] = true
      elsif !liked_now && was_liked_before
        # Unliking after having liked in this session
        DB.execute("UPDATE meme_stats SET likes = likes - 1, updated_at = CURRENT_TIMESTAMP WHERE url = ? AND likes > 0", [url])
        
        # Update user-specific meme_stats (if user logged in)
        if user_id
          DB.execute(
            "UPDATE user_meme_stats SET liked = 0, unliked_at = CURRENT_TIMESTAMP, updated_at = CURRENT_TIMESTAMP WHERE user_id = ? AND meme_url = ?",
            [user_id, url]
          )
        end
        session[:meme_like_counts][url] = false
      end

      likes = DB.execute("SELECT likes FROM meme_stats WHERE url = ?", [url]).first&.dig("likes").to_i
      RedisService.set("meme:likes:#{url}", likes, ttl: 300)  # MIGRATED: 5 min cache (Phase 3 Week 1)
      likes
    end

    # Flatten memes from YAML structure
    def flatten_memes
      return [] unless MEMES.is_a?(Hash)
      MEMES.values.flatten.compact
    end

    # Safely execute DB queries
    def safe_db_exec(query, params = [])
      return nil unless defined?(DB) && DB
      DB.execute(query, params)
    rescue => e
      puts "DB Error: #{e.message}"
      nil
    end

    # Pre-validate image URL (HEAD request to check if accessible)
    def is_image_accessible?(url)
      return false unless url&.match?(/^https?:\/\//)
      
      begin
        uri = URI(url)
        response = Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == 'https', read_timeout: 5, open_timeout: 5) do |http|
          http.head(uri.request_uri)
        end
        
        # Check if response indicates accessible image
        response.code == "200" && response["Content-Type"]&.include?("image")
      rescue
        false
      end
    end

    # Track broken image URL
    def report_broken_image(url)
      return unless url
      
      begin
        DB.execute(
          "INSERT INTO broken_images (url, failure_count) VALUES (?, 1) ON CONFLICT(url) DO UPDATE SET failure_count = failure_count + 1, last_failed_at = CURRENT_TIMESTAMP",
          [url]
        )
      rescue => e
        puts "Error tracking broken image: #{e.message}"
      end
    end

    # Check if URL is known to be broken
    def is_image_broken?(url)
      return false unless url
      
      begin
        result = DB.execute("SELECT failure_count FROM broken_images WHERE url = ?", [url]).first
        result && result["failure_count"].to_i >= 2
      rescue
        false
      end
    end

    # Get next valid meme (skip broken URLs)
    def get_next_valid_meme
      memes = random_memes_pool
      return nil if memes.empty?

      session[:meme_history] ||= []
      last_meme_url = session[:meme_history].last

      # Try to find a meme with working image
      attempts = 0
      max_attempts = [memes.size, 30].min
      
      while attempts < max_attempts
        candidate = memes.sample
        candidate_id = candidate["url"] || candidate["file"]
        
        # Skip if already shown or image is broken
        if candidate_id != last_meme_url && is_valid_meme?(candidate) && !is_image_broken?(candidate_id)
          meme_identifier = candidate_id
          session[:meme_history] << meme_identifier
          session[:meme_history] = session[:meme_history].last(30)
          return candidate
        end
        attempts += 1
      end

      nil
    end

    # Smart media rendering helpers
    def render_meme_with_smart_fallback(meme_data, options = {})
      SmartMediaRendererService.render_with_smart_fallback(meme_data, options)
    end

    def media_placeholder_styles
      SmartMediaRendererService.placeholder_styles
    end

    # Meme Placeholder helpers (SEO-optimized)
    def meme_placeholder
      PlaceholderImageService.get_placeholder
    end

    def render_meme_placeholder(options = {})
      PlaceholderImageService.render_html(options)
    end

    def meme_placeholder_alt_text(context: 'meme', additional_info: nil)
      PlaceholderImageService.generate_alt_text(context: context, additional_info: additional_info)
    end

    def meme_placeholder_og_tags(page_context = {})
      PlaceholderImageService.generate_og_meta_tags(page_context)
    end

    def meme_placeholder_styles
      PlaceholderImageService.generate_styles
    end

    def meme_placeholder_preload_tag
      PlaceholderImageService.generate_preload_tag
    end
    
    # Legacy aliases for backward compatibility
    alias_method :tattoo_annie_placeholder, :meme_placeholder
    alias_method :render_tattoo_annie, :render_meme_placeholder
    alias_method :tattoo_annie_alt_text, :meme_placeholder_alt_text
    alias_method :tattoo_annie_og_tags, :meme_placeholder_og_tags
    alias_method :tattoo_annie_styles, :meme_placeholder_styles
    alias_method :tattoo_annie_preload_tag, :meme_placeholder_preload_tag
    
    # Check if meme has valid media URL
    def has_valid_media?(meme)
      return false unless meme.is_a?(Hash)
      
      url = meme["url"] || meme["file"]
      return false unless url.is_a?(String) && !url.strip.empty?
      
      # Remote URLs: Accept all valid HTTP/HTTPS URLs (API memes)
      if url.match?(/^https?:\/\//)
        # Reject Reddit comment/post URLs (these would show fallback images)
        return false if url.include?('/r/') && url.include?('/comments/')
        
        # Accept all other HTTP/HTTPS URLs - these are API memes from Reddit
        # This includes:
        # - Direct image URLs (i.redd.it, i.imgur.com, etc.)
        # - Preview URLs (preview.redd.it)
        # - Gallery URLs with media metadata
        # - URLs with preview data in the meme object
        return true
      end
      
      # Local files: check existence (handles both relative and absolute paths)
      begin
        # Normalize path (add leading slash if not present)
        normalized_path = url.start_with?('/') ? url : "/#{url}"
        public_folder = defined?(settings) && settings.respond_to?(:public_folder) ? settings.public_folder : 'public'
        file_path = File.join(public_folder, normalized_path)
        return File.exist?(file_path)
      rescue => e
        puts "⚠️  [VALIDATION] Error checking local file #{url}: #{e.message}"
        return false
      end
    end
  end

  # -----------------------
  # Routes
  # -----------------------
  
  # AdSense ads.txt file - serve as plain text
  get "/ads.txt" do
    content_type 'text/plain'
    File.read('ads.txt')
  end
  
  get "/" do
    begin
      # FAST: Serve from pre-warmed cache (instant)
      @meme = MEME_CACHE[:memes].sample rescue nil
      @meme ||= fallback_meme
    rescue => e
      puts "Error in root route: #{e.class}: #{e.message}"
      @meme = fallback_meme
    end
    
    @image_src = meme_image_src(@meme)
    @likes = 0  # Will be loaded by JS
    
    # ASYNC: Track analytics in background (non-blocking) - Use thread pool
    ANALYTICS_POOL.post do
      begin
        user_id = session[:user_id] rescue nil
        meme_identifier = @meme["url"] || @meme["file"]
        return unless meme_identifier
        
        # Track view
        DB.execute(
          "INSERT INTO meme_stats (url, title, subreddit, views, likes) VALUES (?, ?, ?, 1, 0) ON CONFLICT(url) DO UPDATE SET views = views + 1, updated_at = CURRENT_TIMESTAMP",
          [meme_identifier, @meme["title"] || "Unknown", @meme["subreddit"] || "local"]
        ) rescue nil
        
        # Track exposure for spaced repetition
        if user_id
          DB.execute(
            "INSERT INTO user_meme_exposure (user_id, meme_url, shown_count) VALUES (?, ?, 1) ON CONFLICT(user_id, meme_url) DO UPDATE SET shown_count = shown_count + 1, last_shown = CURRENT_TIMESTAMP",
            [user_id, meme_identifier]
          ) rescue nil
        end
      rescue => e
        AppLogger.error("Background analytics tracking failed", error: e.message, meme: meme_identifier)
      end
    end
    
    erb :random
  end

  # Render random meme page
  get "/random" do
    begin
      # FAST: Serve from pre-warmed cache (instant)
      # If cache is empty or only has local memes, fallback to fresh pool
      if MEME_CACHE[:memes].is_a?(Array) && !MEME_CACHE[:memes].empty?
        @meme = MEME_CACHE[:memes].sample
      else
        # Cache empty or invalid - rebuild from scratch
        @meme = random_memes_pool.sample
      end
      @meme ||= fallback_meme
    rescue => e
      puts "Error in /random route: #{e.class}: #{e.message}"
      @meme = fallback_meme
    end
    
    @image_src = meme_image_src(@meme)
    @likes = 0  # Will be loaded by JS
    
    # GAMIFICATION: Track view count and check for milestones/rewards
    begin
      require_relative './lib/services/milestone_service'
      
      # Increment view count (session-based, works for everyone)
      session[:view_count] ||= 0
      session[:view_count] += 1
      
      # Check if milestone reached
      milestone = MilestoneService.check_milestone(session[:view_count])
      if milestone
        @milestone = milestone
        # Award to DB if logged in
        if session[:user_id]
          MilestoneService.award_milestone(session[:user_id], milestone) rescue nil
        end
      end
      
      # Get progress to next milestone
      @progress = MilestoneService.get_progress(session[:view_count])
      
      # Surprise rewards (10% chance)
      if rand < 0.10
        @surprise_reward = {
          icon: ["🎁", "⚡", "🛡️", "🔥", "💎"].sample,
          title: ["Bonus XP!", "Double XP!", "Streak Freeze!", "Lucky You!", "Jackpot!"].sample,
          message: ["You earned bonus points!", "Your next meme counts double!", "Your streak is protected!", "Keep the momentum going!", "Fortune favors the bold!"].sample
        }
      end
    rescue => e
      puts "⚠️ Gamification error: #{e.message}"
      # Don't break page if gamification fails
      @milestone = nil
      @progress = nil
      @surprise_reward = nil
    end
  
    # Determine reddit_path for this specific image
    @reddit_path = nil
    begin
      if @meme["reddit_post_urls"]&.is_a?(Array)
        post_url = @meme["reddit_post_urls"].find { |u| u.include?(@image_src) }
        @reddit_path = post_url
      end
    
      # Fallback to permalink from API meme
      if !@reddit_path && @meme["permalink"]
        permalink_str = @meme["permalink"].to_s.strip
        if permalink_str != ""
          @reddit_path = permalink_str
          # Strip domain if full URL
          @reddit_path = URI.parse(@reddit_path).path if @reddit_path.start_with?("http")
        end
      end
    rescue => e
      puts "⚠️ Reddit path error: #{e.message}"
    end
    
    # ASYNC: Track analytics in background (non-blocking) - Use thread pool
    ANALYTICS_POOL.post do
      begin
        user_id = session[:user_id] rescue nil
        meme_identifier = @meme["url"] || @meme["file"]
        return unless meme_identifier
        
        # Track view
        DB.execute(
          "INSERT INTO meme_stats (url, title, subreddit, views, likes) VALUES (?, ?, ?, 1, 0) ON CONFLICT(url) DO UPDATE SET views = views + 1, updated_at = CURRENT_TIMESTAMP",
          [meme_identifier, @meme["title"] || "Unknown", @meme["subreddit"] || "local"]
        ) rescue nil
        
        # Track exposure for spaced repetition
        if user_id
          DB.execute(
            "INSERT INTO user_meme_exposure (user_id, meme_url, shown_count) VALUES (?, ?, 1) ON CONFLICT(user_id, meme_url) DO UPDATE SET shown_count = shown_count + 1, last_shown = CURRENT_TIMESTAMP",
            [user_id, meme_identifier]
          ) rescue nil
        end
      rescue => e
        AppLogger.error("Background analytics tracking failed", error: e.message, meme: meme_identifier)
      end
    end

    erb :random
  end
  
  get "/random.json" do
    puts "🔄 [/random.json] Request received"
    
    # Use random_memes_pool for ALL users (both auth and non-auth) to ensure API memes are always available
    # This fixes the OAuth issue where new users only saw local memes
    puts "🔄 [/random.json] Calling random_memes_pool..."
    memes = random_memes_pool
    puts "✅ [/random.json] Got #{memes.size} memes from pool"
    
    halt 404, { error: "No memes found" }.to_json if memes.empty?
    
    # CDN caching - 1 hour for meme data
    headers "Cache-Control" => "public, max-age=3600"
    headers "ETag" => Digest::MD5.hexdigest(memes.to_json)
    
    # Track in session history and pick from pool
    session[:meme_history] ||= []
    session[:last_subreddit] ||= nil
    last_meme_url = session[:meme_history].last
    
    # Find a new meme that's different from last shown
    @meme = nil
    attempts = 0
    max_attempts = [memes.size, 30].min
    
    while attempts < max_attempts
      candidate = memes.sample
      candidate_id = candidate["url"] || candidate["file"]
      
      if candidate_id && candidate_id != last_meme_url
        @meme = candidate
        break
      end
      attempts += 1
    end
    
    halt 404, { error: "No valid meme found" }.to_json if @meme.nil?
    puts "✅ [/random.json] Found valid meme: #{@meme['title']}"
    
    # Track in session history
    meme_identifier = @meme["url"] || @meme["file"]
    session[:meme_history] << meme_identifier
    session[:meme_history] = session[:meme_history].last(50)  # Hard cap: 50 (reduced from 100)
    session[:last_subreddit] = @meme["subreddit"]&.downcase
    
    image_url = @meme["url"] || @meme["file"]
    
    reddit_path = nil
    if @meme["reddit_post_urls"]&.is_a?(Array)
      post_url = @meme["reddit_post_urls"].find { |u| u.include?(image_url) }
      reddit_path = post_url
    end
    
    # Try to get permalink from meme
    if !reddit_path && @meme["permalink"].to_s.strip != ""
      reddit_path = @meme["permalink"]
    end
    
    # Strip domain if full URL
    if reddit_path&.start_with?("http")
      uri = URI.parse(reddit_path)
      reddit_path = uri.path
    end
    
    # Track view in meme_stats if it's an API meme (not local file)
    if !image_url.start_with?("/")
      meme_title = @meme["title"] || "Unknown"
      meme_subreddit = @meme["subreddit"] || "reddit"
      DB.execute(
        "INSERT INTO meme_stats (url, title, subreddit, views, likes) VALUES (?, ?, ?, 1, 0) ON CONFLICT(url) DO UPDATE SET views = views + 1, updated_at = CURRENT_TIMESTAMP",
        [image_url, meme_title, meme_subreddit]
      ) rescue nil
    end
    
    # Extract preview images for client-side fallback chain
    preview_images = extract_preview_images(@meme)
    media_type = detect_media_type(image_url)
    
    response_data = {
      title: @meme["title"],
      subreddit: @meme["subreddit"],
      file: @meme["file"],
      url: image_url,
      reddit_path: reddit_path,
      likes: get_meme_likes(image_url),
      preview_images: preview_images,
      media_type: media_type
    }
    
    content_type :json
    puts "✅ [/random.json] Returning response with #{preview_images.size} preview images..."
    response_data.to_json
  end
  
  # ========================================================================
  # P2 WEEK 2: REFACTORED ROUTES - Old implementations below (commented out)
  # NEW MODULAR ROUTES: routes/meme_stats.rb, routes/trending_routes.rb, routes/search_routes.rb
  # ========================================================================
  
  # post "/like" - NOW IN routes/meme_stats.rb
  # post "/report-broken-image" - NOW IN routes/meme_stats.rb
  # get "/trending" - NOW IN routes/trending_routes.rb
  # before "/category/*" - NOW IN routes/trending_routes.rb
  # get "/category/:name" - NOW IN routes/trending_routes.rb
  # get "/category/:name/meme/:title" - NOW IN routes/trending_routes.rb

  # Smart Hybrid Search helper method - KEPT for use by route modules
  def search_memes(query)
    return [] unless query
    
    # SECURITY FIX: Use Validators to prevent SQL injection

    
    begin

    
      sanitized_query = Validators.validate_search_query(query, min_length: 1, max_length: 200)

    
    rescue Validators::ValidationError => e

    
      AppLogger.warn("Invalid search query", query: query, error: e.message)

    
      return []

    
    end
    
    query_lower = sanitized_query.downcase
    
    # Tier 1: Search in-memory cache (instant, fresh Reddit memes)
    cache_results = (MEME_CACHE[:memes] || []).select do |m|
      (m["title"]&.downcase&.include?(query_lower) ||
       m["subreddit"]&.downcase&.include?(query_lower))
    end
    
    # Tier 2: If too few results, hit API for niche queries
    if cache_results.size < 3
      api_results = (fetch_reddit_memes(POPULAR_SUBREDDITS, 30) rescue []).select do |m|
        m["title"]&.downcase&.include?(query_lower) ||
        m["subreddit"]&.downcase&.include?(query_lower)
      end
      cache_results = (cache_results + api_results).uniq { |m| m["url"] }
    end
    
    # Tier 3: Fall back to DB + YAML if still empty
    # SECURITY FIX: Proper parameterized query with ESCAPE clause
    if cache_results.empty?
      db_results = (DB.execute(
        "SELECT * FROM meme_stats WHERE title LIKE '%' || ? || '%' ESCAPE '\\' COLLATE NOCASE LIMIT 100",
        [sanitized_query]
      ) rescue []).map { |r| r.transform_keys(&:to_s) }
      yaml_results = flatten_memes.select { |m| m["title"]&.downcase&.include?(query_lower) }
      cache_results = (db_results + yaml_results).uniq { |m| m["url"] || m["file"] }
    end
    
    # Rank results: exact match > title match > subreddit match, then by engagement
    ranked = cache_results.sort_by do |m|
      title = m["title"]&.downcase || ""
      subreddit = m["subreddit"]&.downcase || ""
      likes = m["likes"].to_i
      views = m["views"].to_i
      
      exact_match = title == query_lower ? 0 : 1
      title_match = title.include?(query_lower) ? 0 : 1
      subreddit_match = subreddit.include?(query_lower) ? 2 : 3
      engagement = -(likes * 2 + views) # Negative to sort descending
      
      [exact_match, title_match, subreddit_match, engagement]
    end
    
    ranked
  end

  # get "/search" - NOW IN routes/search_routes.rb
  # get "/api/search.json" - NOW IN routes/search_routes.rb

  get "/metrics.json" do
    total_memes = DB.get_first_value("SELECT COUNT(*) FROM meme_stats") || 0
    total_likes = DB.get_first_value("SELECT SUM(likes) FROM meme_stats") || 0
    total_views = DB.get_first_value("SELECT COALESCE(SUM(views), 0) FROM meme_stats") || 0

    avg_likes = total_memes.to_i > 0 ? (total_likes.to_f / total_memes.to_i).round(2) : 0
    avg_views = total_memes.to_i > 0 ? (total_views.to_f / total_memes.to_i).round(2) : 0

    content_type :json
    {
      total_memes: total_memes,
      total_likes: total_likes,
      total_views: total_views,
      avg_likes: avg_likes,
      avg_views: avg_views
    }.to_json
  end

  get "/metrics" do
    # Initialize defaults first
    @total_memes         = 0
    @total_likes         = 0
    @total_views         = 0
    @total_users         = 0
    @total_saved_memes   = 0
    @memes_with_no_likes = 0
    @memes_with_no_views = 0
    @avg_likes           = 0
    @avg_views           = 0
    @top_memes           = []
    @top_subreddits      = []

    begin
      if defined?(DB) && DB
        # Get meme stats
        @total_memes = (DB.get_first_value("SELECT COUNT(*) FROM meme_stats") || 0).to_i
        @total_likes = (DB.get_first_value("SELECT COALESCE(SUM(likes), 0) FROM meme_stats") || 0).to_i
        @total_views = (DB.get_first_value("SELECT SUM(views) FROM meme_stats") || 0).to_i
        @total_users = (DB.get_first_value("SELECT COUNT(*) FROM users") || 0).to_i
        @total_saved_memes = (DB.get_first_value("SELECT COUNT(*) FROM saved_memes") || 0).to_i
        @memes_with_no_likes = (DB.get_first_value("SELECT COUNT(*) FROM meme_stats WHERE likes = 0") || 0).to_i
        @memes_with_no_views = (DB.get_first_value("SELECT COUNT(*) FROM meme_stats WHERE views = 0") || 0).to_i

        # Calculate averages
        @avg_likes = @total_memes > 0 ? (@total_likes.to_f / @total_memes).round(2) : 0
        @avg_views = @total_memes > 0 ? (@total_views.to_f / @total_memes).round(2) : 0

        # Top memes (DB already returns hashes with results_as_hash = true)
        @top_memes = DB.execute("
          SELECT title, subreddit, url, likes, views
          FROM meme_stats
          ORDER BY (likes * 2 + views) DESC
          LIMIT 10
        ")

        # Top subreddits
        @top_subreddits = DB.execute("
          SELECT subreddit, SUM(likes) AS total_likes, COUNT(*) AS count
          FROM meme_stats
          GROUP BY subreddit
          ORDER BY total_likes DESC
          LIMIT 10
        ")
      end
    rescue => e
      puts "Metrics error: #{e.class}: #{e.message}"
    end

    erb :metrics
  end

  # -----------------------
  # Authentication Routes
  # -----------------------
  # Auth routes are now handled by routes/auth.rb
  # This eliminates duplicate routes and uses proper validation

  # -----------------------
  # Gamification Routes
  # -----------------------
  
  # Enhanced Leaderboard Route with Advanced Features + Fallback
  get "/leaderboard" do
    puts "🏆 [LEADERBOARD] Route accessed"
    
    # Initialize all variables with safe defaults
    @leaderboard_type = params[:type]&.to_sym || :all_time
    @current_period = params[:period]
    @leaderboard = []
    @user_rank = nil
    @rank_change = nil
    @nearby = []
    @insights = []
    @challenge = nil
    @challenge_progress = nil
    @previous_periods = []
    
    # PRIMARY: Try advanced LeaderboardService (gracefully falls back to simple version)
    @leaderboard = begin
      if @leaderboard_type == :weekly && @current_period.nil?
        # For weekly default, try simple method first (faster)
        puts "🏆 [LEADERBOARD] Using simple weekly leaderboard"
        get_leaderboard || []
      else
        # For other types or specific periods, use LeaderboardService
        puts "🏆 [LEADERBOARD] Using LeaderboardService (type: #{@leaderboard_type})"
        LeaderboardService.get_leaderboard(
          type: @leaderboard_type,
          period: @current_period,
          limit: 25
        )
      end
    rescue => e
      puts "⚠️ [LEADERBOARD] Advanced service failed: #{e.message}, falling back to simple"
      @leaderboard_type = :weekly  # Reset to weekly on error
      get_leaderboard rescue []
    end
    
    puts "🏆 [LEADERBOARD] Got #{@leaderboard.size} entries"
    
    # Mark current user in leaderboard
    if session[:user_id] && @leaderboard.any?
      @leaderboard.each do |entry|
        entry['is_current_user'] = (entry['user_id'].to_i == session[:user_id].to_i)
      end
    end
    
    # ADVANCED FEATURES (only if user is logged in)
    if session[:user_id]
      # Get user's rank with advanced details
      @user_rank = begin
        LeaderboardService.get_user_rank(
          session[:user_id],
          type: @leaderboard_type,
          period: @current_period
        )
      rescue => e
        puts "⚠️ [LEADERBOARD] get_user_rank failed: #{e.message}"
        # Fallback: find in current leaderboard
        @leaderboard.find { |e| e['user_id'].to_i == session[:user_id].to_i }
      end
      
      if @user_rank
        # Get rank change from previous period
        @rank_change = begin
          LeaderboardService.rank_change(session[:user_id], type: @leaderboard_type)
        rescue => e
          puts "⚠️ [LEADERBOARD] rank_change failed: #{e.message}"
          nil
        end
        
        # Get nearby competitors
        @nearby = begin
          LeaderboardService.get_nearby_ranks(
            session[:user_id],
            type: @leaderboard_type,
            range: 5,
            period: @current_period
          )
        rescue => e
          puts "⚠️ [LEADERBOARD] get_nearby_ranks failed: #{e.message}"
          []
        end
        
        # Generate insights
        current_rank = @user_rank['rank'].to_i
        if current_rank > 10
          gap_analysis = begin
            LeaderboardService.rank_gap_analysis(
              session[:user_id],
              10,
              type: @leaderboard_type,
              period: @current_period
            )
          rescue => e
            puts "⚠️ [LEADERBOARD] rank_gap_analysis failed: #{e.message}"
            nil
          end
          
          if gap_analysis
            @insights << {
              icon: '🎯',
              text: "You need #{gap_analysis[:gap]} more points to reach the top 10!"
            }
          end
        elsif current_rank <= 3
          @insights << {
            icon: '🏆',
            text: "Amazing! You're in the top 3!"
          }
        elsif current_rank <= 10
          @insights << {
            icon: '⭐',
            text: "Great job! You're in the top 10!"
          }
        end
        
        # Rank improvement insight
        if @rank_change && @rank_change[:change] && @rank_change[:change] > 0
          @insights << {
            icon: '📈',
            text: "You've climbed #{@rank_change[:change]} positions!"
          }
        end
      end
    end
    
    # Get weekly challenge
    @challenge = current_weekly_challenge rescue nil
    
    # Generate previous periods for dropdown (for weekly/monthly types)
    if @leaderboard_type == :weekly || @leaderboard_type == :monthly
      @previous_periods = begin
        periods = []
        current = LeaderboardService.current_period(@leaderboard_type)
        5.times do |i|
          period = LeaderboardService.previous_period(@leaderboard_type, current)
          label = if @leaderboard_type == :weekly
            date = Date.strptime(period.to_s + '1', '%Y%U%u')
            "Week of #{date.strftime('%b %d, %Y')}"
          else
            year = period.to_s[0..3]
            month = period.to_s[4..5]
            Date.new(year.to_i, month.to_i).strftime('%B %Y')
          end
          
          periods << { value: period, label: label }
          current = period
        end
        periods
      rescue => e
        puts "⚠️ [LEADERBOARD] previous_periods generation failed: #{e.message}"
        []
      end
    end
    
    puts "🏆 [LEADERBOARD] Rendering view..."
    erb :leaderboard
  end
  
  # API Endpoint for AJAX leaderboard updates
  get "/api/leaderboard" do
    content_type :json
    
    begin
      type = (params[:type] || 'weekly').to_sym
      period = params[:period]
      limit = (params[:limit] || 25).to_i
      offset = (params[:offset] || 0).to_i
      
      # Get leaderboard data
      leaderboard = LeaderboardService.get_leaderboard(
        type: type,
        period: period,
        limit: limit,
        offset: offset
      )
      
      # Mark current user
      if session[:user_id]
        leaderboard.each do |entry|
          entry['is_current_user'] = (entry['user_id'].to_i == session[:user_id].to_i)
        end
      end
      
      # Get user rank and nearby competitors
      user_rank = nil
      rank_change = nil
      nearby = []
      insights = {}
      
      if session[:user_id]
        user_rank = LeaderboardService.get_user_rank(
          session[:user_id],
          type: type,
          period: period
        )
        
        if user_rank
          rank_change = LeaderboardService.rank_change(session[:user_id], type: type)
          nearby = LeaderboardService.get_nearby_ranks(
            session[:user_id],
            type: type,
            range: 5,
            period: period
          )
          
          # Generate insights
          current_rank = user_rank['rank'].to_i
          if current_rank > 10
            gap_analysis = LeaderboardService.rank_gap_analysis(
              session[:user_id],
              10,
              type: type,
              period: period
            )
            insights[:gap_to_top10] = gap_analysis[:gap] if gap_analysis
          end
        end
      end
      
      # Get challenge
      challenge = current_weekly_challenge
      
      {
        success: true,
        leaderboard: leaderboard,
        user_rank: user_rank,
        rank_change: rank_change,
        nearby: nearby,
        insights: insights,
        challenge: challenge
      }.to_json
    rescue => e
      puts "❌ API Leaderboard error: #{e.message}"
      {
        success: false,
        error: e.message
      }.to_json
    end
  end

  # -----------------------
  # User Profile & Features
  # -----------------------
  get "/profile" do
    # Check session safely
    user_id = session[:user_id] rescue nil
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
        puts "Error fetching liked memes: #{e.message}"
        []
      end
  
    rescue => e
      # Log the error and return proper error response
      puts "Profile Error: #{e.class}: #{e.message}"
      puts e.backtrace.join("\n")
      halt 500, "Error loading profile: #{e.message}"
    end
  
    # Count stats
    @saved_count = @saved_memes.size
    @liked_count = @liked_memes.size
  
    erb :profile
  end
  

  post "/api/save-meme" do
    halt 401, { error: "Not logged in" }.to_json unless session[:user_id]

    url = params[:url]
    title = params[:title]
    subreddit = params[:subreddit]

    halt 400, { error: "URL required" }.to_json unless url

    save_meme(session[:user_id], url, title, subreddit)

    content_type :json
    { saved: true, message: "Meme saved" }.to_json
  end

  post "/api/unsave-meme" do
    halt 401, { error: "Not logged in" }.to_json unless session[:user_id]

    url = params[:url]
    halt 400, { error: "URL required" }.to_json unless url

    unsave_meme(session[:user_id], url)

    content_type :json
    { unsaved: true, message: "Meme unsaved" }.to_json
  end

  # -----------------------
  # Push Notification API (Priority 1)
  # -----------------------
  post "/api/subscribe-push" do
    halt 401, { error: "Not logged in" }.to_json unless session[:user_id]
    
    begin
      subscription_data = JSON.parse(request.body.read)
      subscription_json = subscription_data.to_json
      
      # Store subscription in database (SQLite-compatible)
      # Check if subscription already exists
      existing = DB.execute(
        "SELECT id FROM push_subscriptions WHERE user_id = ? AND subscription_data = ?",
        [session[:user_id], subscription_json]
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
          [session[:user_id], subscription_json]
        )
      end
      
      puts "✅ Push subscription saved for user #{session[:user_id]}"
      
      content_type :json
      { success: true, message: "Push subscription saved" }.to_json
    rescue => e
      puts "❌ Push subscription error: #{e.message}"
      halt 500, { error: "Failed to save subscription", details: e.message }.to_json
    end
  end

  # Test endpoint for admins to send test notifications
  post "/api/test-push" do
    halt 401 unless session[:user_id]
    halt 403 unless is_admin?
    
    begin
      PushNotificationService.send_custom(
        session[:user_id],
        "🔥 Test Notification",
        "Your push notifications are working perfectly!",
        "/random"
      )
      
      content_type :json
      { success: true, message: "Test notification sent" }.to_json
    rescue => e
      puts "❌ Test push error: #{e.message}"
      halt 500, { error: e.message }.to_json
    end
  end

  # -----------------------
  # Surprise Rewards API (Priority 2)
  # -----------------------
  get "/api/surprise-rewards/check" do
    halt 401 unless session[:user_id]
    
    begin
      # Check if user has pending reward
      reward = session.delete(:pending_surprise_reward)
      
      content_type :json
      { reward: reward }.to_json
    rescue => e
      puts "❌ Surprise reward check error: #{e.message}"
      halt 500, { error: e.message }.to_json
    end
  end

  get "/api/surprise-rewards/active-boosts" do
    halt 401 unless session[:user_id]
    
    begin
      boosts = SurpriseRewardsService.active_boosts(session[:user_id])
      
      content_type :json
      { boosts: boosts }.to_json
    rescue => e
      puts "❌ Active boosts error: #{e.message}"
      halt 500, { error: e.message }.to_json
    end
  end

  get "/saved/:id" do
    # FIX: IDOR vulnerability - require authentication and authorization
    halt 401, "Not logged in" unless session[:user_id]
    
    saved_id = params[:id].to_i
    saved_meme = DB.execute(
      "SELECT * FROM saved_memes WHERE id = ? AND user_id = ?", 
      [saved_id, session[:user_id]]
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
  get "/health" do
    content_type :json
    HealthCheckService.quick_check.to_json
  end
  
  # Detailed health check (admin only)
  get "/health/detailed" do
    halt 403, { error: "Forbidden" }.to_json unless is_admin?
    content_type :json
    HealthCheckService.check.to_json
  end
  
  # Performance metrics (admin only)
  get "/metrics/performance" do
    halt 403, { error: "Forbidden" }.to_json unless is_admin?
    content_type :json
    PerformanceProfiler.summary.to_json
  end

  get "/errors" do
    halt 403, "Forbidden" unless is_admin?
    content_type :json
    {
      recent_errors: ErrorHandler::Logger.recent(50),
      error_rate_5m: ErrorHandler::Logger.error_rate(300),
      critical_errors_5m: ErrorHandler::Logger.critical_errors(300),
      error_patterns: ErrorHandler::ErrorPatterns.top_errors(10)
    }.to_json
  end

  get "/api/notifications" do
    halt 401, { error: "Not logged in" }.to_json unless session[:user_id]
    user_id = session[:user_id]
    
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
before '/admin/*' do
  halt 403, { error: "Forbidden - Admin access required" }.to_json unless is_admin?
end

# -----------------------
# Admin Authorization Filter (P0 Security Fix)
# -----------------------
before '/admin/*' do
  halt 403, { error: "Forbidden - Admin access required" }.to_json unless is_admin?
end

  # -----------------------
  # Admin Routes
  # -----------------------
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
        
        puts "👤 [USER FEEDBACK] Broken content reported: #{url} (from #{page})"
        
        { success: true, message: 'Thank you for your feedback!' }.to_json
      else
        halt 500, { success: false, error: 'Service unavailable' }.to_json
      end
    rescue JSON::ParserError => e
      halt 400, { success: false, error: 'Invalid JSON' }.to_json
    rescue => e
      puts "❌ [USER FEEDBACK] Error: #{e.message}"
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
      puts "❌ [Activity Stats] Error: #{e.message}"
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
  use Routes::ABTesting
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
      uptime_seconds: (Time.now - $start_time).to_i,
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
end  # End of MemeExplorer module
