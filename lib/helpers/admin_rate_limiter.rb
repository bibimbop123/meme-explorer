# Admin Operation Rate Limiter
# P1 Fix: Prevent DoS on expensive operations

module AdminRateLimiter
  # Track last execution time for expensive operations
  @operation_timestamps = {}
  @operation_lock = Mutex.new
  
  class << self
    # Check if operation is allowed (with cooldown)
    def allowed?(operation_key, cooldown_seconds: 60)
      @operation_lock.synchronize do
        last_execution = @operation_timestamps[operation_key]
        
        if last_execution.nil?
          mark_executed(operation_key)
          return true
        end
        
        elapsed = Time.now - last_execution
        if elapsed >= cooldown_seconds
          mark_executed(operation_key)
          return true
        end
        
        false
      end
    end
    
    # Get remaining cooldown time
    def remaining_cooldown(operation_key, cooldown_seconds: 60)
      @operation_lock.synchronize do
        last_execution = @operation_timestamps[operation_key]
        return 0 if last_execution.nil?
        
        elapsed = Time.now - last_execution
        remaining = cooldown_seconds - elapsed
        [remaining, 0].max.to_i
      end
    end
    
    # Mark operation as executed
    def mark_executed(operation_key)
      @operation_timestamps[operation_key] = Time.now
    end
    
    # Clean up old timestamps (prevent memory leak)
    def cleanup_old_timestamps(max_age_seconds: 3600)
      @operation_lock.synchronize do
        cutoff = Time.now - max_age_seconds
        @operation_timestamps.delete_if { |_key, timestamp| timestamp < cutoff }
      end
    end
  end
  
  # Helper method for routes
  def check_admin_rate_limit(operation_key, cooldown: AppConfig::ADMIN_CACHE_REBUILD_COOLDOWN_SECONDS)
    unless AdminRateLimiter.allowed?(operation_key, cooldown_seconds: cooldown)
      remaining = AdminRateLimiter.remaining_cooldown(operation_key, cooldown_seconds: cooldown)
      halt 429, {
        error: "Rate limit exceeded",
        message: "This operation is rate limited. Please wait #{remaining} seconds.",
        retry_after: remaining
      }.to_json
    end
  end
end
