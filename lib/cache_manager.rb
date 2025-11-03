require 'monitor'

class CacheManager
  @@cache = {}
  @@cache_lock = Monitor.new
  @@cache_timestamps = {}
  @@cache_hit_count = {}
  MAX_CACHE_SIZE = 100 * 1024 * 1024

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

  def set(key, value, ttl = 3600)
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
        if @@cache.key?(key)
          @@cache_hit_count[key] = (@@cache_hit_count[key] || 0) + 1
          return @@cache[key]
        end
      end
      nil
    end

    def set(key, value, ttl = 3600)
      @@cache_lock.synchronize do
        if should_evict?
          evict_lru
        end
        @@cache[key] = value
        @@cache_timestamps[key] = Time.now
        @@cache_hit_count[key] = 0
      end
    end

    def delete(key)
      @@cache_lock.synchronize do
        @@cache.delete(key)
        @@cache_timestamps.delete(key)
        @@cache_hit_count.delete(key)
      end
    end

    def clear
      @@cache_lock.synchronize do
        @@cache.clear
        @@cache_timestamps.clear
        @@cache_hit_count.clear
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
          keys: @@cache.keys
        }
      end
    end

    private

    def should_evict?
      estimate_size > MAX_CACHE_SIZE
    end

    def evict_lru
      return if @@cache.empty?
      lru_key = @@cache.keys.min_by do |key|
        hit_count = @@cache_hit_count[key] || 0
        timestamp = @@cache_timestamps[key] || Time.now
        [hit_count, timestamp.to_i]
      end
      @@cache.delete(lru_key)
      @@cache_timestamps.delete(lru_key)
      @@cache_hit_count.delete(lru_key)
    end

    def estimate_size
      total_size = 0
      @@cache.each do |key, value|
        total_size += key.to_s.bytesize
        total_size += estimate_object_size(value)
      end
      total_size
    rescue => e
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
      100
    end
  end
end
