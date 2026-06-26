# frozen_string_literal: true
# Tuning Parameters - All Magic Numbers Extracted
# This file contains all configurable constants used throughout the application
# Part of Phase 1 Code Quality Improvements

module TuningParameters
  # === Meme History & Selection ===
  MEME_HISTORY_MAX = 10
  MEME_POOL_SIZE = 100
  MEME_POOL_MIN_SIZE = 20
  MAX_RETRY_ATTEMPTS = 3
  
  # === Surprise & Randomness ===
  SURPRISE_PROBABILITY = 0.10
  SURPRISE_REWARD_MIN = 5
  SURPRISE_REWARD_MAX = 50
  NEAR_MISS_PROBABILITY = 0.15
  
  # === Quality Thresholds ===
  QUALITY_THRESHOLD = 0.75
  MINIMUM_QUALITY_SCORE = 0.5
  HIGH_QUALITY_THRESHOLD = 0.85
  VIRAL_THRESHOLD = 0.90
  
  # === Cache TTL (seconds) ===
  CACHE_TTL_SHORT = 300       # 5 minutes
  CACHE_TTL_MEDIUM = 1800     # 30 minutes
  CACHE_TTL_LONG = 3600       # 1 hour
  CACHE_TTL_EXTENDED = 86400  # 24 hours
  
  # === Rate Limiting ===
  RATE_LIMIT_ANONYMOUS = 100  # requests per minute
  RATE_LIMIT_AUTHENTICATED = 300
  RATE_LIMIT_ADMIN = 1000
  RATE_LIMIT_SEARCH = 20      # expensive operation
  RATE_LIMIT_CACHE_REFRESH = 5  # per hour
  
  # === Reddit API ===
  REDDIT_API_DELAY = 2        # seconds between requests
  REDDIT_MAX_RETRIES = 3
  REDDIT_BATCH_SIZE = 100
  REDDIT_TIMEOUT = 10         # seconds
  
  # === Database ===
  DB_CONNECTION_POOL_SIZE = 5
  DB_QUERY_TIMEOUT = 5        # seconds
  DB_SLOW_QUERY_THRESHOLD = 1 # second
  
  # === Gamification ===
  STREAK_BONUS_MULTIPLIER = 1.5
  LEADERBOARD_TOP_N = 100
  POINTS_PER_LIKE = 10
  POINTS_PER_SHARE = 25
  POINTS_PER_COLLECTION = 50
  
  # === Pagination ===
  DEFAULT_PAGE_SIZE = 24
  MAX_PAGE_SIZE = 100
  
  # === Image Processing ===
  IMAGE_TIMEOUT = 5           # seconds
  IMAGE_MAX_SIZE_MB = 10
  
  # === Session & Cleanup ===
  SESSION_LIFETIME = 604800   # 7 days in seconds
  CLEANUP_BATCH_SIZE = 1000
  
  # === Performance ===
  RESPONSE_TIME_TARGET_MS = 150
  SLOW_REQUEST_THRESHOLD_MS = 300
  
  # === A/B Testing ===
  AB_TEST_SAMPLE_SIZE = 1000
  AB_TEST_CONFIDENCE_LEVEL = 0.95
  
  # === Monitoring ===
  HEALTH_CHECK_INTERVAL = 60  # seconds
  METRICS_AGGREGATION_INTERVAL = 300  # 5 minutes
  
  # === Feature Flags ===
  ENABLE_EXPERIMENTAL_FEATURES = ENV['RACK_ENV'] != 'production'
  ENABLE_VERBOSE_LOGGING = ENV['RACK_ENV'] == 'development'
  ENABLE_PERFORMANCE_PROFILING = ENV['ENABLE_PROFILING'] == 'true'
  
  # === Content Limits ===
  MAX_SAVED_MEMES = 1000
  MAX_COLLECTIONS = 50
  MAX_COLLECTION_SIZE = 500
  
  # Helper method to get parameter with fallback
  def self.get(param, default = nil)
    const_get(param) rescue default
  end
  
  # Get all parameters as hash (useful for debugging)
  def self.to_h
    constants.select { |c| const_get(c).is_a?(Numeric) || const_get(c).is_a?(String) }
             .map { |c| [c, const_get(c)] }
             .to_h
  end
end
