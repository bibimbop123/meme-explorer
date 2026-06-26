# Redis Resilience Module
# P1 Fix: Graceful degradation when Redis fails

module RedisResilience
  class RedisUnavailable < StandardError; end
  
  # Fallback chain: Redis -> Memory Cache -> Database -> Default
  def fetch_with_fallback(key, ttl: 300, fallback_to_memory: true, &block)
    # Try Redis first
    begin
      return RedisService.fetch(key, ttl: ttl, &block) if redis_available?
    rescue Redis::ConnectionError, Redis::TimeoutError => e
      AppLogger.warn("Redis unavailable, falling back", error: e.message, key: key)
      mark_redis_unavailable
    end
    
    # Fallback to memory cache
    if fallback_to_memory
      return MEME_CACHE.fetch(key, expires_in: ttl) { block.call } if defined?(MEME_CACHE)
    end
    
    # Last resort: execute block directly (no caching)
    AppLogger.warn("All caches unavailable, executing without cache", key: key)
    block.call
  end
  
  # Check if Redis is available (with circuit breaker pattern)
  def redis_available?
    # If we recently marked Redis as unavailable, don't try again immediately
    last_failure = @redis_last_failure_time
    if last_failure && (Time.now - last_failure) < redis_backoff_seconds
      return false
    end
    
    begin
      RedisService.ping
      @redis_last_failure_time = nil
      true
    rescue Redis::BaseError
      false
    end
  end
  
  # Mark Redis as unavailable and start backoff timer
  def mark_redis_unavailable
    @redis_last_failure_time = Time.now
  end
  
  # Exponential backoff for Redis reconnection attempts
  def redis_backoff_seconds
    failures = @redis_failure_count ||= 0
    [2 ** failures, 60].min  # Max 60 seconds backoff
  end
  
  # Try to write to Redis, but don't fail if it's unavailable
  def safe_redis_write(key, value, ttl: 300)
    return false unless redis_available?
    
    begin
      RedisService.set(key, value, ex: ttl)
      true
    rescue Redis::BaseError => e
      AppLogger.warn("Redis write failed", error: e.message, key: key)
      mark_redis_unavailable
      false
    end
  end
end
