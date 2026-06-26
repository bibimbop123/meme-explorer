# lib/helpers/search_optimization_helpers.rb
# P2: Add relevance scoring to search results

module SearchOptimizationHelpers
  # Search with relevance scoring (PostgreSQL specific)
  def search_memes_with_relevance(query, limit: 100)
    sanitized = sanitize_search_query(query)
    
    sql = <<~SQL
      SELECT 
        url,
        title,
        subreddit,
        views,
        likes,
        created_at,
        -- Relevance scoring: exact matches score higher
        CASE 
          WHEN LOWER(title) = LOWER($1) THEN 100
          WHEN LOWER(title) LIKE LOWER($1) || '%' THEN 90
          WHEN LOWER(title) LIKE '%' || LOWER($1) || '%' THEN 80
          ELSE 70
        END +
        -- Boost popular memes
        (likes * 0.1 + views * 0.01) AS relevance_score
      FROM meme_stats
      WHERE LOWER(title) LIKE '%' || LOWER($1) || '%'
      ORDER BY relevance_score DESC, updated_at DESC
      LIMIT $2
    SQL
    
    DB_POOL.with do |conn|
      conn.exec_params(sql, [sanitized, limit])
        .map { |row| row.transform_keys(&:to_sym) }
    end
  rescue => e
    AppLogger.error("Search with relevance failed", query: query, error: e.message)
    fallback_search(query, limit)
  end
  
  # Fallback to simple search if relevance scoring fails
  def fallback_search(query, limit)
    sql = "SELECT * FROM meme_stats WHERE LOWER(title) LIKE '%' || LOWER($1) || '%' LIMIT $2"
    
    DB_POOL.with do |conn|
      conn.exec_params(sql, [sanitize_search_query(query), limit])
        .map { |row| row.transform_keys(&:to_sym) }
    end
  rescue => e
    AppLogger.error("Fallback search failed", error: e.message)
    []
  end
  
  # Sanitize search query to prevent SQL injection and ReDoS
  def sanitize_search_query(query)
    return "" if query.nil?
    
    # Remove null bytes and control characters
    cleaned = query.to_s.gsub(/[\x00-\x1F\x7F]/, '').strip
    
    # Limit length to prevent ReDoS
    cleaned = cleaned[0...200] if cleaned.length > 200
    
    # Remove dangerous patterns
    cleaned.gsub(/[%_\\]/, '') # Remove SQL LIKE wildcards
  end
end
