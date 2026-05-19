# Application Constants
# Centralized constants for better maintainability
# Generated: May 19, 2026

module AppConstants
  # Cache Configuration
  module Cache
    MINIMUM_POOL_SIZE = 3
    MAXIMUM_POOL_SIZE = 1000
    DEFAULT_TTL = 3600 # 1 hour
    MEME_POOL_TTL = 1800 # 30 minutes
    MAX_CACHE_SIZE_MB = 500
  end
  
  # API Configuration
  module API
    THROTTLE_DELAY = 1.5 # seconds
    REQUEST_TIMEOUT = 15 # seconds
    MAX_RETRY_ATTEMPTS = 3
    DEFAULT_LIMIT = 50
    MAX_SUBREDDITS_PER_REQUEST = 40
  end
  
  # Pagination
  module Pagination
    DEFAULT_PAGE = 1
    DEFAULT_LIMIT = 20
    MAX_LIMIT = 100
  end
  
  # User Limits
  module UserLimits
    MAX_SAVED_MEMES = 1000
    MAX_SEARCH_HISTORY = 50
    SESSION_DURATION = 2_592_000 # 30 days
  end
  
  # Gamification
  module Gamification
    XP_PER_LIKE = 10
    XP_PER_SAVE = 5
    XP_PER_VIEW = 1
    LEVEL_UP_THRESHOLD = 100
    STREAK_BONUS_MULTIPLIER = 1.5
  end
  
  # Validation
  module Validation
    MAX_SEARCH_LENGTH = 100
    MAX_URL_LENGTH = 2000
    MAX_USERNAME_LENGTH = 50
    MAX_TITLE_LENGTH = 300
    MIN_PASSWORD_LENGTH = 8
    SESSION_SECRET_MIN_LENGTH = 64
  end
  
  # Rate Limiting
  module RateLimit
    REQUESTS_PER_MINUTE = 60
    LIKES_PER_MINUTE = 10
    SEARCHES_PER_MINUTE = 30
    SIGNUPS_PER_HOUR = 5
  end
  
  # Image Processing
  module Images
    MAX_FILE_SIZE_MB = 10
    ALLOWED_EXTENSIONS = %w[.jpg .jpeg .png .gif .webp].freeze
    THUMBNAIL_SIZE = 300
    PREVIEW_SIZE = 600
  end
  
  # Meme Pool Configuration
  module MemePool
    TRENDING_RATIO = 0.7 # 70%
    FRESH_RATIO = 0.2    # 20%
    EXPLORATION_RATIO = 0.1 # 10%
    FRESH_HOURS_THRESHOLD = 48
    MIN_ENGAGEMENT_SCORE = 5
  end
  
  # Reddit API
  module Reddit
    TOP_TIER_SUBS = %w[
      memes dankmemes me_irl meirl 2meirl4meirl
      comedyheaven holup okbuddyretard adviceanimals
    ].freeze
    
    MID_TIER_SUBS = %w[
      funny wholesomememes mademesmile murderedbywords
      rareinsults facepalm instant_regret
    ].freeze
    
    USER_AGENTS = [
      "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36",
      "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36",
      "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36"
    ].freeze
  end
  
  # Health Check
  module Health
    CACHE_STALE_THRESHOLD_MINUTES = 60
    DATABASE_TIMEOUT_SECONDS = 5
    REDIS_TIMEOUT_SECONDS = 2
    MIN_MEME_POOL_SIZE = 10
  end
  
  # HTTP Status Codes (for reference)
  module HTTP
    OK = 200
    CREATED = 201
    BAD_REQUEST = 400
    UNAUTHORIZED = 401
    FORBIDDEN = 403
    NOT_FOUND = 404
    UNPROCESSABLE = 422
    TOO_MANY_REQUESTS = 429
    INTERNAL_ERROR = 500
    SERVICE_UNAVAILABLE = 503
  end
end
