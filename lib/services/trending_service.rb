# lib/services/trending_service.rb
# P2 OPTIMIZATION: Move sorting to database layer

module TrendingService
  extend self
  
  # Calculate trending score in SQL, not Ruby
  def get_trending_memes(limit: 50, time_window_hours: 24)
    cutoff_time = Time.now - (time_window_hours * 3600)
    
    # OPTIMIZED: Scoring done in SQL with proper indexes
    query = <<~SQL
      SELECT 
        url,
        title,
        subreddit,
        views,
        likes,
        created_at,
        updated_at,
        -- Trending score: likes * 2 + views, with time decay
        (likes * 2.0 + views) * 
        EXP(-0.05 * EXTRACT(EPOCH FROM (CURRENT_TIMESTAMP - updated_at)) / 3600.0) AS trending_score
      FROM meme_stats
      WHERE updated_at >= $1
        AND views > 0
      ORDER BY trending_score DESC, updated_at DESC
      LIMIT $2
    SQL
    
    DB_POOL.with do |conn|
      conn.exec_params(query, [cutoff_time, limit])
        .map { |row| row.transform_keys(&:to_sym) }
    end
  rescue => e
    AppLogger.error("Trending query failed", error: e.message, backtrace: e.backtrace.first(3))
    []
  end
  
  # Get trending by category with SQL aggregation
  def get_trending_by_category(category, limit: 30)
    query = <<~SQL
      SELECT 
        m.*,
        (m.likes * 2.0 + m.views) * 
        EXP(-0.05 * EXTRACT(EPOCH FROM (CURRENT_TIMESTAMP - m.updated_at)) / 3600.0) AS score
      FROM meme_stats m
      WHERE m.subreddit = $1
        AND m.updated_at >= CURRENT_TIMESTAMP - INTERVAL '48 hours'
      ORDER BY score DESC
      LIMIT $2
    SQL
    
    DB_POOL.with do |conn|
      conn.exec_params(query, [category, limit])
        .map { |row| row.transform_keys(&:to_sym) }
    end
  rescue => e
    AppLogger.warn("Category trending failed", category: category, error: e.message)
    []
  end
  
  # Aggregate stats at database level
  def get_aggregate_stats
    query = <<~SQL
      SELECT 
        COUNT(DISTINCT url) as total_memes,
        SUM(views) as total_views,
        SUM(likes) as total_likes,
        AVG(likes::float / NULLIF(views, 0)) as avg_like_rate,
        COUNT(DISTINCT subreddit) as total_subreddits
      FROM meme_stats
      WHERE updated_at >= CURRENT_TIMESTAMP - INTERVAL '7 days'
    SQL
    
    DB_POOL.with do |conn|
      result = conn.exec(query)
      result[0] if result.ntuples > 0
    end
  rescue => e
    AppLogger.error("Stats aggregation failed", error: e.message)
    {}
  end
  
  # Cache trending results with proper TTL
  def cached_trending(time_window: 24, cache_ttl: 300)
    cache_key = "trending:#{time_window}h"
    
    cached = RedisService.get(cache_key) rescue nil
    return JSON.parse(cached) if cached
    
    trending = get_trending_memes(time_window_hours: time_window)
    RedisService.setex(cache_key, cache_ttl, trending.to_json) rescue nil
    
    trending
  end
end
