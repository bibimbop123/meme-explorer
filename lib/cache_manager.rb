# Meme Explorer Cache Manager - LRU cache with memory limits
class MemeExplorerCacheManager
  def initialize(max_size_bytes, ttl_seconds)
      @max_size = max_size_bytes
      @ttl = ttl_seconds
      @cache = {}
      @timestamps = {}
      @access_times = {}
      @mutex = Mutex.new
      @current_size = 0
    end

    def set(key, value)
      @mutex.synchronize do
        if @cache[key]
          @current_size -= estimate_size(@cache[key])
        end

        @cache[key] = value
        @timestamps[key] = Time.now
        @access_times[key] = Time.now
        new_size = estimate_size(value)
        @current_size += new_size

        evict_if_needed
      end
    end

    def get(key)
      @mutex.synchronize do
        return nil unless @cache[key]
        if Time.now - @timestamps[key] > @ttl
          delete(key)
          return nil
        end
        @access_times[key] = Time.now
        @cache[key]
      end
    end

    def delete(key)
      @mutex.synchronize do
        if @cache[key]
          @current_size -= estimate_size(@cache[key])
          @cache.delete(key)
          @timestamps.delete(key)
          @access_times.delete(key)
        end
      end
    end

    def clear
      @mutex.synchronize do
        @cache.clear
        @timestamps.clear
        @access_times.clear
        @current_size = 0
      end
    end

    def stats
      @mutex.synchronize do
        {
          size: @current_size,
          max_size: @max_size,
          used_percent: (@current_size.to_f / @max_size * 100).round(2),
          entries: @cache.size,
          ttl: @ttl
        }
      end
    end

    private

    def estimate_size(value)
      case value
      when String
        value.bytesize
      when Array
        value.sum { |v| estimate_size(v) }
      when Hash
        value.sum { |k, v| estimate_size(k) + estimate_size(v) }
      else
        ObjectSpace.memsize_of(value)
      end
    end

    def evict_if_needed
      while @current_size > @max_size && !@cache.empty?
        lru_key = @access_times.min_by { |k, v| v }[0]
        delete(lru_key)
      end

      now = Time.now
      @cache.each_key do |key|
        delete(key) if now - @timestamps[key] > @ttl
      end
  end
end
