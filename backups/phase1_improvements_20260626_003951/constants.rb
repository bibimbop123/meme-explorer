# frozen_string_literal: true

# Application-wide constants for Meme Explorer
# Centralizes magic numbers and configuration values for better maintainability

module MemeExplorerConstants
  # Cache Configuration
  CACHE_REFRESH_INTERVAL_SECONDS = 30
  CACHE_STARTUP_DELAY_SECONDS = 2
  CACHE_STALENESS_THRESHOLD_SECONDS = 60
  CACHE_TTL_SECONDS = 300  # 5 minutes
  
  # Reddit API Configuration
  REDDIT_API_FETCH_LIMIT = 45
  REDDIT_API_SUBREDDIT_SAMPLE_SIZE = 8
  REDDIT_API_MAX_SUBREDDITS = 40
  REDDIT_API_REQUEST_DELAY_SECONDS = 1.5
  REDDIT_API_RETRY_DELAY_SECONDS = 2
  REDDIT_API_MAX_RETRIES = 3
  REDDIT_API_TIMEOUT_SECONDS = 15
  
  # Meme Selection Configuration
  MAX_MEME_SELECTION_ATTEMPTS = 30
  MEME_HISTORY_SIZE = 100
  MEME_HISTORY_SHORT_SIZE = 30
  
  # Intelligent Pool Ratios
  TRENDING_POOL_RATIO = 0.7  # 70%
  FRESH_POOL_RATIO = 0.2     # 20%
  EXPLORATION_POOL_RATIO = 0.1  # 10%
  
  # Time-based Pool Configurations (by hour of day)
  PEAK_HOURS = (9..11).to_a + (18..21).to_a
  OFF_HOURS = (0..6).to_a
  
  # Peak hours ratios
  PEAK_TRENDING_RATIO = 0.8
  PEAK_FRESH_RATIO = 0.15
  PEAK_EXPLORATION_RATIO = 0.05
  
  # Off-hours ratios
  OFF_TRENDING_RATIO = 0.6
  OFF_FRESH_RATIO = 0.3
  OFF_EXPLORATION_RATIO = 0.1
  
  # Normal hours ratios (default)
  NORMAL_TRENDING_RATIO = 0.7
  NORMAL_FRESH_RATIO = 0.2
  NORMAL_EXPLORATION_RATIO = 0.1
  
  # Personalization Configuration
  PREFERRED_MEMES_RATIO = 0.6  # 60% from preferred subreddits
  NEUTRAL_MEMES_RATIO = 0.4    # 40% from neutral
  NEW_USER_EXPOSURE_THRESHOLD = 10
  PREFERENCE_SCORE_INCREMENT = 0.2
  PREFERENCE_SCORE_THRESHOLD = 1.0
  
  # Database Configuration
  DB_CLEANUP_INTERVAL_SECONDS = 3600  # 1 hour
  DB_CLEANUP_DELAY_SECONDS = 3600     # Wait 1 hour before first cleanup
  BROKEN_IMAGE_FAILURE_THRESHOLD = 2
  BROKEN_IMAGE_FAILURE_LIMIT = 5
  STALE_MEME_DAYS = 7
  FRESH_CONTENT_HOURS = 48
  
  # Spaced Repetition Configuration
  SPACED_REPETITION_BASE = 4  # 4^(shown_count - 1) hours
  
  # Pagination Defaults
  DEFAULT_PAGINATION_LIMIT = 10
  MAX_PAGINATION_LIMIT = 100
  
  # Content Display
  TOP_MEMES_LIMIT = 20
  TOP_SUBREDDITS_LIMIT = 10
  ADMIN_TOP_MEMES_LIMIT = 10
  
  # Metrics
  DEFAULT_ERROR_RATE_WINDOW_SECONDS = 300  # 5 minutes
  
  # Session Configuration
  SESSION_COOKIE_MAX_AGE_DAYS = 30
  SESSION_COOKIE_MAX_AGE_SECONDS = 30 * 24 * 60 * 60  # 30 days
  
  # Cache Entry Limits
  MAX_CACHE_ENTRIES = 1000
  CONSERVATIVE_CACHE_ENTRIES = 500
  
  # Fallback Pool Size
  FALLBACK_POOL_SIZE = 100
  
  # User Preferences
  MIN_PREFERENCE_SCORE_FOR_BOOST = 1.0
end
