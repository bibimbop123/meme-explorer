# Adaptive Rate Limiter - Learns from API responses and adjusts automatically
# Intelligently backs off on 429s and gradually increases on success

require_relative 'token_bucket_limiter'

class AdaptiveRateLimiter
  def initialize(redis, api_name)
    @redis = redis
    @api_name = api_name
    @key = "adaptive_rate:#{api_name}"
    @initial_rate = 45  # Start conservative (Reddit allows 60)
    @min_rate = 10      # Never go below this
    @max_rate = 55      # Never exceed this (safety buffer)
  end

  # Get current rate limit
  def current_rate
    rate = @redis.get("#{@key}:current_rate")
    rate ? rate.to_i : @initial_rate
  rescue => e
    AppLogger.error("⚠️  [ADAPTIVE] Error getting rate: #{e.message}")
    @initial_rate
  end

  # Acquire a permit to make an API call (will wait if necessary)
  def acquire_permit
    limiter = TokenBucketLimiter.new(
      @redis,
      @api_name,
      current_rate,
      current_rate / 60.0  # convert to per-second rate
    )

    unless limiter.acquire
      wait_time = limiter.wait_time
      if wait_time > 0
        AppLogger.info("⏸️  [ADAPTIVE] Rate limited, waiting #{wait_time.round(2)}s (current rate: #{current_rate} req/min)")
        sleep(wait_time + 0.1)  # Small buffer
      end
    end
  rescue => e
    AppLogger.error("⚠️  [ADAPTIVE] Acquire error: #{e.message}")
    # Fail open - allow request
  end

  # Record a successful API call
  def record_success
    # Gradually increase rate on success (conservative growth)
    new_rate = [current_rate + 1, @max_rate].min
    @redis.setex("#{@key}:current_rate", 600, new_rate)
    
    # Clear any 429 history on consistent success
    successes = @redis.incr("#{@key}:consecutive_successes")
    @redis.expire("#{@key}:consecutive_successes", 300)
    
    if successes >= 10
      @redis.del("#{@key}:last_429")
      @redis.del("#{@key}:consecutive_successes")
    end
  rescue => e
    AppLogger.error("⚠️  [ADAPTIVE] Success recording error: #{e.message}")
  end

  # Record a rate limit response (429)
  def record_rate_limit(retry_after = nil)
    @redis.del("#{@key}:consecutive_successes")
    
    # Aggressively decrease rate on 429
    decrease_by = retry_after ? 15 : 10
    new_rate = [current_rate - decrease_by, @min_rate].max
    
    @redis.setex("#{@key}:current_rate", 600, new_rate)
    @redis.setex("#{@key}:last_429", 300, Time.now.to_i)
    @redis.incr("#{@key}:total_429s")
    
    AppLogger.warn("⚠️  [ADAPTIVE] Rate limit hit! Decreasing to #{new_rate} req/min (retry_after: #{retry_after}s)")
  rescue => e
    AppLogger.error("⚠️  [ADAPTIVE] Rate limit recording error: #{e.message}")
  end

  # Check if we're in cooldown from a recent 429
  def in_cooldown?
    last_429 = @redis.get("#{@key}:last_429")
    return false unless last_429
    
    cooldown_seconds = 120  # 2 minute cooldown
    Time.now.to_i - last_429.to_i < cooldown_seconds
  rescue => e
    AppLogger.error("⚠️  [ADAPTIVE] Cooldown check error: #{e.message}")
    false
  end

  # Get statistics (for monitoring)
  def stats
    {
      current_rate: current_rate,
      in_cooldown: in_cooldown?,
      total_429s: @redis.get("#{@key}:total_429s").to_i,
      consecutive_successes: @redis.get("#{@key}:consecutive_successes").to_i,
      last_429_ago: last_429_seconds_ago
    }
  rescue => e
    AppLogger.error("⚠️  [ADAPTIVE] Stats error: #{e.message}")
    {}
  end

  # Reset to initial state
  def reset!
    @redis.del("#{@key}:current_rate")
    @redis.del("#{@key}:last_429")
    @redis.del("#{@key}:total_429s")
    @redis.del("#{@key}:consecutive_successes")
    AppLogger.info("🔄 [ADAPTIVE] Reset to initial rate: #{@initial_rate} req/min")
  rescue => e
    AppLogger.error("⚠️  [ADAPTIVE] Reset error: #{e.message}")
  end

  private

  def last_429_seconds_ago
    last_429 = @redis.get("#{@key}:last_429")
    return nil unless last_429
    Time.now.to_i - last_429.to_i
  rescue
    nil
  end
end
