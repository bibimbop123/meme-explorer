# Distributed Locking Module for Redis
# Prevents race conditions in worker processes
module DistributedLock
  class LockAcquisitionError < StandardError; end
  
  # Acquire a distributed lock using Redis
  # Uses SET NX EX for atomic lock acquisition with TTL
  #
  # @param key [String] Lock identifier
  # @param ttl [Integer] Time-to-live in seconds (default: 300)
  # @param block [Block] Code to execute while holding the lock
  # @return [Boolean] true if lock was acquired and block executed
  def with_redis_lock(key, ttl: 300, &block)
    return false unless defined?(REDIS) && REDIS
    
    lock_key = "lock:#{key}"
    lock_token = SecureRandom.uuid
    
    # Try to acquire lock atomically
    acquired = REDIS.set(lock_key, lock_token, nx: true, ex: ttl)
    return false unless acquired
    
    begin
      yield
      true
    ensure
      # Release lock only if we still own it (prevent releasing someone else's lock)
      release_lock(lock_key, lock_token)
    end
  rescue => e
    # Log error but don't re-raise to allow cleanup
    AppLogger.error("⚠️ [DistributedLock] Error in locked block: #{e.class} - #{e.message}")
    raise
  end
  
  # Try to acquire lock with retries
  # Useful for non-critical operations that can wait
  def with_redis_lock_retry(key, ttl: 300, max_attempts: 3, retry_delay: 1, &block)
    attempts = 0
    
    while attempts < max_attempts
      result = with_redis_lock(key, ttl: ttl, &block)
      return true if result
      
      attempts += 1
      sleep(retry_delay) if attempts < max_attempts
    end
    
    false
  end
  
  # Check if a lock is currently held
  def lock_held?(key)
    return false unless defined?(REDIS) && REDIS
    REDIS.exists?("lock:#{key}")
  end
  
  private
  
  # Release lock using Lua script to ensure atomicity
  # Only releases if the token matches (we still own the lock)
  def release_lock(lock_key, lock_token)
    lua_script = <<-LUA
      if redis.call("get", KEYS[1]) == ARGV[1] then
        return redis.call("del", KEYS[1])
      else
        return 0
      end
    LUA
    
    REDIS.eval(lua_script, keys: [lock_key], argv: [lock_token])
  rescue => e
    AppLogger.error("⚠️ [DistributedLock] Error releasing lock: #{e.message}")
  end
end
