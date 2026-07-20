class ActivityAggregationWorker
  include Sidekiq::Worker
  
  sidekiq_options queue: :default, retry: 3
  
  def perform
    AppLogger.info("📊 [ACTIVITY WORKER] Aggregating activity stats at #{Time.now}")
    
    return unless defined?(REDIS) && REDIS
    
    # Get all active user keys
    active_keys = REDIS.keys("active:*")
    
    # Count unique users in last 5 minutes (keys with remaining TTL)
    active_count = active_keys.count do |key|
      ttl = REDIS.ttl(key)
      ttl > 0  # Still active
    end
    
    # Store hourly aggregates
    hour_key = "activity:hourly:#{Time.now.strftime('%Y%m%d%H')}"
    REDIS.hincrby(hour_key, "active_users", active_count)
    REDIS.hincrby(hour_key, "samples", 1)
    REDIS.expire(hour_key, 86400)  # Keep for 24 hours
    
    # Calculate and store average
    samples = REDIS.hget(hour_key, "samples").to_i
    total = REDIS.hget(hour_key, "active_users").to_i
    avg = samples > 0 ? (total.to_f / samples).round(1) : 0
    REDIS.hset(hour_key, "average", avg)
    AppLogger.info("✅ [ACTIVITY WORKER] Logged #{active_count} active users (avg: #{avg})")
    
  rescue => e
    AppLogger.info("❌ [ACTIVITY WORKER] Error: #{e.message}")
    AppLogger.info(e.backtrace.first(5).join("\n"))
    # Don't raise - not critical
  end
end
