# Meme Explorer Application Configuration - Centralized Constants
class MemeExplorerConfig
  # Session Configuration
  SESSION_EXPIRE_AFTER = 2_592_000  # 30 days in seconds
  COOKIE_OPTIONS = {
    secure: true,
    httponly: true,
    same_site: :lax,
    expires: Time.now + SESSION_EXPIRE_AFTER
  }.freeze

  # Cache Configuration
  MEME_CACHE_MAX_SIZE = 500 * 1024 * 1024  # 500 MB hard limit
  MEME_CACHE_TTL = 86_400                  # 24 hours
  CACHE_REFRESH_INTERVAL = 30              # seconds
  CACHE_INITIAL_DELAY = 2                  # seconds

  # Tier Weighting Configuration
  TIER_WEIGHTS = {
    tier_1: 35, tier_2: 18, tier_3: 15, tier_4: 10, tier_5: 8,
    tier_6: 5, tier_7: 3, tier_8: 2, tier_9: 2, tier_10: 2
  }.freeze
  TOTAL_TIER_WEIGHT = TIER_WEIGHTS.values.sum

  # Rate Limiting
  RATE_LIMIT_REQUESTS = 60
  RATE_LIMIT_PERIOD = 60

  class << self
    def validate!
      unless TOTAL_TIER_WEIGHT == 100
        raise ConfigurationError, "TIER_WEIGHTS must sum to 100"
      end
    end
  end
end

class ConfigurationError < StandardError; end
