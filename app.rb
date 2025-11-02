
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

require_relative "./db/setup"
require_relative "./lib/error_handler"
require "digest"

# Sentry Error Tracking (if configured)
begin
  require 'sentry-ruby'
  require_relative './config/sentry'
rescue LoadError
  puts "⚠️  Sentry not available - error tracking disabled"
end


$VERBOSE = nil # suppress warnings

# -----------------------
# Main App
# -----------------------
class MemeExplorer < Sinatra::Base
  # -----------------------
  # Redis & DB
  # -----------------------
  REDIS_URL = ENV.fetch("REDIS_URL", "rediss://red-d42v6u24d50c73a5goqg:UD3EpN1aQXznpIRseNj0ULS0qRNo8SvS@oregon-keyvalue.render.com:6379")
  REDIS = begin
    Redis.new(url: REDIS_URL)
  rescue
    nil
  end
  DB = ::DB

  # -----------------------
  # Rack::Attack
  # -----------------------
  Rack::Attack.cache.store = ActiveSupport::Cache::RedisCacheStore.new(url: REDIS_URL) if REDIS
  class Rack::Attack
    safelist("allow-localhost") { |req| ["127.0.0.1", "::1"].include?(req.ip) }
    throttle("req/ip", limit: 60, period: 60) { |req| req.ip unless req.path.start_with?("/assets") }
    self.throttled_responder = lambda do |_env|
      [429, { "Content-Type" => "application/json" }, [{ error: "Too many requests" }.to_json]]
    end
  end
  use Rack::Attack

  # -----------------------
  # Constants
  # -----------------------
  POPULAR_SUBREDDITS = YAML.load_file("data/subreddits.yml")["popular"]
  ALL_POPULAR_SUBS = POPULAR_SUBREDDITS.sample(50)
  MEME_CACHE = { memes: [], last_refresh: nil, rate_limit_reset: nil }
  MEMES = YAML.load_file("data/memes.yml") rescue []
  METRICS = Hash.new(0).merge(avg_request_time_ms: 0.0)

  # -----------------------
  # Configuration
  # -----------------------
  configure do
    set :server, :puma
    enable :sessions
    set :session_secret, ENV.fetch("SESSION_SECRET", "fallback-secret-key-default")
    set :cookie_options, {
      secure: true,
      httponly: true,
      same_site: :lax
    }
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

  # Load tier configuration
  TIER_CONFIG = YAML.load_file("data/subreddits.yml") rescue {}
  TIER_WEIGHTS = {
    tier_1: 50,   # 50% - Best Content
    tier_2: 25,   # 25% - Excellent Content
    tier_3: 15,   # 15% - Very Good
    tier_4: 10,   # 10% - Good
    tier_5: 8,    # 8%  - Decent
    tier_6: 6,    # 6%  - Niche (Tech)
    tier_7: 4,    # 4%  - Niche (Business)
    tier_8: 2,    # 2%  - Niche (Stocks)
    tier_9: 2,    # 2%  - Niche (Music)
    tier_10: 1    # 1%  - Niche (Sports)
  }
  TOTAL_TIER_WEIGHT = TIER_WEIGHTS.values.sum

  # Pre-warm cache immediately on startup with LOCAL MEMES ONLY (non-blocking)
  Thread.new do
    begin
      puts "🔥 Pre-warming cache with local memes..."
      
      local_memes = begin
        yaml_data = YAML.load_file("data/memes.yml")
        if yaml_data.is_a?(Hash)
          yaml_data.values.flatten.compact
        else
          yaml_data || []
        end
      rescue
        []
      end
      
      MEME_CACHE[:memes] = local_memes.shuffle
      MEME_CACHE[:last_refresh] = Time.now
      puts "✅ Cache pre-warmed with #{local_memes.size} local memes (Reddit memes loading in background)"
    rescue => e
      puts "⚠️ Cache init error: #{e.class}"
    end
  end

  # Background cache refresh - OAuth2 with fallback to local memes (60 second interval, non-blocking)
  Thread.new do
    sleep 10  # Wait for app to fully start
    loop do
      begin
        # Always start with local memes as fallback
        local_memes = begin
          yaml_data = YAML.load_file("data/memes.yml")
          if yaml_data.is_a?(Hash)
            yaml_data.values.flatten.compact
          else
            yaml_data || []
          end
        rescue
          []
        end

        if REDDIT_OAUTH_CLIENT_ID.to_s.strip.empty? || REDDIT_OAUTH_CLIENT_SECRET.to_s.strip.empty?
          puts "⚠️ Missing Reddit OAuth credentials - using local memes only"
          MEME_CACHE[:memes] = local_memes.shuffle
          MEME_CACHE[:last_refresh] = Time.now
          sleep 60
          next
        end

        puts "🔄 Getting OAuth2 token for meme fetch..."
        client = OAuth2::Client.new(
          REDDIT_OAUTH_CLIENT_ID,
          REDDIT_OAUTH_CLIENT_SECRET,
          site: "https://www.reddit.com",
          authorize_url: "/api/v1/authorize",
          token_url: "/api/v1/access_token"
        )

        token = client.client_credentials.get_token(scope: "read")
        puts "✅ Got OAuth2 token for authenticated API"

        # Use same subreddit sampling as original random_memes_pool
        subreddits_to_fetch = POPULAR_SUBREDDITS.sample(8)
        meme_pool = MemeExplorer.fetch_reddit_memes_authenticated(token.token, subreddits_to_fetch, 30) rescue []
        puts "✓ Fetched #{meme_pool.size} memes from #{subreddits_to_fetch.size} subreddits via OAuth2"

        validated = meme_pool.select { |m| m["url"] && m["url"].match?(/^https?:\/\//) }
        
        if validated.empty?
          puts "⚠️ No valid memes from API - falling back to local memes"
          MEME_CACHE[:memes] = local_memes.shuffle
          MEME_CACHE[:rate_limit_reset] = Time.now + 3600
        else
          # Combine fresh API memes with local fallback
          all_memes = (validated + local_memes).uniq { |m| m["url"] }
          MEME_CACHE[:memes] = all_memes.shuffle
          MEME_CACHE[:rate_limit_reset] = nil
          puts "✅ Cache updated with #{validated.size} API memes + #{local_memes.size} local memes"
        end
        
        MEME_CACHE[:last_refresh] = Time.now
      rescue OAuth2::Error => e
        puts "❌ OAuth2 error: #{e.message} - falling back to local memes"
        local_memes = (YAML.load_file("data/memes.yml").values.flatten.compact rescue [])
        MEME_CACHE[:memes] = local_memes.shuffle
        MEME_CACHE[:rate_limit_reset] = Time.now + 3600
        MEME_CACHE[:last_refresh] = Time.now
      rescue => e
        puts "❌ Refresh error: #{e.class}: #{e.message}"
        local_memes = (YAML.load_file("data/memes.yml").values.flatten.compact rescue [])
        MEME_CACHE[:memes] = local_memes.shuffle
        MEME_CACHE[:last_refresh] = Time.now
      end
      sleep 60
    end
  end

  # Hourly database cleanup (non-blocking)
  Thread.new do
    sleep 3600  # Wait 1 hour before first cleanup
    loop do
      begin
        DB.execute("DELETE FROM broken_images WHERE failure_count >= 5 AND datetime(first_failed_at) < datetime('now', '-1 day')")
        DB.execute("DELETE FROM meme_stats WHERE likes = 0 AND views = 0 AND datetime(updated_at) < datetime('now', '-7 days')")
      rescue => e
        # Silent fail
      end
      sleep 3600
    end
  end

  # -----------------------
  # Request Lifecycle
  # -----------------------
  before do
    @start_time = Time.now
    @seen_memes = request.cookies["seen_memes"] ? JSON.parse(request.cookies["seen_memes"]) : []
    
    # Store large session data in Redis to avoid 4KB cookie limit
    if REDIS && session[:user_id]
      user_id = session[:user_id]
      @redis_meme_history_key = "user:#{user_id}:meme_history"
      @redis_meme_likes_key = "user:#{user_id}:meme_like_counts"
    end
  end

  after do
    duration = ((Time.now - @start_time) * 1000).round(2)
    METRICS[:total_requests] += 1
    total = METRICS[:total_requests]
    avg = METRICS[:avg_request_time_ms]
    METRICS[:avg_request_time_ms] = ((avg * (total - 1)) + duration) / total.to_f

    response.set_cookie(
      "seen_memes",
      value: @seen_memes.to_json,
      path: "/",
      expires: Time.now + 60 * 60 * 24 * 30,
      httponly: true
    )
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
            next if post_data["is_video"] || post_data["is_self"] || !post_data["url"]
            
            meme = {
              "title" => post_data["title"],
              "url" => post_data["url"],
              "subreddit" => post_data["subreddit"],
              "likes" => post_data["ups"] || 0,
              "permalink" => post_data["permalink"]
            }
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
            next if post_data["is_video"] || post_data["is_self"] || !post_data["url"]
            
            meme = {
              "title" => post_data["title"],
              "url" => post_data["url"],
              "subreddit" => post_data["subreddit"],
              "likes" => post_data["ups"] || 0
            }
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

  # -----------------------
  # Auth Helpers
  # -----------------------
  helpers do
    # Hash password with bcrypt
    def hash_password(password)
      BCrypt::Password.create(password)
    end

    # Verify password
    def verify_password(password, hash)
      BCrypt::Password.new(hash) == password
    end

    # Create or find user
    def create_or_find_user(reddit_username, reddit_id, reddit_email)
      existing = DB.execute("SELECT id FROM users WHERE reddit_id = ?", [reddit_id]).first
      return existing["id"] if existing

      DB.execute(
        "INSERT INTO users (reddit_id, reddit_username, reddit_email) VALUES (?, ?, ?)",
        [reddit_id, reddit_username, reddit_email]
      )
      DB.last_insert_row_id
    end

    # Create email/password user
    def create_email_user(email, password)
      hashed = hash_password(password)
      DB.execute(
        "INSERT INTO users (email, password_hash) VALUES (?, ?)",
        [email, hashed]
      )
      DB.last_insert_row_id
    rescue SQLite3::ConstraintException
      nil
    end

    # Find user by email
    def find_user_by_email(email)
      DB.execute("SELECT id, password_hash FROM users WHERE email = ?", [email]).first
    end

    # Get user by ID
    def get_user(user_id)
      DB.execute("SELECT id, reddit_username, email, created_at FROM users WHERE id = ?", [user_id]).first
    end

    # Check if admin
    def is_admin?
      session[:user_id] && session[:reddit_username] == "brianhkim13@gmail.com"
    end

    # Get user saved memes
    def get_user_saved_memes(user_id)
      DB.execute("SELECT id, meme_url, meme_title, meme_subreddit, saved_at FROM saved_memes WHERE user_id = ? ORDER BY saved_at DESC", [user_id])
    end

    # Save meme for user
    def save_meme(user_id, meme_url, meme_title, meme_subreddit)
      DB.execute(
        "INSERT OR IGNORE INTO saved_memes (user_id, meme_url, meme_title, meme_subreddit) VALUES (?, ?, ?, ?)",
        [user_id, meme_url, meme_title, meme_subreddit]
      )
    end

    # Unsave meme
    def unsave_meme(user_id, meme_url)
      DB.execute("DELETE FROM saved_memes WHERE user_id = ? AND meme_url = ?", [user_id, meme_url])
    end

    # Check if meme is saved by user
    def is_meme_saved?(user_id, meme_url)
      DB.execute("SELECT id FROM saved_memes WHERE user_id = ? AND meme_url = ?", [user_id, meme_url]).first
    end

    # Get user stats
    def get_user_stats(user_id)
      saved_count = DB.get_first_value("SELECT COUNT(*) FROM saved_memes WHERE user_id = ?", [user_id]).to_i
      liked_count = session[:liked_memes]&.size || 0
      { saved_count: saved_count, liked_count: liked_count }
    end

  # -----------------------
  # Helpers (continued)
  # -----------------------
    # Safely get meme image
    def meme_image_src(m)
      return "/images/funny1.jpeg" unless m.is_a?(Hash)
      m["file"].to_s.strip != "" ? m["file"] : (m["url"].to_s.strip != "" ? m["url"] : "/images/funny1.jpeg")
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

    # Phase 2: Get pool based on time of day (trending/fresh/exploration split)
    def get_intelligent_pool(user_id = nil, limit = 100)
      # 70% Trending, 20% Fresh, 10% Exploration
      trending = get_trending_pool(limit * 0.7)
      fresh = get_fresh_pool(limit * 0.2, 48)
      exploration = get_exploration_pool(limit * 0.1)
      
      pool = trending + fresh + exploration
      pool = pool.uniq { |m| m["url"] }
      
      # CRITICAL FIX: If DB is empty, fallback to local memes
      if pool.empty?
        local_memes = begin
          if MEMES.is_a?(Hash)
            MEMES.values.flatten.compact.map do |m|
              # Convert file paths: remove leading / so File.join works correctly
              m_copy = m.dup
              if m_copy["file"] && m_copy["file"].start_with?("/")
                m_copy["file"] = m_copy["file"][1..-1]  # Remove leading slash
              end
              m_copy
            end
          elsif MEMES.is_a?(Array)
            MEMES.map do |m|
              m_copy = m.dup
              if m_copy["file"] && m_copy["file"].start_with?("/")
                m_copy["file"] = m_copy["file"][1..-1]
              end
              m_copy
            end
          else
            []
          end
        rescue
          []
        end
        pool = local_memes
      end
      
      # Apply user preferences if logged in
      if user_id
        apply_user_preferences(pool, user_id)
      else
        pool.shuffle
      end
    end

    # Phase 2: Apply user preferences - boost preferred subreddits
    def apply_user_preferences(pool, user_id)
      user_prefs = DB.execute(
        "SELECT subreddit, preference_score FROM user_subreddit_preferences WHERE user_id = ? ORDER BY preference_score DESC",
        [user_id]
      )
      
      return pool.shuffle if user_prefs.empty?
      
      # Separate memes by preference
      preferred = []
      neutral = []
      
      pool.each do |meme|
        sub = meme["subreddit"]&.downcase
        pref = user_prefs.find { |p| p["subreddit"].downcase == sub }
        if pref && pref["preference_score"] > 1.0
          preferred << meme
        else
          neutral << meme
        end
      end
      
      # Return 60% preferred + 40% neutral for variety
      ratio = (preferred.size * 0.6 / [preferred.size, 1].max).to_i
      (preferred.sample(ratio) + neutral.sample((pool.size - ratio))).compact.shuffle
    end

    # Phase 2: Navigate memes with intelligent pool selection
    def navigate_meme(direction: "next")
      user_id = session[:user_id] rescue nil
      
      # STAGED ONBOARDING: New users (< 10 views) get fresh cache, established users get personalization
      is_new_user = false
      if user_id
        exposure_count = DB.execute("SELECT COUNT(*) FROM user_meme_exposure WHERE user_id = ?", [user_id]).first[0].to_i
        is_new_user = exposure_count < 10
      end
      
      # Route: new users get cache (fresh API memes), established users get personalized DB pool
      if user_id && !is_new_user
        memes = get_intelligent_pool(user_id, 100)
      else
        memes = random_memes_pool
      end
      
      # CRITICAL FIX: If no memes or all memes fail validation, use fallback
      use_fallback = memes.empty?
      
      return nil if memes.empty? && user_id.nil?

      # Initialize session tracking for subreddit diversity (OAuth-safe: ||= ensures it exists after OAuth)
      session[:meme_history] ||= []
      session[:last_subreddit] ||= nil
      last_meme_url = session[:meme_history].last

      # Get a random meme that's different from the last one shown AND from different subreddit
      new_meme = nil
      attempts = 0
      max_attempts = [memes.size, 30].min
      
      while attempts < max_attempts
        candidate = memes.sample
        candidate_id = candidate["url"] || candidate["file"]
        candidate_subreddit = candidate["subreddit"]&.downcase
        
        # Ensure:
        # 1. Different URL than last shown
        # 2. Valid meme
        # 3. Different subreddit than last (subreddit diversity)
        if candidate_id && 
           candidate_id != last_meme_url && 
           is_valid_meme?(candidate) &&
           candidate_subreddit != session[:last_subreddit]
          new_meme = candidate
          break
        end
        attempts += 1
      end

      # CRITICAL FALLBACK: If no valid meme found but user is logged in, try fallback pool
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

      # ULTIMATE FALLBACK: If still nil, just grab any meme without strict validation
      if new_meme.nil? && user_id
        memes = random_memes_pool
        new_meme = memes.first if memes.any?
      end

      return nil unless new_meme

      # Ensure meme has proper URL property set for frontend
      meme_identifier = new_meme["url"] || new_meme["file"]
      new_meme["url"] = meme_identifier if !new_meme["url"]
      
      # Ensure permalink field exists (for Reddit links)
      new_meme["permalink"] ||= ""
      
      # Track view in meme_stats - CRITICAL for accurate metrics
      meme_title = new_meme["title"] || "Unknown"
      meme_subreddit = new_meme["subreddit"] || "local"
      DB.execute(
        "INSERT INTO meme_stats (url, title, subreddit, views, likes) VALUES (?, ?, ?, 1, 0) ON CONFLICT(url) DO UPDATE SET views = views + 1, updated_at = CURRENT_TIMESTAMP",
        [meme_identifier, meme_title, meme_subreddit]
      ) rescue nil
      
      # Track history in session (properly initialized above with ||=, so safe for OAuth)
      session[:meme_history] << meme_identifier
      session[:meme_history] = session[:meme_history].last(30)
      session[:last_subreddit] = new_meme["subreddit"]&.downcase

      # Track exposure for spaced repetition (Phase 3)
      if user_id
        DB.execute(
          "INSERT INTO user_meme_exposure (user_id, meme_url, shown_count) VALUES (?, ?, 1) ON CONFLICT(user_id, meme_url) DO UPDATE SET shown_count = shown_count + 1, last_shown = CURRENT_TIMESTAMP",
          [user_id, meme_identifier]
        ) rescue nil
      end

      new_meme
    end

    # Phase 2: Update user preference when they like a meme
    def update_user_preference(user_id, subreddit)
      return unless user_id && subreddit
      
      subreddit = subreddit.downcase
      DB.execute(
        "INSERT INTO user_subreddit_preferences (user_id, subreddit, preference_score, times_liked) VALUES (?, ?, 1.0, 1) ON CONFLICT(user_id, subreddit) DO UPDATE SET preference_score = preference_score + 0.2, times_liked = times_liked + 1, last_updated = CURRENT_TIMESTAMP",
        [user_id, subreddit]
      ) rescue nil
    end

    # Phase 3: Spaced repetition - allow re-showing memes after decay
    def should_exclude_from_exposure(user_id, meme_url)
      return false unless user_id
      
      exposure = DB.execute(
        "SELECT last_shown, shown_count FROM user_meme_exposure WHERE user_id = ? AND meme_url = ?",
        [user_id, meme_url]
      ).first
      
      return false unless exposure
      
      last_shown = DateTime.parse(exposure["last_shown"]) rescue nil
      return false unless last_shown
      
      shown_count = exposure["shown_count"].to_i
      
      # Exponential decay: base interval grows with each view
      # 1st view: exclude for 1 hour
      # 2nd view: exclude for 4 hours
      # 3rd view: exclude for 16 hours
      # 4th view: exclude for 64 hours (never shown again effectively)
      hours_to_wait = 4 ** (shown_count - 1)
      
      time_since_shown = (Time.now - last_shown) / 3600  # Convert to hours
      time_since_shown < hours_to_wait
    end

    # Phase 3: Get time-based pool distribution
    def get_time_based_pools(user_id = nil, limit = 100)
      hour = Time.now.hour
      
      # Peak hours: 9-11am, 6-9pm (80% trending, 15% fresh, 5% exploration)
      # Off-hours: 12am-6am (60% trending, 30% fresh, 10% exploration)
      # Normal hours: (70% trending, 20% fresh, 10% exploration)
      
      if (9..11).include?(hour) || (18..21).include?(hour)
        # Peak hours
        trending_ratio = 0.8
        fresh_ratio = 0.15
        exploration_ratio = 0.05
      elsif (0..6).include?(hour)
        # Off-hours
        trending_ratio = 0.6
        fresh_ratio = 0.3
        exploration_ratio = 0.1
      else
        # Normal hours
        trending_ratio = 0.7
        fresh_ratio = 0.2
        exploration_ratio = 0.1
      end
      
      trending = get_trending_pool((limit * trending_ratio).to_i)
      fresh = get_fresh_pool((limit * fresh_ratio).to_i, 48)
      exploration = get_exploration_pool((limit * exploration_ratio).to_i)
      
      pool = trending + fresh + exploration
      pool = pool.uniq { |m| m["url"] }
      
      # Apply user preferences if logged in
      if user_id
        apply_user_preferences(pool, user_id)
      else
        pool.shuffle
      end
    end

    # Phase 3: Personalized scoring for logged-in users
    def calculate_personalized_score(meme, user_id)
      return 0 unless meme || user_id
      
      base_score = Math.sqrt((meme["likes"].to_i * 2 + meme["views"].to_i).to_f)
      
      # Get user preferences
      user_pref = DB.execute(
        "SELECT preference_score FROM user_subreddit_preferences WHERE user_id = ? AND subreddit = ?",
        [user_id, meme["subreddit"]&.downcase]
      ).first
      
      preference_boost = user_pref ? (user_pref["preference_score"] - 1.0) * 0.5 : 0
      
      # Get exposure history for spaced repetition weighting
      exposure = DB.execute(
        "SELECT shown_count, liked FROM user_meme_exposure WHERE user_id = ? AND meme_url = ?",
        [user_id, meme["url"] || meme["file"]]
      ).first
      
      # Boost memes user liked, slightly penalize heavily shown memes
      exposure_penalty = exposure ? -((exposure["shown_count"].to_i - 1) * 0.1) : 0
      liked_boost = exposure && exposure["liked"] == 1 ? 0.5 : 0
      
      base_score + preference_boost + exposure_penalty + liked_boost
    end

    # Phase 3: Navigate with spaced repetition
    def navigate_meme_v3(direction: "next")
      user_id = session[:user_id] rescue nil
      
      # Get time-based intelligent pool
      if user_id
        memes = get_time_based_pools(user_id, 100)
      else
        memes = random_memes_pool
      end
      
      return nil if memes.empty?

      session[:meme_history] ||= []
      session[:last_subreddit] ||= nil
      last_meme_url = session[:meme_history].last

      # Get a random meme with spaced repetition filtering
      new_meme = nil
      attempts = 0
      max_attempts = [memes.size, 30].min
      
      while attempts < max_attempts
        candidate = memes.sample
        candidate_id = candidate["url"] || candidate["file"]
        candidate_subreddit = candidate["subreddit"]&.downcase
        
        # Phase 3: Check spaced repetition - exclude recently shown
        if should_exclude_from_exposure(user_id, candidate_id)
          attempts += 1
          next
        end
        
        # Ensure:
        # 1. Different URL than last shown
        # 2. Valid meme
        # 3. Different subreddit than last (subreddit diversity)
        if candidate_id && 
           candidate_id != last_meme_url && 
           is_valid_meme?(candidate) &&
           candidate_subreddit != session[:last_subreddit]
          new_meme = candidate
          break
        end
        attempts += 1
      end

      return nil unless new_meme

      # Ensure meme has proper URL property set for frontend
      meme_identifier = new_meme["url"] || new_meme["file"]
      new_meme["url"] = meme_identifier if !new_meme["url"]
      
      # Ensure permalink field exists
      new_meme["permalink"] ||= ""
      
      # Track history and subreddit diversity
      session[:meme_history] << meme_identifier
      session[:meme_history] = session[:meme_history].last(100)  # Increased from 30 for spaced repetition
      session[:last_subreddit] = new_meme["subreddit"]&.downcase

      # Track exposure for spaced repetition (Phase 3)
      if user_id
        DB.execute(
          "INSERT INTO user_meme_exposure (user_id, meme_url, shown_count) VALUES (?, ?, 1) ON CONFLICT(user_id, meme_url) DO UPDATE SET shown_count = shown_count + 1, last_shown = CURRENT_TIMESTAMP",
          [user_id, meme_identifier]
        ) rescue nil
      end

      new_meme
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

    # Get memes from cache or MEMES
    def get_cached_memes
      cached = REDIS&.get("memes:latest")
      memes = cached ? JSON.parse(cached) : MEME_CACHE[:memes] ||= MEMES

      memes.reject! do |m|
        file_missing = m["file"] && !File.exist?(File.join(settings.public_folder, m["file"]))
        url_invalid  = m["url"] && !m["url"].match?(/^https?:\/\//)
        file_missing || url_invalid
      end

      REDIS&.setex("memes:latest", 300, memes.to_json) rescue nil
      MEME_CACHE[:memes] = memes
    rescue
      MEME_CACHE[:memes] ||= MEMES
    end

    # Fetch memes from popular subreddits with working image links
    def fetch_reddit_memes(subreddits = POPULAR_SUBREDDITS, limit = 45)
      memes = []
      subreddits = subreddits.sample(25) if subreddits.size > 30

      # Multiple user agents to avoid blocking
      user_agents = [
        "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
        "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
        "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
        "Mozilla/5.0 (iPhone; CPU iPhone OS 14_7_1 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/14.1.2 Mobile/15E148 Safari/604.1",
        "curl/7.64.1"
      ]

      subreddits.each do |subreddit|
        attempts = 0
        max_attempts = 3
        
        while attempts < max_attempts
          begin
            url = "https://www.reddit.com/r/#{subreddit}/top.json?t=week&limit=#{limit}"
            uri = URI(url)
            
            Net::HTTP.start(uri.host, uri.port, use_ssl: true, read_timeout: 15, open_timeout: 15) do |http|
              request = Net::HTTP::Get.new(uri.request_uri)
              request["User-Agent"] = user_agents[attempts % user_agents.size]
              request["Accept"] = "application/json, text/javascript, */*; q=0.01"
              request["Accept-Language"] = "en-US,en;q=0.9"
              request["Accept-Encoding"] = "gzip, deflate"
              request["DNT"] = "1"
              request["Connection"] = "keep-alive"
              request["Upgrade-Insecure-Requests"] = "1"
              
              response = http.request(request)
              
              if response.code == "200"
                body = response.body
                data = JSON.parse(body)

                data["data"]["children"].each do |post|
                  post_data = post["data"]
                  next if post_data["is_video"] || post_data["is_self"] || !post_data["url"]

                  image_url = extract_image_url(post_data)
                  next unless image_url && image_url.match?(/^https?:\/\//)

                  meme = {
                    "title" => post_data["title"],
                    "url" => image_url,
                    "subreddit" => post_data["subreddit"],
                    "likes" => post_data["ups"] || 0,
                    "permalink" => post_data["permalink"]
                  }
                  memes << meme
                end
                break  # Success, exit retry loop
              else
                attempts += 1
                sleep 2 if attempts < max_attempts
              end
            end
          rescue JSON::ParserError => e
            attempts += 1
            sleep 2 if attempts < max_attempts
          rescue => e
            attempts += 1
            sleep 2 if attempts < max_attempts
          end
        end
        
        sleep 1.5  # Be respectful to Reddit between requests
      end

      memes
    end

    # Extract direct image URL from Reddit post data
    def extract_image_url(post_data)
      # Direct i.redd.it links (native Reddit images)
      if post_data["url"]&.match?(/^https:\/\/i\.redd\.it\//)
        return post_data["url"]
      end

      # imgur direct links (all formats)
      if post_data["url"]&.match?(/^https:\/\/(i\.)?imgur\.com\//)
        return post_data["url"]
      end

      # Other image hosts
      if post_data["url"]&.match?(/^https:\/\/(media\.|external-)?[a-z0-9\-]+\.(jpg|jpeg|png|gif|webp)/i)
        return post_data["url"]
      end

      # Check media metadata for preview image - handle reddit's internal preview
      if post_data["preview"]&.dig("images", 0, "source", "url")
        url = post_data["preview"]["images"][0]["source"]["url"]
        return url.gsub("&amp;", "&") if url
      end

      # Try gallery image first
      if post_data["gallery_data"]&.dig("items")&.first
        gallery_id = post_data["gallery_data"]["items"].first["media_id"]
        if post_data["media_metadata"]&.dig(gallery_id, "s", "x")
          return post_data["media_metadata"][gallery_id]["s"]["x"]
        end
      end

      nil
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

    # Phase 1: Get trending/fresh/exploration pools
    def get_trending_pool(limit = 50)
      result = DB.execute(
        "SELECT * FROM meme_stats WHERE failure_count IS NULL OR failure_count < 2 ORDER BY (likes * 2 + views) DESC LIMIT ?",
        [limit]
      ) rescue []
      result || []
    end

    def get_fresh_pool(limit = 30, hours_ago = 24)
      result = DB.execute(
        "SELECT * FROM meme_stats WHERE updated_at > datetime('now', '-#{hours_ago} hours') AND (failure_count IS NULL OR failure_count < 2) ORDER BY updated_at DESC LIMIT ?",
        [limit]
      ) rescue []
      result || []
    end

    def get_exploration_pool(limit = 20)
      result = DB.execute(
        "SELECT * FROM meme_stats WHERE failure_count IS NULL OR failure_count < 2 ORDER BY RANDOM() LIMIT ?",
        [limit]
      ) rescue []
      result || []
    end

    # Get meme pool from cache or build fresh - prioritizes API memes with local fallback
    def random_memes_pool
      # Use cached pool if fresh (less than 2 minutes old)
      if MEME_CACHE[:memes].is_a?(Array) && !MEME_CACHE[:memes].empty? &&
         MEME_CACHE[:last_refresh] && (Time.now - MEME_CACHE[:last_refresh]) < 120
        return MEME_CACHE[:memes]
      end

      # Always load local memes as guaranteed fallback
      local_memes = begin
        if MEMES.is_a?(Hash)
          MEMES.values.flatten.compact
        elsif MEMES.is_a?(Array)
          MEMES
        else
          []
        end
      rescue
        []
      end

      # Fetch fresh API memes first (primary source)
      api_memes = fetch_reddit_memes(POPULAR_SUBREDDITS, 50) rescue []
      
      # Combine: prefer API memes but always include local as fallback
      pool = api_memes + local_memes
      pool = pool.uniq { |m| m["url"] || m["file"] }

      # Validate memes - be lenient, accept if either file exists or URL is valid
      validated = pool.select do |m| 
        next true if m["file"] && File.exist?(File.join("public", m["file"]))
        next true if m["url"] && m["url"].match?(/^https?:\/\//)
        false
      end

      # If validation filtered everything, use local memes without strict validation as last resort
      if validated.empty? && !local_memes.empty?
        validated = local_memes
      end

      # Normalize file paths: remove leading / so File.join works correctly
      normalized = validated.map do |m|
        m_copy = m.dup
        if m_copy["file"] && m_copy["file"].start_with?("/")
          m_copy["file"] = m_copy["file"][1..-1]  # Remove leading slash
        end
        m_copy
      end

      MEME_CACHE[:memes] = normalized.shuffle
      MEME_CACHE[:last_refresh] = Time.now

      normalized
    end

    # Get likes safely
    def get_meme_likes(url)
      return 0 unless url
      likes = REDIS&.get("meme:likes:#{url}")&.to_i
      return likes if likes

      row = DB.execute("SELECT likes FROM meme_stats WHERE url = ?", url).first
      likes = row ? row["likes"].to_i : 0
      REDIS&.set("meme:likes:#{url}", likes)
      likes
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
          
          # Phase 2: Update user preference for this subreddit
          # (We'll get subreddit from DB query - need to store it in session during navigate_meme)
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
      REDIS&.set("meme:likes:#{url}", likes)
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
  end

  # -----------------------
  # OAuth Routes
  # -----------------------
  get "/auth/reddit" do
    client = OAuth2::Client.new(
      REDDIT_OAUTH_CLIENT_ID,
      REDDIT_OAUTH_CLIENT_SECRET,
      site: "https://www.reddit.com",
      authorize_url: "/api/v1/authorize",
      token_url: "/api/v1/access_token"
    )
    
    redirect client.auth_code.authorize_url(
      redirect_uri: REDDIT_REDIRECT_URI,
      response_type: "code",
      state: SecureRandom.hex(16),
      scope: "identity read",
      duration: "permanent"
    )
  end

  get "/auth/reddit/callback" do
    code = params[:code]
    halt 400, "No authorization code received" unless code

    client = OAuth2::Client.new(
      REDDIT_OAUTH_CLIENT_ID,
      REDDIT_OAUTH_CLIENT_SECRET,
      site: "https://www.reddit.com",
      authorize_url: "/api/v1/authorize",
      token_url: "/api/v1/access_token"
    )

    begin
      token = client.auth_code.get_token(
        code,
        redirect_uri: REDDIT_REDIRECT_URI,
        headers: {
          "User-Agent" => "MemeExplorer/1.0"
        }
      )

      # Get Reddit user info from /api/v1/me endpoint
      begin
        me_response = HTTParty.get(
          "https://oauth.reddit.com/api/v1/me",
          headers: {
            "Authorization" => "Bearer #{token.token}",
            "User-Agent" => "MemeExplorer/1.0"
          },
          timeout: 10
        )
        
        if me_response.success?
          user_data = me_response.parsed_response
          reddit_username = user_data["name"]
          reddit_id = user_data["id"]
          
          puts "OAuth Success: username=#{reddit_username}, id=#{reddit_id}"
        else
          puts "OAuth API Error: #{me_response.code} - #{me_response.body}"
          halt 400, "Failed to get Reddit user info: HTTP #{me_response.code}"
        end
        
        halt 400, "Failed to get Reddit username" unless reddit_username
      rescue Timeout::Error
        puts "OAuth Timeout: /api/v1/me took too long"
        halt 504, "Reddit API timeout"
      rescue => e
        puts "OAuth HTTP Error: #{e.class}: #{e.message}"
        halt 503, "Failed to contact Reddit API: #{e.message}"
      end

      # Store access token in Redis
      if REDIS
        REDIS.setex("reddit:access_token", 3600, token.token)
        REDIS.setex("reddit:token_expires_at", 3600, (Time.now + 3600).to_i.to_s)
      end

      # Create or find user
      begin
        user_id = create_or_find_user(reddit_username, reddit_id, nil)
        
        puts "OAuth: Setting session - user_id=#{user_id}, username=#{reddit_username}"
        
        # Set session
        session[:user_id] = user_id
        session[:reddit_username] = reddit_username
        session[:reddit_token] = token.token
        
        puts "OAuth: Session after set - user_id=#{session[:user_id]}, username=#{session[:reddit_username]}"

        redirect "/profile", 302
      rescue => e
        puts "OAuth User Creation Error: #{e.class}: #{e.message}"
        puts e.backtrace.join("\n")
        halt 500, "Failed to create/find user: #{e.message}"
      end
    rescue => e
      puts "OAuth Error: #{e.class}: #{e.message}"
      puts e.backtrace.join("\n")
      halt 400, "OAuth authentication failed: #{e.message}"
    end
  end

  # -----------------------
  # Routes
  # -----------------------
  get "/" do
    @meme = navigate_meme_v3(direction: "next")
    @image_src = meme_image_src(@meme)
    erb :random
  end

  # Render random meme page
  get "/random" do
    @meme = navigate_meme_v3(direction: "random")
    halt 404, "No memes found!" unless @meme
  
    @image_src = meme_image_src(@meme)
    @likes = get_meme_likes(@image_src)
  
    # Determine reddit_path for this specific image
    @reddit_path = nil
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

    erb :random
  end
  
  get "/random.json" do
    # Use random_memes_pool for ALL users (both auth and non-auth) to ensure API memes are always available
    # This fixes the OAuth issue where new users only saw local memes
    memes = random_memes_pool
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
    
    # Track in session history
    meme_identifier = @meme["url"] || @meme["file"]
    session[:meme_history] << meme_identifier
    session[:meme_history] = session[:meme_history].last(100)
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
    
    content_type :json
    {
      title: @meme["title"],
      subreddit: @meme["subreddit"],
      file: @meme["file"],
      url: image_url,
      reddit_path: reddit_path,
      likes: get_meme_likes(image_url)
    }.to_json
  end
  
  
  post "/like" do
    url = params[:url]
    halt 400, { error: "No URL provided" }.to_json unless url
  
    session[:liked_memes] ||= []
    session[:meme_like_counts] ||= {}
  
    # Toggle user's local like state
    liked_now = if session[:liked_memes].include?(url)
                  session[:liked_memes].delete(url)
                  false
                else
                  session[:liked_memes] << url
                  true
                end
  
    # Only count like once per session globally
    likes = toggle_like(url, liked_now, session)
  
    content_type :json
    { liked: liked_now, likes: likes }.to_json
  end

  post "/report-broken-image" do
    url = params[:url]
    halt 400, { error: "No URL provided" }.to_json unless url

    report_broken_image(url)
    
    content_type :json
    { reported: true, message: "Broken image tracked" }.to_json
  end
  
  get "/trending" do
    db_memes = DB.execute("SELECT url, title, subreddit, views, likes, (likes * 2 + views) AS score FROM meme_stats")

    local_memes = flatten_memes.map do |m|
      {
        "title" => m["title"],
        "file" => m["file"],
        "subreddit" => "local",
        "likes" => DB.get_first_value("SELECT likes FROM meme_stats WHERE url = ?", [m["file"] || m["url"]]) || 0,
        "views" => DB.get_first_value("SELECT views FROM meme_stats WHERE url = ?", [m["file"] || m["url"]]) || 0,
        "score" => (DB.get_first_value("SELECT likes FROM meme_stats WHERE url = ?", [m["file"] || m["url"]]) || 0) * 2 +
                   (DB.get_first_value("SELECT views FROM meme_stats WHERE url = ?", [m["file"] || m["url"]]) || 0)
      }
    end

    combined = (db_memes + local_memes).uniq { |m| m["url"] || m["file"] }
    @memes = combined.sort_by { |m| -(m["score"].to_i) }.first(20)
    erb :trending
  end
  before "/category/*" do
    # Define default categories if not loaded
    @categories = {
      funny: ["funny", "memes"],
      wholesome: ["wholesome", "aww"],
      dank: ["dank", "dankmemes"],
      selfcare: ["selfcare", "wellness"]
    }
  end
  
  get "/category/:name" do
    category_name = params[:name].to_sym
    subreddits = @categories[category_name]
    halt 404, { error: "Category not found" }.to_json unless subreddits && !subreddits.empty?
  
    # Filter valid memes
    local_memes = MEMES.is_a?(Hash) ? MEMES[category_name.to_s] || [] : []
    api_memes = (fetch_fresh_memes(batch_size: 50) rescue []).select { |m| subreddits.include?(m["subreddit"]) }
  
    @memes = (local_memes + api_memes).uniq { |m| m["url"] || m["file"] }
  
    # Use fallback only if empty
    @memes = [fallback_meme.merge("subreddit" => category_name.to_s)] if @memes.empty?
  
    if request.accept.include?("application/json")
      content_type :json
      @memes.to_json
    else
      @category_name = category_name
      erb :category, layout: :layout
    end
  end
  
  get "/category/:name/meme/:title" do
    category_name = params[:name].to_sym
    subreddits = @categories[category_name] || []
  
    local_memes = MEMES.is_a?(Hash) ? MEMES[category_name.to_s] || [] : []
    api_memes = (fetch_fresh_memes(batch_size: 50) rescue []).select { |m| subreddits.include?(m["subreddit"]) }
  
    combined = (local_memes + api_memes).uniq { |m| m["url"] || m["file"] }
  
    requested_title = URI.decode_www_form_component(params[:title])
    @meme = combined.find { |m| m["title"] == requested_title }
  
    # Fallback
    @meme ||= fallback_meme.merge("subreddit" => category_name.to_s)
    @image_src = meme_image_src(@meme)
  
    erb :random, layout: :layout
  end
  
  

  # Smart Hybrid Search: Cache → API (if needed) → DB/YAML Fallback
  def search_memes(query)
    return [] unless query
    query_lower = query.downcase.strip
    return [] if query_lower.empty?
    
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
    if cache_results.empty?
      db_results = (DB.execute("SELECT * FROM meme_stats WHERE title LIKE ? COLLATE NOCASE", ["%#{query_lower}%"]) rescue []).map { |r| r.transform_keys(&:to_s) }
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

  get "/search" do
    query = params[:q]
    
    if request.accept.include?("application/json")
      # JSON API endpoint
      results = search_memes(query)
      content_type :json
      {
        query: query,
        results: results.map { |m| {
          title: m["title"],
          url: m["url"] || m["file"],
          file: m["file"],
          subreddit: m["subreddit"],
          likes: m["likes"].to_i,
          views: m["views"].to_i,
          source: m["file"] ? "local" : "reddit"
        }},
        total: results.size
      }.to_json
    else
      # HTML view
      @results = search_memes(query)
      @query = query
      erb :search
    end
  end
  
  get "/api/search.json" do
    query = params[:q]
    results = search_memes(query)
    
    content_type :json
    {
      query: query,
      results: results.map { |m| {
        title: m["title"],
        url: m["url"] || m["file"],
        file: m["file"],
        subreddit: m["subreddit"],
        likes: m["likes"].to_i,
        views: m["views"].to_i,
        source: m["file"] ? "local" : "reddit",
        engagement_score: (m["likes"].to_i * 2 + m["views"].to_i)
      }},
      total: results.size
    }.to_json
  end

  get "/metrics.json" do
    total_memes = DB.get_first_value("SELECT COUNT(*) FROM meme_stats") || 0
    total_likes = DB.get_first_value("SELECT SUM(likes) FROM meme_stats") || 0
    total_views = DB.get_first_value("SELECT COALESCE(SUM(views), 0) FROM meme_stats") || 0

    avg_likes = total_memes > 0 ? (total_likes.to_f / total_memes).round(2) : 0
    avg_views = total_memes > 0 ? (total_views.to_f / total_memes).round(2) : 0

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
  get "/login" do
    erb :login
  end

  post '/login' do
    user = User.find_by(email: params[:email])
    if user && user.authenticate(params[:password])
      session[:user_id] = user.id
      redirect '/profile'
    else
      redirect '/login'
    end
  end

  get "/signup" do
    erb :signup
  end

  post "/signup" do
    email = params[:email]
    password = params[:password]
    password_confirm = params[:password_confirm]

    halt 400, "Passwords do not match" if password != password_confirm
    halt 400, "Email and password required" if email.to_s.strip.empty? || password.to_s.strip.empty?

    user_id = create_email_user(email, password)
    halt 400, "Email already in use" unless user_id

    session[:user_id] = user_id
    session[:email] = email
    redirect "/profile"
  end

  get "/logout" do
    session.clear
    redirect "/"
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

  get "/saved/:id" do
    saved_id = params[:id].to_i
    saved_meme = DB.execute("SELECT * FROM saved_memes WHERE id = ?", [saved_id]).first

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
  # Monitoring Routes
  # -----------------------
  get "/health" do
    content_type :json
    {
      status: "ok",
      timestamp: Time.now.iso8601,
      uptime_seconds: (Time.now - $start_time).to_i,
      requests: METRICS[:total_requests],
      avg_response_time_ms: METRICS[:avg_request_time_ms].round(2),
      error_rate_5m: ErrorHandler::Logger.error_rate(300)
    }.to_json
  end

  get "/errors" do
    halt 403, "Forbidden" unless is_admin?
    content_type :json
    {
      recent_errors: ErrorHandler::Logger.recent(50),
      error_rate_5m: ErrorHandler::Logger.error_rate(300),
      critical_errors_5m: ErrorHandler::Logger.critical_errors(300)
    }.to_json
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
  # Start server
  # -----------------------
  run! if app_file == $0
end

# Track server start time for /health endpoint
$start_time = Time.now
