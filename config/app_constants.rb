# frozen_string_literal: true

# Application-wide constants for Meme Explorer
# Extracted from app.rb for better organization

module MemeExplorerConstants
  # Reddit API Configuration
  REDDIT_REQUEST_DELAY = 1.5  # Seconds between Reddit API requests
  DEFAULT_MEME_LIMIT = 45      # Optimal pool size for meme fetching
  MAX_SUBREDDIT_SAMPLE = 40    # Maximum subreddits to sample at once
  
  # Pool Distribution Ratios
  TRENDING_RATIO = 0.7    # 70% trending content
  FRESH_RATIO = 0.2       # 20% fresh content
  EXPLORATION_RATIO = 0.1 # 10% exploration content
  
  # Cache Configuration
  CACHE_TTL_MEMES = 300        # 5 minutes
  CACHE_TTL_USER_DATA = 300    # 5 minutes
  MAX_CACHE_SIZE = 100 * 1024 * 1024  # 100MB
  
  # Pagination Defaults
  DEFAULT_PAGE_SIZE = 10
  MAX_PAGE_SIZE = 100
  
  # Session Configuration
  MAX_MEME_HISTORY = 100      # Keep last 100 memes in session
  MAX_SEEN_MEMES_COOKIE = 30  # Keep last 30 in cookie
  
  # User Engagement
  NEW_USER_THRESHOLD = 10     # Views before user is "established"
  MAX_SELECTION_ATTEMPTS = 30 # Max attempts to find valid meme
  
  # Spaced Repetition (defined in constants.rb to avoid duplication)
  
  # Rate Limiting
  REQUESTS_PER_MINUTE = 60
  RATE_LIMIT_WINDOW = 60  # seconds
  
  # Image Validation
  MAX_IMAGE_FAILURES = 5
  IMAGE_TIMEOUT = 5  # seconds
  
  # User Agents for Reddit API
  USER_AGENTS = [
    "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
    "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
    "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
    "Mozilla/5.0 (iPhone; CPU iPhone OS 14_7_1 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/14.1.2 Mobile/15E148 Safari/604.1"
  ].freeze
  
  # Fallback Images
  FALLBACK_IMAGES = {
    funny: ['/images/funny1.jpeg', '/images/funny2.jpeg', '/images/funny3.jpeg'],
    wholesome: ['/images/wholesome1.jpeg', '/images/wholesome2.jpeg', '/images/wholesome3.jpeg'],
    selfcare: ['/images/selfcare1.jpeg', '/images/selfcare2.jpeg', '/images/selfcare3.jpeg']
  }.freeze
  
  DEFAULT_FALLBACK = '/images/funny1.jpeg'
end
