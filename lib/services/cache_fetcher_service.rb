# frozen_string_literal: true
# CacheFetcherService - Extracted from ApiCacheService
# Single Responsibility: Fetch from cache or API with TTL management
# Part of Phase 1 God Object Refactoring

require_relative '../../config/tuning_parameters'

class CacheFetcherService
  include TuningParameters

  def initialize(cache_manager: nil, redis: nil)
    @cache = cache_manager || CacheManager
    @redis = redis || RedisService
  end

  # Fetch data with cache-first strategy
  # @param key [String] Cache key
  # @param ttl [Integer] Time-to-live in seconds
  # @param block [Proc] Block to execute on cache miss
  # @return [Object] Cached or fresh data
  def fetch(key, ttl: CACHE_TTL_MEDIUM, &block)
    # Try cache first
    cached_data = @cache.get(key)
    return parse_cached_data(cached_data) if cached_data

    # Cache miss - fetch fresh data
    fresh_data = block.call
    store(key, fresh_data, ttl: ttl)
    fresh_data
  rescue => e
    AppLogger.error("CacheFetcherService fetch error", {
      key: key,
      error: e.message
    })
    block.call # Fallback to fresh data on error
  end

  # Store data in cache
  # @param key [String] Cache key
  # @param data [Object] Data to store
  # @param ttl [Integer] Time-to-live in seconds
  def store(key, data, ttl: CACHE_TTL_MEDIUM)
    serialized = serialize_data(data)
    @cache.set(key, serialized, ttl)
  end

  # Invalidate cache key
  # @param key [String] Cache key to invalidate
  def invalidate(key)
    @cache.delete(key)
  end

  # Invalidate multiple keys by pattern
  # @param pattern [String] Key pattern (e.g., "meme:*")
  def invalidate_pattern(pattern)
    keys = @redis.keys(pattern)
    keys.each { |key| invalidate(key) }
  end

  # Check if key exists in cache
  # @param key [String] Cache key
  # @return [Boolean]
  def exists?(key)
    @cache.get(key) != nil
  end

  # Get TTL for key
  # @param key [String] Cache key
  # @return [Integer, nil] TTL in seconds or nil
  def ttl(key)
    @redis.ttl(key)
  end

  private

  def parse_cached_data(data)
    return data if data.is_a?(Hash) || data.is_a?(Array)
    JSON.parse(data)
  rescue JSON::ParserError
    data
  end

  def serialize_data(data)
    return data if data.is_a?(String)
    data.to_json
  end
end
