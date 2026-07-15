# frozen_string_literal: true

# ============================================
# TRENDING MEMES CACHE HELPER
# ============================================
# Week 1 Day 4-5: Cache trending memes for 5 minutes
# Reduces load on database and improves response time

module TrendingCacheHelper
  TRENDING_CACHE_TTL = 5 * 60 # 5 minutes
  
  # Get trending memes with caching
  def self.get_trending(category: nil, limit: 50)
    cache_key = "trending:#{category || 'all'}:#{limit}"
    
    # Try Redis cache first
    cached = RedisService.get(cache_key)
    if cached
      return JSON.parse(cached)
    end
    
    # Fetch fresh data
    trending = fetch_trending_from_db(category: category, limit: limit)
    
    # Cache for 5 minutes
    RedisService.setex(cache_key, TRENDING_CACHE_TTL, trending.to_json)
    
    trending
  rescue => e
    AppLogger.warn("[TrendingCache] Cache error: #{e.message}, fetching directly")
    fetch_trending_from_db(category: category, limit: limit)
  end
  
  # Invalidate trending cache (call after new likes)
  def self.invalidate_cache(category: nil)
    pattern = category ? "trending:#{category}:*" : "trending:*"
    keys = RedisService.redis_pool.with { |conn| conn.keys(pattern) }
    
    keys.each do |key|
      RedisService.del(key)
    end
    
    AppLogger.info("[TrendingCache] Invalidated #{keys.length} cache keys")
  rescue => e
    AppLogger.warn("[TrendingCache] Failed to invalidate cache: #{e.message}")
  end
  
  private
  
  def self.fetch_trending_from_db(category:, limit:)
    query = DB[:meme_stats]
      .where(failure_count: 0..2)
      .order(Sequel.desc(:likes), Sequel.desc(:views))
      .limit(limit)
    
    query = query.where(subreddit: category) if category
    
    query.all
  end
end
