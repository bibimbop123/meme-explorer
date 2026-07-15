# frozen_string_literal: true

# ============================================
# REDIS MONITORING HELPER
# ============================================
# Week 1 Day 6-7: Monitor Redis health and memory

module RedisMonitoringHelper
  # Redis memory alert threshold (80% of max memory)
  MEMORY_ALERT_THRESHOLD = 0.80
  
  # Get Redis statistics
  def self.redis_stats
    RedisService.redis_pool.with do |redis|
      info = redis.info
      
      {
        used_memory: info['used_memory_human'],
        used_memory_bytes: info['used_memory'].to_i,
        max_memory_bytes: info['maxmemory'].to_i,
        memory_usage_percent: calculate_memory_percent(info),
        total_keys: redis.dbsize,
        connected_clients: info['connected_clients'].to_i,
        uptime_days: info['uptime_in_days'].to_i,
        hit_rate: calculate_hit_rate(info)
      }
    end
  rescue => e
    AppLogger.error("[RedisMonitoring] Failed to get stats: #{e.message}")
    nil
  end
  
  # Check if Redis memory is approaching limit
  def self.check_memory_alert
    stats = redis_stats
    return false unless stats
    
    if stats[:memory_usage_percent] > MEMORY_ALERT_THRESHOLD
      AppLogger.warn(
        "[RedisMonitoring] ALERT: Redis memory usage at " \
        "#{(stats[:memory_usage_percent] * 100).round(1)}%"
      )
      true
    else
      false
    end
  end
  
  # Get keys without TTL (memory leak candidates)
  def self.keys_without_ttl(limit: 100)
    keys_no_ttl = []
    
    RedisService.redis_pool.with do |redis|
      redis.keys('*').first(limit).each do |key|
        ttl = redis.ttl(key)
        keys_no_ttl << key if ttl == -1
      end
    end
    
    keys_no_ttl
  rescue => e
    AppLogger.error("[RedisMonitoring] Failed to check TTLs: #{e.message}")
    []
  end
  
  # Get memory usage by namespace
  def self.memory_by_namespace
    namespaces = Hash.new(0)
    
    RedisService.redis_pool.with do |redis|
      redis.keys('*').each do |key|
        namespace = key.split(':').first
        size = redis.strlen(key)
        namespaces[namespace] += size
      end
    end
    
    # Sort by size descending
    namespaces.sort_by { |_k, v| -v }.to_h
  rescue => e
    AppLogger.error("[RedisMonitoring] Failed to analyze namespaces: #{e.message}")
    {}
  end
  
  private
  
  def self.calculate_memory_percent(info)
    used = info['used_memory'].to_f
    max = info['maxmemory'].to_f
    
    return 0.0 if max.zero?
    
    used / max
  end
  
  def self.calculate_hit_rate(info)
    hits = info['keyspace_hits'].to_f
    misses = info['keyspace_misses'].to_f
    total = hits + misses
    
    return 0.0 if total.zero?
    
    (hits / total * 100).round(2)
  end
end
