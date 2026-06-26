# frozen_string_literal: true

# Centralized Cache Key Management
# Provides consistent cache key generation and invalidation patterns
# Senior Dev Pattern: Centralize cache key logic, add versioning

module CacheKeys
  # Cache version - increment to invalidate all caches
  VERSION = 'v2'
  
  # TTL Constants (in seconds)
  TTL_SHORT = 300        # 5 minutes - volatile data
  TTL_MEDIUM = 1800      # 30 minutes - semi-stable data
  TTL_LONG = 3600        # 1 hour - stable data
  TTL_VERY_LONG = 86400  # 24 hours - rarely changing data
  
  # ====== MEME CACHE KEYS ======
  
  def self.meme(id)
    "#{VERSION}:meme:#{id}"
  end
  
  def self.meme_stats(url)
    "#{VERSION}:meme:stats:#{url}"
  end
  
  def self.meme_pool
    "#{VERSION}:meme:pool"
  end
  
  def self.meme_pool_metadata
    "#{VERSION}:meme:pool:metadata"
  end
  
  def self.similar_memes(meme_id)
    "#{VERSION}:meme:#{meme_id}:similar"
  end
  
  # ====== USER CACHE KEYS ======
  
  def self.user_profile(user_id)
    "#{VERSION}:user:#{user_id}:profile"
  end
  
  def self.user_stats(user_id)
    "#{VERSION}:user:#{user_id}:stats"
  end
  
  def self.user_preferences(user_id)
    "#{VERSION}:user:#{user_id}:preferences"
  end
  
  def self.user_saved_memes(user_id)
    "#{VERSION}:user:#{user_id}:saved"
  end
  
  def self.user_taste_profile(user_id)
    "#{VERSION}:user:#{user_id}:taste_profile"
  end
  
  # ====== LEADERBOARD CACHE KEYS ======
  
  def self.leaderboard(type, period = 'weekly')
    "#{VERSION}:leaderboard:#{type}:#{period}"
  end
  
  def self.leaderboard_user_rank(user_id, type)
    "#{VERSION}:leaderboard:#{type}:user:#{user_id}:rank"
  end
  
  # ====== TRENDING CACHE KEYS ======
  
  def self.trending_memes(timeframe = '24h')
    "#{VERSION}:trending:#{timeframe}"
  end
  
  def self.trending_subreddits
    "#{VERSION}:trending:subreddits"
  end
  
  # ====== SEARCH CACHE KEYS ======
  
  def self.search_results(query, filters = {})
    filter_hash = Digest::MD5.hexdigest(filters.to_json)
    "#{VERSION}:search:#{query}:#{filter_hash}"
  end
  
  # ====== COLLECTION CACHE KEYS ======
  
  def self.collection(collection_id)
    "#{VERSION}:collection:#{collection_id}"
  end
  
  def self.collection_memes(collection_id)
    "#{VERSION}:collection:#{collection_id}:memes"
  end
  
  # ====== INVALIDATION HELPERS ======
  
  # Invalidate all cache keys for a specific user
  def self.invalidate_user(user_id)
    return unless defined?(RedisService)
    
    patterns = [
      "#{VERSION}:user:#{user_id}:*",
      "#{VERSION}:leaderboard:*:user:#{user_id}:*"
    ]
    
    patterns.each do |pattern|
      RedisService.delete_pattern(pattern)
    end
    
    AppLogger.info('cache_invalidation', {
      type: 'user',
      user_id: user_id,
      patterns: patterns
    })
  end
  
  # Invalidate meme-related caches
  def self.invalidate_meme(meme_id)
    return unless defined?(RedisService)
    
    keys_to_delete = [
      meme(meme_id),
      similar_memes(meme_id)
    ]
    
    keys_to_delete.each { |key| RedisService.delete(key) }
    
    # Also invalidate pool cache as meme stats changed
    RedisService.delete(meme_pool)
    
    AppLogger.info('cache_invalidation', {
      type: 'meme',
      meme_id: meme_id
    })
  end
  
  # Invalidate leaderboard caches
  def self.invalidate_leaderboard(type = nil)
    return unless defined?(RedisService)
    
    pattern = type ? "#{VERSION}:leaderboard:#{type}:*" : "#{VERSION}:leaderboard:*"
    RedisService.delete_pattern(pattern)
    
    AppLogger.info('cache_invalidation', {
      type: 'leaderboard',
      leaderboard_type: type || 'all'
    })
  end
  
  # Invalidate trending caches
  def self.invalidate_trending
    return unless defined?(RedisService)
    
    RedisService.delete_pattern("#{VERSION}:trending:*")
    
    AppLogger.info('cache_invalidation', {
      type: 'trending'
    })
  end
  
  # Invalidate search caches (typically on meme updates)
  def self.invalidate_search
    return unless defined?(RedisService)
    
    RedisService.delete_pattern("#{VERSION}:search:*")
    
    AppLogger.info('cache_invalidation', {
      type: 'search'
    })
  end
  
  # Nuclear option: invalidate everything
  def self.invalidate_all
    return unless defined?(RedisService)
    
    RedisService.delete_pattern("#{VERSION}:*")
    
    AppLogger.warn('cache_invalidation', {
      type: 'all',
      message: 'All caches invalidated'
    })
  end
  
  # ====== CACHE WARMING HELPERS ======
  
  # Check if a cache key exists
  def self.exists?(key)
    return false unless defined?(RedisService)
    RedisService.exists?(key)
  end
  
  # Get TTL for a key
  def self.ttl(key)
    return nil unless defined?(RedisService)
    RedisService.ttl(key)
  end
  
  # Get cache statistics
  def self.stats
    return {} unless defined?(RedisService)
    
    {
      version: VERSION,
      total_keys: RedisService.keys("#{VERSION}:*").count,
      meme_keys: RedisService.keys("#{VERSION}:meme:*").count,
      user_keys: RedisService.keys("#{VERSION}:user:*").count,
      leaderboard_keys: RedisService.keys("#{VERSION}:leaderboard:*").count,
      trending_keys: RedisService.keys("#{VERSION}:trending:*").count,
      search_keys: RedisService.keys("#{VERSION}:search:*").count
    }
  end
end
