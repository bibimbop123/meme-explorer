# frozen_string_literal: true

# Application Configuration Constants
# Centralized configuration for all magic numbers and tunable parameters
module AppConstants
  # ==========================================
  # SESSION CONFIGURATION
  # ==========================================
  SESSION_HISTORY_MAX = ENV.fetch('SESSION_HISTORY_MAX', 10).to_i
  SESSION_SIZE_WARNING_BYTES = ENV.fetch('SESSION_SIZE_WARNING', 2048).to_i
  
  # ==========================================
  # MEME SELECTION & ALGORITHM
  # ==========================================
  MEME_SELECTION_MAX_ATTEMPTS = ENV.fetch('MEME_MAX_ATTEMPTS', 30).to_i
  SURPRISE_REWARD_PROBABILITY = ENV.fetch('SURPRISE_PROBABILITY', 0.10).to_f
  SPACED_REPETITION_BASE = ENV.fetch('SPACED_REPETITION_BASE', 4).to_i
  QUALITY_SCORE_THRESHOLD = ENV.fetch('QUALITY_THRESHOLD', 0.7).to_f
  
  # ==========================================
  # CACHE TTL (Time-To-Live) SETTINGS
  # ==========================================
  CACHE_TTL_SHORT = ENV.fetch('CACHE_TTL_SHORT', 300).to_i      # 5 minutes
  CACHE_TTL_MEDIUM = ENV.fetch('CACHE_TTL_MEDIUM', 1800).to_i   # 30 minutes
  CACHE_TTL_LONG = ENV.fetch('CACHE_TTL_LONG', 3600).to_i       # 1 hour
  CACHE_TTL_VERY_LONG = ENV.fetch('CACHE_TTL_VERY_LONG', 86400).to_i  # 24 hours
  
  # ==========================================
  # DATABASE CONNECTION POOL
  # ==========================================
  DB_POOL_SIZE = ENV.fetch('DATABASE_POOL_SIZE', 35).to_i
  DB_POOL_TIMEOUT = ENV.fetch('DATABASE_POOL_TIMEOUT', 5).to_i
  
  # ==========================================
  # QUERY TIMEOUTS
  # ==========================================
  QUERY_TIMEOUT_FAST = ENV.fetch('QUERY_TIMEOUT_FAST', 1).to_i
  QUERY_TIMEOUT_NORMAL = ENV.fetch('QUERY_TIMEOUT_NORMAL', 5).to_i
  QUERY_TIMEOUT_SLOW = ENV.fetch('QUERY_TIMEOUT_SLOW', 15).to_i
  QUERY_TIMEOUT_BULK = ENV.fetch('QUERY_TIMEOUT_BULK', 30).to_i
  
  # ==========================================
  # RATE LIMITING
  # ==========================================
  RATE_LIMIT_API_WRITES = ENV.fetch('RATE_LIMIT_API_WRITES', 30).to_i
  RATE_LIMIT_EXPENSIVE_OPS = ENV.fetch('RATE_LIMIT_EXPENSIVE', 5).to_i
  RATE_LIMIT_PERIOD = ENV.fetch('RATE_LIMIT_PERIOD', 60).to_i
  
  # ==========================================
  # PAGINATION
  # ==========================================
  PAGINATION_DEFAULT_PAGE_SIZE = ENV.fetch('PAGE_SIZE_DEFAULT', 20).to_i
  PAGINATION_MAX_PAGE_SIZE = ENV.fetch('PAGE_SIZE_MAX', 100).to_i
  
  # ==========================================
  # WORKER & BACKGROUND JOBS
  # ==========================================
  CACHE_REFRESH_LOCK_TTL = ENV.fetch('CACHE_REFRESH_LOCK_TTL', 300).to_i
  WORKER_MAX_RETRIES = ENV.fetch('WORKER_MAX_RETRIES', 3).to_i
  WORKER_RETRY_DELAY = ENV.fetch('WORKER_RETRY_DELAY', 60).to_i
  
  # ==========================================
  # LEADERBOARD & GAMIFICATION
  # ==========================================
  LEADERBOARD_TOP_USERS_COUNT = ENV.fetch('LEADERBOARD_TOP_COUNT', 100).to_i
  LEADERBOARD_CACHE_TTL = ENV.fetch('LEADERBOARD_CACHE_TTL', 600).to_i
  STREAK_REMINDER_THRESHOLD_HOURS = ENV.fetch('STREAK_REMINDER_HOURS', 20).to_i
  
  # ==========================================
  # MEDIA & CONTENT
  # ==========================================
  IMAGE_PLACEHOLDER_THRESHOLD = ENV.fetch('IMAGE_PLACEHOLDER_THRESHOLD', 3).to_i
  MEDIA_FETCH_TIMEOUT = ENV.fetch('MEDIA_FETCH_TIMEOUT', 10).to_i
  MAX_IMAGE_SIZE_MB = ENV.fetch('MAX_IMAGE_SIZE_MB', 10).to_i
  
  # ==========================================
  # SEARCH & FILTERING
  # ==========================================
  SEARCH_MIN_QUERY_LENGTH = ENV.fetch('SEARCH_MIN_LENGTH', 2).to_i
  SEARCH_MAX_RESULTS = ENV.fetch('SEARCH_MAX_RESULTS', 100).to_i
  SEARCH_CACHE_TTL = ENV.fetch('SEARCH_CACHE_TTL', 300).to_i
  
  # ==========================================
  # MONITORING & ALERTS
  # ==========================================
  SLOW_REQUEST_THRESHOLD_MS = ENV.fetch('SLOW_REQUEST_MS', 1000).to_i
  MEMORY_WARNING_THRESHOLD_MB = ENV.fetch('MEMORY_WARNING_MB', 512).to_i
  ERROR_RATE_ALERT_THRESHOLD = ENV.fetch('ERROR_RATE_THRESHOLD', 0.05).to_f
  
  # ==========================================
  # FEATURE FLAGS (can be toggled via ENV)
  # ==========================================
  ENABLE_STRUCTURED_LOGGING = ENV.fetch('ENABLE_STRUCTURED_LOGGING', 'true') == 'true'
  ENABLE_QUERY_TIMEOUTS = ENV.fetch('ENABLE_QUERY_TIMEOUTS', 'true') == 'true'
  ENABLE_DISTRIBUTED_LOCKS = ENV.fetch('ENABLE_DISTRIBUTED_LOCKS', 'true') == 'true'
  ENABLE_SESSION_MONITORING = ENV.fetch('ENABLE_SESSION_MONITORING', 'true') == 'true'

  # ==========================================
  # MERGED FROM MemeExplorerConstants (config/constants.rb)
  # ==========================================
  CACHE_REFRESH_INTERVAL_SECONDS    = ENV.fetch('CACHE_REFRESH_INTERVAL', 30).to_i
  CACHE_STARTUP_DELAY_SECONDS       = ENV.fetch('CACHE_STARTUP_DELAY', 2).to_i
  CACHE_STALENESS_THRESHOLD_SECONDS = ENV.fetch('CACHE_STALENESS_THRESHOLD', 60).to_i
  REDDIT_API_FETCH_LIMIT            = ENV.fetch('REDDIT_API_FETCH_LIMIT', 45).to_i
  REDDIT_API_SUBREDDIT_SAMPLE_SIZE  = ENV.fetch('REDDIT_API_SUBREDDIT_SAMPLE_SIZE', 8).to_i
  REDDIT_API_MAX_SUBREDDITS         = ENV.fetch('REDDIT_API_MAX_SUBREDDITS', 40).to_i
  REDDIT_API_REQUEST_DELAY_SECONDS  = ENV.fetch('REDDIT_API_REQUEST_DELAY', 1.5).to_f
  REDDIT_API_RETRY_DELAY_SECONDS    = ENV.fetch('REDDIT_API_RETRY_DELAY', 2).to_f
  REDDIT_API_MAX_RETRIES            = ENV.fetch('REDDIT_API_MAX_RETRIES', 3).to_i
  REDDIT_API_TIMEOUT_SECONDS        = ENV.fetch('REDDIT_API_TIMEOUT', 15).to_i
  MEME_HISTORY_SIZE                 = ENV.fetch('MEME_HISTORY_SIZE', 10).to_i
  TRENDING_POOL_RATIO               = 0.7
  FRESH_POOL_RATIO                  = 0.2
  EXPLORATION_POOL_RATIO            = 0.1
  STALE_MEME_DAYS                   = ENV.fetch('STALE_MEME_DAYS', 7).to_i
  FRESH_CONTENT_HOURS               = ENV.fetch('FRESH_CONTENT_HOURS', 48).to_i
  DEFAULT_PAGINATION_LIMIT          = ENV.fetch('DEFAULT_PAGINATION_LIMIT', 10).to_i
  MAX_PAGINATION_LIMIT              = ENV.fetch('MAX_PAGINATION_LIMIT', 100).to_i
  MAX_CACHE_ENTRIES                 = ENV.fetch('MAX_CACHE_ENTRIES', 1000).to_i
  FALLBACK_POOL_SIZE                = ENV.fetch('FALLBACK_POOL_SIZE', 100).to_i
  SESSION_COOKIE_MAX_AGE_SECONDS    = ENV.fetch('SESSION_COOKIE_MAX_AGE', 2_592_000).to_i # 30 days

  # ==========================================
  # MERGED FROM MemeExplorerConfig (config/application.rb)
  # ==========================================
  SESSION_EXPIRE_AFTER  = SESSION_COOKIE_MAX_AGE_SECONDS
  MEME_CACHE_MAX_SIZE   = 500 * 1024 * 1024  # 500 MB hard limit
  MEME_CACHE_TTL        = CACHE_TTL_VERY_LONG
  CACHE_REFRESH_INTERVAL = CACHE_REFRESH_INTERVAL_SECONDS
  CACHE_INITIAL_DELAY   = CACHE_STARTUP_DELAY_SECONDS
  RATE_LIMIT_REQUESTS   = ENV.fetch('RATE_LIMIT_REQUESTS', 60).to_i

  # Tier weighting (kept here for single source of truth)
  TIER_WEIGHTS = {
    tier_1: 35, tier_2: 18, tier_3: 15, tier_4: 10, tier_5: 8,
    tier_6: 5,  tier_7: 3,  tier_8: 2,  tier_9: 2,  tier_10: 2
  }.freeze
  TOTAL_TIER_WEIGHT = TIER_WEIGHTS.values.sum

  COOKIE_OPTIONS = {
    path:      '/',
    secure:    ENV['RACK_ENV'] == 'production',
    httponly:  true,
    same_site: :lax,
    expires:   Time.now + SESSION_EXPIRE_AFTER
  }.freeze

  # Health sub-module (used by lib/concerns/cache_strategy.rb)
  module Health
    MIN_MEME_POOL_SIZE           = ENV.fetch('MIN_MEME_POOL_SIZE', 10).to_i
    CACHE_STALE_THRESHOLD_MINUTES = ENV.fetch('CACHE_STALE_THRESHOLD_MINUTES', 30).to_i
  end

  def self.validate!
    unless TOTAL_TIER_WEIGHT == 100
      raise ConfigurationError, "TIER_WEIGHTS must sum to 100 (got #{TOTAL_TIER_WEIGHT})"
    end
  end
end

# ---------------------------------------------------------------------------
# Backward-compat aliases — remove after all callsites migrated to AppConstants
# ---------------------------------------------------------------------------
MemeExplorerConstants = AppConstants unless defined?(MemeExplorerConstants)
