# Token Bucket Rate Limiter - Redis-backed distributed rate limiting
# Scales across multiple Puma workers with atomic operations

class TokenBucketLimiter
  def initialize(redis, bucket_name, capacity, refill_rate)
    @redis = redis
    @bucket_name = "rate_limit:#{bucket_name}"
    @capacity = capacity.to_f
    @refill_rate = refill_rate.to_f  # tokens per second
  end

  # Attempt to acquire tokens from the bucket
  # Returns true if successful, false if rate limited
  def acquire(tokens = 1)
    # Lua script ensures atomic execution across all workers
    script = <<~LUA
      local key = KEYS[1]
      local capacity = tonumber(ARGV[1])
      local refill_rate = tonumber(ARGV[2])
      local requested = tonumber(ARGV[3])
      local now = tonumber(ARGV[4])
      
      local bucket = redis.call('HMGET', key, 'tokens', 'last_refill')
      local tokens = tonumber(bucket[1]) or capacity
      local last_refill = tonumber(bucket[2]) or now
      
      -- Refill tokens based on time elapsed
      local elapsed = now - last_refill
      tokens = math.min(capacity, tokens + (elapsed * refill_rate))
      
      if tokens >= requested then
        tokens = tokens - requested
        redis.call('HMSET', key, 'tokens', tokens, 'last_refill', now)
        redis.call('EXPIRE', key, 120)
        return 1  -- Success
      else
        redis.call('HMSET', key, 'tokens', tokens, 'last_refill', now)
        redis.call('EXPIRE', key, 120)
        return 0  -- Rate limited
      end
    LUA

    result = @redis.eval(
      script,
      keys: [@bucket_name],
      argv: [@capacity, @refill_rate, tokens, Time.now.to_f]
    )

    result == 1
  rescue => e
    puts "⚠️  [TOKEN BUCKET] Error: #{e.message}"
    # Fail open - allow request on error to prevent cascading failures
    true
  end

  # Calculate how long until next token is available
  def wait_time
    bucket = @redis.hmget(@bucket_name, 'tokens', 'last_refill')
    tokens = bucket[0].to_f
    return 0 if tokens >= 1
    
    (1 - tokens) / @refill_rate
  rescue => e
    puts "⚠️  [TOKEN BUCKET] Wait time calculation error: #{e.message}"
    0
  end

  # Get current token count (for monitoring)
  def current_tokens
    bucket = @redis.hmget(@bucket_name, 'tokens', 'last_refill')
    tokens = bucket[0]&.to_f || @capacity
    last_refill = bucket[1]&.to_f || Time.now.to_f
    
    # Apply refill since last check
    elapsed = Time.now.to_f - last_refill
    [[@capacity, tokens + (elapsed * @refill_rate)].min, 0].max
  rescue => e
    puts "⚠️  [TOKEN BUCKET] Current tokens error: #{e.message}"
    @capacity
  end
end
