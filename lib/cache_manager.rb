require 'monitor'

class CacheManager
  @@cache = {}
  @@cache_lock = Monitor.new
  @@cache_timestamps = {}
  @@cache_hit_count = {}
  @@cache_ttl = {}  # Store TTL per key
  MAX_CACHE_SIZE = 100 * 1024 * 1024
  DEFAULT_TTL = 3600  # 1 hour default
  MAX_TTL = 86400     # 24 hours max

  # Instance methods - delegate to class methods
  def [](key)
    self.class.get(key)
  end

  def []=(key, value)
    self.class.set(key, value)
  end

  def get(key)
    self.class.get(key)
  end

  def set(key, value, ttl = DEFAULT_TTL)
    self.class.set(key, value, ttl)
  end

  def delete(key)
    self.class.delete(key)
  end

  def clear
    self.class.clear
  end

  def size
    self.class.size
  end

  def stats
    self.class.stats
  end

  class << self
    def get(key)
      @@cache_lock.synchronize do
        # Check TTL expiration
        if @@cache.key?(key)
          if expired?(key)
            # Auto-delete expired entries
            delete_unsafe(key)
            return nil
          end
          
          @@cache_hit_count[key] = (@@cache_hit_count[key] || 0) + 1
          return @@cache[key]
        end
      end
      nil
    end

    def set(key, value, ttl = DEFAULT_TTL)
      @@cache_lock.synchronize do
        # Evict before adding to prevent memory overflow
        if should_evict?
          evict_lru
        end
        
        # Clamp TTL to reasonable bounds
        ttl = [[ttl, 0].max, MAX_TTL].min
        
        @@cache[key] = value
        @@cache_timestamps[key] = Time.now
        @@cache_ttl[key] = ttl
        @@cache_hit_count[key] = 0
      end
    end

    def delete(key)
      @@cache_lock.synchronize do
        delete_unsafe(key)
      end
    end

    def clear
      @@cache_lock.synchronize do
        @@cache.clear
        @@cache_timestamps.clear
        @@cache_hit_count.clear
        @@cache_ttl.clear
      end
    end

    def size
      @@cache_lock.synchronize do
        @@cache.size
      end
    end

    def stats
      @@cache_lock.synchronize do
        {
          size: @@cache.size,
          estimated_memory: estimate_size,
          max_memory: MAX_CACHE_SIZE,
          keys: @@cache.keys,
          expired_count: count_expired
        }
      end
    end

    # Atomic transaction support
    def transaction(&block)
      @@cache_lock.synchronize(&block)
    end

    # Clean up all expired entries
    def cleanup_expired
      @@cache_lock.synchronize do
        expired_keys = @@cache.keys.select { |key| expired?(key) }
        expired_keys.each { |key| delete_unsafe(key) }
        expired_keys.size
      end
    end

    private

    # Check if key has expired (must be called within synchronized block)
    def expired?(key)
      return false unless @@cache_timestamps[key]
      
      ttl = @@cache_ttl[key] || DEFAULT_TTL
      age = Time.now - @@cache_timestamps[key]
      age > ttl
    rescue => e
      puts "⚠️ Cache expiration check error: #{e.message}"
      false
    end

    # Count expired entries (must be called within synchronized block)
    def count_expired
      @@cache.keys.count { |key| expired?(key) }
    rescue => e
      puts "⚠️ Cache count error: #{e.message}"
      0
    end

    # Delete without lock (must be called within synchronized block)
    def delete_unsafe(key)
      @@cache.delete(key)
      @@cache_timestamps.delete(key)
      @@cache_hit_count.delete(key)
      @@cache_ttl.delete(key)
    end

    def should_evict?
      # FIX: Use hard size limit as backup if estimate fails
      return true if @@cache.size > 1000  # Hard entry limit
      
      begin
        estimate_size > MAX_CACHE_SIZE
      rescue => e
        puts "⚠️ Cache size estimation failed: #{e.message}"
        @@cache.size > 500  # Conservative fallback
      end
    end

    def evict_lru
      return if @@cache.empty?
      
      # First try to evict expired entries
      expired_keys = @@cache.keys.select { |key| expired?(key) }
      if expired_keys.any?
        expired_keys.each { |key| delete_unsafe(key) }
        return
      end
      
      # Otherwise evict least recently used
      lru_key = @@cache.keys.min_by do |key|
        hit_count = @@cache_hit_count[key] || 0
        timestamp = @@cache_timestamps[key] || Time.now
        [hit_count, timestamp.to_i]
      end
      
      delete_unsafe(lru_key) if lru_key
    rescue => e
      puts "⚠️ Cache eviction error: #{e.message}"
      # Emergency: delete oldest entry
      oldest_key = @@cache_timestamps.min_by { |k, v| v }&.first
      delete_unsafe(oldest_key) if oldest_key
    end

    def estimate_size
      total_size = 0
      @@cache.each do |key, value|
        total_size += key.to_s.bytesize
        total_size += estimate_object_size(value)
      end
      total_size
    rescue => e
      puts "⚠️ Cache size estimation error: #{e.message}"
      # FIX: Better fallback estimation
      @@cache.size * 10_000
    end

    def estimate_object_size(obj)
      case obj
      when String
        obj.bytesize + 40
      when Array
        (obj.map { |item| estimate_object_size(item) }.sum) + 40
      when Hash
        (obj.sum { |k, v| estimate_object_size(k) + estimate_object_size(v) }) + 40
      when Integer, Float, TrueClass, FalseClass, NilClass
        24
      when Symbol
        obj.to_s.bytesize + 40
      else
        100
      end
    rescue => e
      puts "⚠️ Object size estimation error: #{e.message}"
      100
    end
  end
end
