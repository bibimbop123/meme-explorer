# frozen_string_literal: true

# Redis Cluster Configuration
# Based on: REFACTORING_ROADMAP Phase 4, Task 6.3

require 'connection_pool'
require 'redis'

# Redis cluster or single instance
REDIS_CLUSTER_ENABLED = ENV['REDIS_CLUSTER'] == 'true'
REDIS_POOL_SIZE = (ENV['REDIS_POOL_SIZE'] || 50).to_i
REDIS_TIMEOUT = (ENV['REDIS_TIMEOUT'] || 5).to_i

if REDIS_CLUSTER_ENABLED && ENV['REDIS_CLUSTER_URLS']
  # Multiple Redis nodes for clustering
  redis_urls = ENV['REDIS_CLUSTER_URLS'].split(',').map(&:strip)
  
  REDIS_POOL = ConnectionPool.new(size: REDIS_POOL_SIZE, timeout: REDIS_TIMEOUT) do
    Redis.new(
      cluster: redis_urls,
      reconnect_attempts: 3,
      reconnect_delay: 1,
      reconnect_delay_max: 5,
      timeout: REDIS_TIMEOUT
    )
  end

  AppLogger.info("Redis Cluster configured", 
    nodes: redis_urls.length,
    pool_size: REDIS_POOL_SIZE
  )
else
  # Single Redis instance (existing)
  REDIS_POOL = ConnectionPool.new(size: REDIS_POOL_SIZE, timeout: REDIS_TIMEOUT) do
    Redis.new(
      url: ENV['REDIS_URL'] || 'redis://localhost:6379/0',
      reconnect_attempts: 3,
      reconnect_delay: 1,
      timeout: REDIS_TIMEOUT
    )
  end

  AppLogger.info("Redis single instance configured", 
    pool_size: REDIS_POOL_SIZE
  )
end

# Memory cache fallback (if Redis unavailable)
class MemoryCache
  def initialize
    @cache = {}
    @mutex = Mutex.new
  end

  def get(key)
    @mutex.synchronize { @cache[key] }
  end

  def set(key, value, ex: nil)
    @mutex.synchronize do
      @cache[key] = value
      # Schedule expiration if specified
      if ex
        # Short-lived TTL expiry thread — one per key, lives for `ex` seconds then exits
        t = Thread.new do
          Thread.current.name = "cache-ttl-#{key[0..20]}"
          Thread.current.abort_on_exception = false
          sleep ex
          @mutex.synchronize { @cache.delete(key) }
        end
        t.abort_on_exception = false
      end
    end
  end

  def del(key)
    @mutex.synchronize { @cache.delete(key) }
  end

  def exists?(key)
    @mutex.synchronize { @cache.key?(key) }
  end

  def keys(pattern = '*')
    @mutex.synchronize { @cache.keys }
  end

  def clear
    @mutex.synchronize { @cache.clear }
  end
end

MEMORY_CACHE = MemoryCache.new
