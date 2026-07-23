# frozen_string_literal: true

# Multi-Tier Caching System
# L1: Memory, L2: Redis, L3: Database
# Created: July 22, 2026

module MultiTierCache
  class << self
    # Fetch with automatic tier fallback
    def fetch(key, expires_in: 3600, &block)
      # L1: Memory cache
      value = memory_cache.get(key)
      return value if value
      
      # L2: Redis cache
      value = redis_cache.read(key)
      if value
        memory_cache.set(key, value, expires_in: 300)
        return value
      end
      
      # L3: Database - execute block
      value = block.call
      
      # Write to all cache layers
      memory_cache.set(key, value, expires_in: 300)
      redis_cache.write(key, value, expires_in)
      
      value
    end

    # Warm up cache with commonly accessed data
    def warm_up(keys = [])
      keys.each do |key, block|
        fetch(key, &block) unless memory_cache.get(key)
      end
    end

    # Clear all cache tiers
    def clear_all
      memory_cache.clear
      redis_cache.clear_all
    end

    private

    def memory_cache
      @memory_cache ||= MemoryCache.new(max_size: 1000)
    end

    def redis_cache
      @redis_cache ||= PerformanceCache
    end
  end

  class MemoryCache
    def initialize(max_size: 1000)
      @cache = {}
      @max_size = max_size
    end

    def get(key)
      entry = @cache[key]
      return nil unless entry
      return nil if entry[:expires_at] < Time.now
      entry[:value]
    end

    def set(key, value, expires_in: 300)
      @cache.shift if @cache.size >= @max_size
      @cache[key] = {
        value: value,
        expires_at: Time.now + expires_in
      }
    end

    def clear
      @cache.clear
    end
  end
end
