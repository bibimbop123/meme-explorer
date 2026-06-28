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
#
# TTL implementation uses a single background reaper thread that wakes every
# REAPER_INTERVAL seconds and evicts all expired entries in one pass.
# This replaces the previous per-key Thread.new { sleep ex; delete(key) }
# pattern, which created O(n) threads and leaked them whenever the cache was
# heavily written to (each thread blocked on sleep, then contended the mutex).
#
# Trade-off: keys may linger up to REAPER_INTERVAL seconds past their TTL.
# For an in-process memory fallback that only runs when Redis is unavailable,
# that precision is more than acceptable.
class MemoryCache
  REAPER_INTERVAL = 30 # seconds between eviction sweeps

  def initialize
    @cache    = {}   # key => value
    @expires  = {}   # key => Time (absolute expiry)
    @mutex    = Mutex.new
    start_reaper
  end

  def get(key)
    @mutex.synchronize do
      exp = @expires[key]
      if exp && Time.now >= exp
        @cache.delete(key)
        @expires.delete(key)
        return nil
      end
      @cache[key]
    end
  end

  def set(key, value, ex: nil)
    @mutex.synchronize do
      @cache[key]   = value
      @expires[key] = Time.now + ex if ex
    end
  end

  def del(key)
    @mutex.synchronize do
      @cache.delete(key)
      @expires.delete(key)
    end
  end

  def exists?(key)
    @mutex.synchronize do
      exp = @expires[key]
      if exp && Time.now >= exp
        @cache.delete(key)
        @expires.delete(key)
        return false
      end
      @cache.key?(key)
    end
  end

  def keys(pattern = '*')
    @mutex.synchronize { @cache.keys }
  end

  def clear
    @mutex.synchronize do
      @cache.clear
      @expires.clear
    end
  end

  private

  # One reaper thread per MemoryCache instance.
  # Runs as a daemon so it never blocks clean process shutdown.
  def start_reaper
    t = Thread.new do
      Thread.current.name             = 'memory-cache-reaper'
      Thread.current.abort_on_exception = false
      loop do
        sleep REAPER_INTERVAL
        evict_expired
      end
    end
    t.abort_on_exception = false
  end

  def evict_expired
    now = Time.now
    @mutex.synchronize do
      @expires.each do |key, exp|
        next if now < exp
        @cache.delete(key)
        @expires.delete(key)
      end
    end
  rescue => e
    AppLogger.warn('MemoryCache reaper: eviction sweep failed', error: e.message)
  end
end

MEMORY_CACHE = MemoryCache.new
