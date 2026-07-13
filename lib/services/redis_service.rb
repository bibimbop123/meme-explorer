# Redis Service - Centralized Redis access with error handling and fallbacks
# Usage: RedisService.fetch('key') { fallback_value }
#
# This service provides:
# - Automatic connection pooling
# - Error handling with fallbacks
# - Circuit breaker pattern
# - Consistent logging
# - Performance monitoring

class RedisService
  class RedisError < StandardError; end
  
  class << self
    # Fetch from Redis with automatic fallback
    # @param key [String] Redis key
    # @param ttl [Integer] Time-to-live in seconds (default: 1 hour)
    # @param fallback [Proc] Block that returns fallback value if Redis fails
    # @return [Object] Cached value or fallback result
    #
    # Example:
    #   memes = RedisService.fetch('popular_memes', ttl: 300) do
    #     MemeService.fetch_from_api
    #   end
    def fetch(key, ttl: 3600, &fallback)
      return fallback.call unless redis_available?
      
      REDIS_POOL.with do |redis|
        cached = redis.get(key)
        return parse_value(cached) if cached
        
        value = fallback.call
        redis.setex(key, ttl, serialize_value(value)) if value
        value
      end
    rescue Redis::BaseError, ConnectionPool::TimeoutError => e
      handle_error(e, operation: 'fetch', key: key)
      fallback.call
    end
    
    # Get value from Redis with fallback
    # @param key [String] Redis key
    # @param default [Object] Default value if key doesn't exist or Redis fails
    # @return [Object] Value from Redis or default
    def get(key, default: nil)
      return default unless redis_available?
      
      REDIS_POOL.with do |redis|
        value = redis.get(key)
        return default if value.nil?
        parse_value(value)
      end
    rescue => e
      handle_error(e, operation: 'get', key: key)
      default
    end
    
    # Set value in Redis with error handling
    # @param key [String] Redis key
    # @param value [Object] Value to store
    # @param ttl [Integer] Time-to-live in seconds (default: 1 hour)
    # @return [Boolean] Success status
    def set(key, value, ttl: 3600)
      return false unless redis_available?
      
      REDIS_POOL.with do |redis|
        redis.setex(key, ttl, serialize_value(value))
        true
      end
    rescue Redis::BaseError, ConnectionPool::TimeoutError => e
      handle_error(e, operation: 'set', key: key)
      false
    end
    
    # Delete key from Redis
    # @param key [String] Redis key
    # @return [Boolean] Success status
    def delete(key)
      return false unless redis_available?
      
      REDIS_POOL.with do |redis|
        redis.del(key)
        true
      end
    rescue Redis::BaseError, ConnectionPool::TimeoutError => e
      handle_error(e, operation: 'delete', key: key)
      false
    end
    
    # Push value(s) to end of Redis list
    # @param key [String] Redis list key
    # @param values [String|Array] Value(s) to push
    # @return [Integer] New list length
    def rpush(key, *values)
      return 0 unless redis_available?
      
      REDIS_POOL.with do |redis|
        redis.rpush(key, *values)
      end
    rescue => e
      handle_error(e, operation: 'rpush', key: key)
      0
    end
    
    # Get range of values from Redis list
    # @param key [String] Redis list key  
    # @param start [Integer] Start index (default 0)
    # @param stop [Integer] Stop index (default -1 = all)
    # @return [Array<String>] List values
    def lrange(key, start = 0, stop = -1)
      return [] unless redis_available?
      
      REDIS_POOL.with do |redis|
        redis.lrange(key, start, stop)
      end
    rescue => e
      handle_error(e, operation: 'lrange', key: key)
      []
    end
    
    # Get list length
    # @param key [String] Redis list key
    # @return [Integer] List length
    def llen(key)
      return 0 unless redis_available?
      
      REDIS_POOL.with do |redis|
        redis.llen(key)
      end
    rescue => e
      handle_error(e, operation: 'llen', key: key)
      0
    end
    
    # Set hash field
    # @param key [String] Redis hash key
    # @param field [String] Hash field name
    # @param value [String] Value to store
    # @return [Boolean] Success status
    def hset(key, field, value)
      return false unless redis_available?
      
      REDIS_POOL.with do |redis|
        redis.hset(key, field, value)
        true
      end
    rescue => e
      handle_error(e, operation: 'hset', key: key)
      false
    end
    
    # Get hash field
    # @param key [String] Redis hash key
    # @param field [String] Hash field name
    # @return [String|nil] Field value
    def hget(key, field)
      return nil unless redis_available?
      
      REDIS_POOL.with do |redis|
        redis.hget(key, field)
      end
    rescue => e
      handle_error(e, operation: 'hget', key: key)
      nil
    end
    
    # Set expiration on key
    # @param key [String] Redis key
    # @param seconds [Integer] TTL in seconds
    # @return [Boolean] Success status
    def expire(key, seconds)
      return false unless redis_available?
      
      REDIS_POOL.with do |redis|
        redis.expire(key, seconds)
        true
      end
    rescue => e
      handle_error(e, operation: 'expire', key: key)
      false
    end
    
    # Direct Redis access with error handling and connection pooling
    # Use this for operations not covered by helper methods
    #
    # Example:
    #   RedisService.with_redis do |redis|
    #     redis.zadd('leaderboard', 100, 'user_123')
    #     redis.zrange('leaderboard', 0, 9)
    #   end
    def with_redis(&block)
      return nil unless redis_available?
      
      REDIS_POOL.with(&block)
    rescue Redis::BaseError, ConnectionPool::TimeoutError => e
      handle_error(e, operation: 'with_redis')
      nil
    end
    
    # Check if Redis is available
    # Caches result for 30 seconds to avoid overhead
    # @return [Boolean] Redis availability status
    def redis_available?
      return @redis_available if defined?(@redis_available) && 
                                  defined?(@redis_check_time) && 
                                  (Time.now - @redis_check_time) < 30
      
      @redis_check_time = Time.now
      @redis_available = begin
        REDIS_POOL.with { |r| r.ping == 'PONG' }
        true
      rescue
        false
      end
    end
    
    # Force refresh of Redis availability check
    def refresh_availability!
      remove_instance_variable(:@redis_available) if defined?(@redis_available)
      remove_instance_variable(:@redis_check_time) if defined?(@redis_check_time)
      redis_available?
    end
    
    # Get comprehensive Redis stats
    # @return [Hash] Redis status and pool information
    def stats
      return { available: false, error: 'Redis not available' } unless redis_available?
      
      REDIS_POOL.with do |redis|
        info = redis.info
        {
          available: true,
          connected: true,
          used_memory: info['used_memory_human'],
          used_memory_peak: info['used_memory_peak_human'],
          connected_clients: info['connected_clients'].to_i,
          total_commands_processed: info['total_commands_processed'].to_i,
          instantaneous_ops_per_sec: info['instantaneous_ops_per_sec'].to_i,
          keyspace_hits: info['keyspace_hits'].to_i,
          keyspace_misses: info['keyspace_misses'].to_i,
          hit_rate: calculate_hit_rate(info),
          pool_size: REDIS_POOL.size,
          pool_available: REDIS_POOL.available,
          uptime_seconds: info['uptime_in_seconds'].to_i
        }
      end
    rescue => e
      pool_size = begin
        REDIS_POOL.size
      rescue
        0
      end
      
      pool_available = begin
        REDIS_POOL.available
      rescue
        0
      end
      
      { 
        available: false, 
        error: e.message,
        pool_size: pool_size,
        pool_available: pool_available
      }
    end
    
    # Clear all keys matching pattern (use with caution!)
    # @param pattern [String] Redis key pattern (e.g., 'memes:*')
    # @return [Integer] Number of keys deleted
    def clear_pattern(pattern)
      return 0 unless redis_available?
      
      REDIS_POOL.with do |redis|
        keys = redis.keys(pattern)
        return 0 if keys.empty?
        
        redis.del(*keys)
        keys.size
      end
    rescue => e
      handle_error(e, operation: 'clear_pattern', pattern: pattern)
      0
    end
    
    # Ping Redis to check connectivity
    # @return [Boolean] True if ping successful
    def ping
      REDIS_POOL.with { |r| r.ping == 'PONG' }
    rescue
      false
    end
    
    # Get raw Redis connection for legacy code compatibility
    # Returns nil if Redis is unavailable
    # @return [Redis, nil] Redis connection or nil
    def connection
      return nil unless redis_available?
      
      # Return a connection that can be used directly
      # Note: For better patterns, use RedisService methods instead
      REDIS_POOL.checkout
    rescue => e
      handle_error(e, operation: 'connection')
      nil
    end
    
    private
    
    # Serialize value for Redis storage
    # @param value [Object] Value to serialize
    # @return [String] Serialized value
    def serialize_value(value)
      case value
      when String
        value
      when Integer, Float, TrueClass, FalseClass, NilClass
        value.to_s
      else
        value.to_json
      end
    end
    
    # Parse value from Redis
    # @param value [String] Value from Redis
    # @return [Object] Parsed value
    def parse_value(value)
      return nil if value.nil?
      
      # Try JSON parse first
      JSON.parse(value)
    rescue JSON::ParserError
      # Return as string if not JSON
      value
    end
    
    # Calculate Redis hit rate
    # @param info [Hash] Redis INFO response
    # @return [Float] Hit rate percentage
    def calculate_hit_rate(info)
      hits = info['keyspace_hits'].to_f
      misses = info['keyspace_misses'].to_f
      total = hits + misses
      
      return 0.0 if total.zero?
      ((hits / total) * 100).round(2)
    end
    
    # Handle Redis errors with logging and circuit breaker
    # @param error [Exception] The error that occurred
    # @param context [Hash] Additional context about the operation
    def handle_error(error, context = {})
      # Log error with context
      error_msg = "Redis error: #{error.class} - #{error.message}"
      error_msg += " (#{context.map { |k, v| "#{k}: #{v}" }.join(', ')})" if context.any?
      AppLogger.error("⚠️  #{error_msg}")
      
      # Send to error tracking if available
      if defined?(Sentry)
        Sentry.capture_exception(error, extra: context)
      end
      
      # Mark Redis as unavailable temporarily (circuit breaker pattern)
      # This prevents hammering Redis when it's down
      @redis_available = false
      @redis_check_time = Time.now
      
      # Schedule availability re-check after 30 seconds (named thread — intentional long-lived)
      @reconnect_thread = Thread.new do
        Thread.current.name = 'redis-reconnect'
        sleep 30
        refresh_availability!
        AppLogger.info("Redis availability re-checked", available: @redis_available)
      end
      @reconnect_thread.abort_on_exception = false
    end
  end
end
