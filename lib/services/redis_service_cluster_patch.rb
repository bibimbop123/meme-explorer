# frozen_string_literal: true

# Redis Service Cluster Support Patch
# Based on: REFACTORING_ROADMAP Phase 4, Task 6.3
# This enhances the existing RedisService with cluster failover

module RedisServiceClusterSupport
  # Execute Redis command with automatic failover
  def with_redis(&block)
    REDIS_POOL.with do |redis|
      yield(redis)
    end
  rescue Redis::CannotConnectError, Redis::TimeoutError => e
    handle_redis_failure(e, &block)
  rescue => e
    AppLogger.error("Redis operation failed", 
      error: e.class.name,
      message: e.message,
      backtrace: e.backtrace.first(3)
    )
    # Fall back to memory cache
    yield(MEMORY_CACHE)
  end

  # Get with automatic failover
  def get_with_fallback(key, &fallback_block)
    with_redis do |redis|
      value = redis.get(key)
      return value if value
    end

    # If not in cache, execute fallback and cache result
    if fallback_block
      value = fallback_block.call
      set_with_fallback(key, value) if value
      value
    end
  rescue => e
    AppLogger.error("Redis get failed, using fallback", key: key, error: e.message)
    fallback_block&.call
  end

  # Set with automatic failover
  def set_with_fallback(key, value, ttl: 3600)
    with_redis do |redis|
      redis.set(key, value, ex: ttl)
    end
  rescue => e
    AppLogger.warn("Redis set failed, using memory cache", key: key, error: e.message)
    MEMORY_CACHE.set(key, value, ex: ttl)
  end

  # Delete with automatic failover
  def del_with_fallback(key)
    with_redis do |redis|
      redis.del(key)
    end
  rescue => e
    AppLogger.warn("Redis delete failed", key: key, error: e.message)
    MEMORY_CACHE.del(key)
  end

  # Check health of Redis cluster
  def redis_healthy?
    with_redis do |redis|
      redis.ping == 'PONG'
    end
  rescue
    false
  end

  # Get Redis info
  def redis_info
    with_redis do |redis|
      info = redis.info
      {
        version: info['redis_version'],
        used_memory: info['used_memory_human'],
        connected_clients: info['connected_clients'],
        total_commands: info['total_commands_processed'],
        cluster_enabled: info['cluster_enabled'] == '1'
      }
    end
  rescue => e
    AppLogger.error("Failed to get Redis info", error: e.message)
    { error: e.message }
  end

  private

  def handle_redis_failure(error, &block)
    AppLogger.error("Redis connection failed, falling back to memory cache", 
      error: error.class.name,
      message: error.message
    )

    # Use memory cache as fallback
    yield(MEMORY_CACHE)
    
    # Notify operations team
    notify_redis_failure(error) if defined?(notify_redis_failure)
  end
end

# Extend RedisService if it exists
if defined?(RedisService)
  RedisService.extend(RedisServiceClusterSupport)
  AppLogger.info("RedisService extended with cluster support")
end
