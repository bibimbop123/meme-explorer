# Application Constants
# Extracted from magic numbers throughout codebase
# Created: May 11, 2026 (Senior Engineer Audit)

module AppConstants
  # Cache Configuration
  CACHE_SUBREDDIT_SAMPLE_SIZE = 50
  CACHE_REFRESH_INTERVAL_SECONDS = 600  # 10 minutes
  CACHE_STARTUP_DELAY_SECONDS = 5
  
  # Reddit API Configuration
  REDDIT_API_DELAY_SECONDS = 1
  REDDIT_API_REQUEST_LIMIT = 60  # per minute
  REDDIT_SUBREDDIT_FETCH_LIMIT = 8
  REDDIT_POSTS_PER_SUBREDDIT = 30
  REDDIT_MAX_SUBREDDIT_SAMPLE = 25
  
  # Meme Pool Configuration
  TRENDING_POOL_PERCENTAGE = 0.7   # 70%
  FRESH_POOL_PERCENTAGE = 0.2      # 20%
  EXPLORATION_POOL_PERCENTAGE = 0.1 # 10%
  
  # Peak Hours Pool Distribution
  PEAK_HOURS_TRENDING = 0.8
  PEAK_HOURS_FRESH = 0.15
  PEAK_HOURS_EXPLORATION = 0.05
  
  # Off Hours Pool Distribution
  OFF_HOURS_TRENDING = 0.6
  OFF_HOURS_FRESH = 0.3
  OFF_HOURS_EXPLORATION = 0.1
  
  # User Preferences
  PREFERRED_MEMES_RATIO = 0.6      # 60% preferred
  NEUTRAL_MEMES_RATIO = 0.4        # 40% neutral
  
  # Session and History
  MEME_HISTORY_LIMIT = 100
  MEME_HISTORY_SHORT_LIMIT = 30
  MAX_MEME_SELECTION_ATTEMPTS = 30
  
  # New User Threshold
  NEW_USER_EXPOSURE_THRESHOLD = 10
  
  # Spaced Repetition
  SPACED_REPETITION_BASE = 4  # hours_to_wait = 4^(shown_count - 1)
  SPACED_REPETITION_FORGIVING_BASE = 2  # More forgiving alternative
  
  # Database Cleanup
  DB_CLEANUP_INTERVAL_SECONDS = 3600  # 1 hour
  BROKEN_IMAGE_FAILURE_THRESHOLD = 5
  BROKEN_IMAGE_RETENTION_DAYS = 1
  UNUSED_MEME_RETENTION_DAYS = 7
  
  # Leaderboard
  LEADERBOARD_DEFAULT_LIMIT = 25
  LEADERBOARD_NEARBY_RANGE = 5
  LEADERBOARD_TOP_RANK_THRESHOLD = 10
  
  # XP and Gamification
  XP_VIEW_MEME = 5
  XP_LIKE_MEME = 10
  XP_SAVE_MEME = 15
  XP_SHARE_MEME = 20
  XP_DAILY_STREAK = 25
  XP_FIRST_LOGIN = 30
  
  # Trending and Scoring
  TRENDING_MEME_COUNT = 20
  TRENDING_LIKE_WEIGHT = 2
  TRENDING_VIEW_WEIGHT = 1
  
  # Image Validation
  IMAGE_VALIDATION_TIMEOUT = 5
  BROKEN_IMAGE_REPORT_THRESHOLD = 2
  
  # API Caching
  API_CACHE_DURATION_SECONDS = 300  # 5 minutes
  CDN_CACHE_DURATION_SECONDS = 3600 # 1 hour
  
  # Retry Configuration
  REDDIT_FETCH_MAX_RETRIES = 3
  REDDIT_FETCH_RETRY_DELAY = 2
  
  # Fresh Pool Configuration
  FRESH_POOL_HOURS = 48
  FRESH_POOL_DEFAULT_LIMIT = 30
  
  # Exploration Pool
  EXPLORATION_POOL_DEFAULT_LIMIT = 20
  
  # Peak Hours (for time-based distribution)
  PEAK_HOURS_MORNING = (9..11)
  PEAK_HOURS_EVENING = (18..21)
  OFF_HOURS = (0..6)
end
