# frozen_string_literal: true

# Performance-Optimized Caching Strategy
# Multi-layer caching with Redis
# Created: July 22, 2026

module PerformanceCache
  class << self
    # Cache with automatic expiration
    def fetch(key, expires_in: 3600, &block)
      cached = read(key)
      return cached if cached
      
      value = block.call
      write(key, value, expires_in)
      value
    end

    # Read from cache
    def read(key)
      return nil unless redis_available?
      
      value = redis.get(cache_key(key))
      value ? deserialize(value) : nil
    rescue => e
      AppLogger.warn("[Cache] Read failed: \\#{e.message}")
      nil
    end

    # Write to cache
    def write(key, value, expires_in = 3600)
      return false unless redis_available?
      
      redis.setex(cache_key(key), expires_in, serialize(value))
      true
    rescue => e
      AppLogger.warn("[Cache] Write failed: \#{e.message}")
      false
    end

    # Delete from cache
    def delete(key)
      return false unless redis_available?
      
      redis.del(cache_key(key))
      true
    rescue => e
      AppLogger.warn("[Cache] Delete failed: \#{e.message}")
      false
    end

    # Clear all cache
    def clear_all
      return false unless redis_available?
      
      pattern = "\#{cache_prefix}:*"
      keys = redis.keys(pattern)
      redis.del(*keys) if keys.any?
      true
    rescue => e
      AppLogger.error("[Cache] Clear failed: \#{e.message}")
      false
    end

    # Cache multiple keys at once
    def fetch_multi(keys, expires_in: 3600, &block)
      results = {}
      cache_keys = keys.map { |k| cache_key(k) }
      
      # Try to get all from cache
      cached_values = redis.mget(*cache_keys) if redis_available?
      
      keys.each_with_index do |key, idx|
        if cached_values && cached_values[idx]
          results[key] = deserialize(cached_values[idx])
        else
          # Cache miss - compute value
          value = block.call(key)
          results[key] = value
          write(key, value, expires_in)
        end
      end
      
      results
    rescue => e
      AppLogger.error("[Cache] fetch_multi failed: \#{e.message}")
      # Fallback - compute all
      keys.each_with_object({}) { |k, h| h[k] = block.call(k) }
    end

    private

    def redis
      @redis ||= Redis.new(
        url: ENV['REDIS_URL'] || 'redis://localhost:6379/0',
        timeout: 1,
        reconnect_attempts: 3
      )
    end

    def redis_available?
      @redis_available ||= begin
        redis.ping == 'PONG'
      rescue
        false
      end
    end

    def cache_key(key)
      "\#{cache_prefix}:\#{key}"
    end

    def cache_prefix
      ENV['CACHE_PREFIX'] || 'meme_explorer'
    end

    def serialize(value)
      JSON.generate(value)
    end

    def deserialize(value)
      JSON.parse(value)
    rescue
      value
    end
  end
end
