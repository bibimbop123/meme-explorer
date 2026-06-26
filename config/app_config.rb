# Application Configuration Constants
# P1 Fix: Replace magic numbers with documented constants

module AppConfig
  # Session Management
  SESSION_HISTORY_MAX = 20  # Maximum memes to track in session history
  SESSION_LIKE_COUNTS_MAX = 50  # Maximum like counts to cache in session
  SESSION_TTL_HOURS = 24  # Session data TTL in Redis
  
  # Meme Selection Algorithm
  RANDOM_SELECTION_MAX_ATTEMPTS = 30  # Maximum attempts to find unseen meme
  SURPRISE_REWARD_PROBABILITY = 0.10  # 10% chance of surprise reward
  SPACED_REPETITION_BASE = 4  # Exponential base for spacing (4^n hours)
  DIVERSITY_SUBREDDIT_THRESHOLD = 0.3  # 30% of recent memes from same subreddit triggers diversity
  
  # Caching Strategy
  MEME_POOL_SIZE = 500  # Size of active meme pool
  MEME_POOL_REFRESH_INTERVAL = 300  # Refresh pool every 5 minutes
  CACHE_TTL_SHORT = 60  # 1 minute
  CACHE_TTL_MEDIUM = 300  # 5 minutes
  CACHE_TTL_LONG = 3600  # 1 hour
  CACHE_TTL_DAY = 86400  # 24 hours
  
  # Rate Limiting
  RATE_LIMIT_REQUESTS_PER_MINUTE = 60
  RATE_LIMIT_EXPENSIVE_OPS_PER_HOUR = 10  # Admin cache refresh, etc.
  RATE_LIMIT_API_REQUESTS_PER_DAY = 1000
  
  # Database Connection Pool
  DB_POOL_SIZE = 35  # Matches Puma thread count + buffer
  DB_POOL_TIMEOUT = 5  # Seconds to wait for connection
  
  # Background Job Settings
  ANALYTICS_POOL_SIZE = 10  # Concurrent analytics threads
  RETRY_MAX_ATTEMPTS = 3
  RETRY_BACKOFF_BASE = 2  # Exponential backoff: 2^n seconds
  
  # Content Quality Thresholds
  QUALITY_SCORE_MIN = 0.5  # Minimum quality score to show meme
  VIRAL_LIKES_THRESHOLD = 1000  # Likes needed to mark as "viral"
  TRENDING_SCORE_DECAY_HOURS = 24  # Time decay for trending algorithm
  
  # Gamification
  XP_PER_LIKE_GIVEN = 1
  XP_PER_MEME_SAVED = 2
  XP_PER_STREAK_DAY = 5
  LEVEL_XP_BASE = 100  # Base XP for level 1
  LEVEL_XP_MULTIPLIER = 1.5  # XP requirement multiplier per level
  
  # Redis Circuit Breaker
  REDIS_BACKOFF_MAX_SECONDS = 60
  REDIS_FAILURE_THRESHOLD = 3  # Failures before circuit opens
  
  # Search
  SEARCH_RESULTS_MAX = 100
  SEARCH_QUERY_MAX_LENGTH = 200
  SEARCH_MIN_LENGTH = 2
  
  # Admin Operations
  ADMIN_CACHE_REBUILD_COOLDOWN_SECONDS = 60  # Minimum time between cache rebuilds
  ADMIN_BULK_OPERATION_MAX = 1000  # Maximum items per bulk operation
end
