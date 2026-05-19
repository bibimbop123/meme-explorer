# Query Optimizer Concern
# Prevents N+1 queries and provides efficient batch loading
# Generated: May 19, 2026

module QueryOptimizer
  # Batch load meme stats to prevent N+1 queries
  def batch_load_meme_stats(meme_urls)
    return {} if meme_urls.empty?
    
    placeholders = meme_urls.map { '?' }.join(',')
    query = "SELECT * FROM meme_stats WHERE url IN (#{placeholders})"
    
    stats = DB.execute(query, meme_urls)
    
    # Index by URL for O(1) lookup
    stats.each_with_object({}) do |stat, hash|
      hash[stat["url"]] = stat
    end
  end
  
  # Batch load user meme stats to prevent N+1
  def batch_load_user_meme_stats(user_id, meme_urls)
    return {} if meme_urls.empty? || user_id.nil?
    
    placeholders = meme_urls.map { '?' }.join(',')
    query = "SELECT * FROM user_meme_stats 
             WHERE user_id = ? AND meme_url IN (#{placeholders})"
    
    stats = DB.execute(query, [user_id, *meme_urls])
    
    stats.each_with_object({}) do |stat, hash|
      hash[stat["meme_url"]] = stat
    end
  end
  
  # Efficient counter updates using batch operations
  def batch_increment_views(meme_urls)
    return if meme_urls.empty?
    
    DB.transaction do
      meme_urls.each_slice(50) do |batch|
        placeholders = batch.map { '?' }.join(',')
        DB.execute(
          "UPDATE meme_stats SET views = views + 1, updated_at = ? 
           WHERE url IN (#{placeholders})",
          [Time.now, *batch]
        )
      end
    end
  end
  
  # Batch upsert for meme stats (insert or update)
  def batch_upsert_meme_stats(memes_data)
    return if memes_data.empty?
    
    DB.transaction do
      memes_data.each do |data|
        DB.execute(
          "INSERT INTO meme_stats (url, title, subreddit, likes, views, created_at, updated_at)
           VALUES (?, ?, ?, ?, 0, ?, ?)
           ON CONFLICT(url) DO UPDATE SET
             title = excluded.title,
             likes = excluded.likes,
             updated_at = excluded.updated_at",
          [data[:url], data[:title], data[:subreddit], data[:likes], 
           Time.now, Time.now]
        )
      end
    end
  end
  
  # Get trending memes with efficient single query
  def get_trending_memes_optimized(limit: 20, time_period: 'week')
    hours_ago = case time_period
                when 'day' then 24
                when 'week' then 168
                when 'month' then 720
                else 168
                end
    
    query = "
      SELECT url, title, subreddit, likes, views,
             (likes * 0.7 + views * 0.3) as engagement_score
      FROM meme_stats
      WHERE updated_at >= datetime('now', '-#{hours_ago} hours')
        AND failure_count IS NULL OR failure_count < 3
      ORDER BY engagement_score DESC
      LIMIT ?
    "
    
    DB.execute(query, [limit])
  end
  
  # Efficient meme search with full-text if available
  def search_memes_optimized(query, limit: 20)
    sanitized_query = query.to_s.strip.downcase
    return [] if sanitized_query.empty?
    
    # Use LIKE with index-friendly pattern
    DB.execute(
      "SELECT DISTINCT url, title, subreddit, likes, views
       FROM meme_stats
       WHERE LOWER(title) LIKE ? OR LOWER(subreddit) LIKE ?
       ORDER BY likes DESC, views DESC
       LIMIT ?",
      ["%#{sanitized_query}%", "%#{sanitized_query}%", limit]
    )
  end
  
  # Get user activity summary with single query
  def get_user_activity_summary(user_id)
    query = "
      SELECT 
        COUNT(CASE WHEN liked = 1 THEN 1 END) as total_likes,
        COUNT(DISTINCT meme_url) as unique_memes_seen,
        MAX(updated_at) as last_activity
      FROM user_meme_stats
      WHERE user_id = ?
    "
    
    DB.execute(query, [user_id]).first || {}
  end
  
  # Preload associations for a collection of memes
  def preload_meme_associations(memes, user_id: nil)
    return memes if memes.empty?
    
    meme_urls = memes.map { |m| m["url"] || m[:url] }.compact
    
    # Batch load all stats
    stats_map = batch_load_meme_stats(meme_urls)
    user_stats_map = user_id ? batch_load_user_meme_stats(user_id, meme_urls) : {}
    
    # Attach stats to memes
    memes.each do |meme|
      url = meme["url"] || meme[:url]
      meme["stats"] = stats_map[url]
      meme["user_stats"] = user_stats_map[url] if user_id
    end
    
    memes
  end
end
