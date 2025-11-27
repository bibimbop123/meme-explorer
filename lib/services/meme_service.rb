# Service for managing meme operations
# Extracted from monolithic app.rb to improve code organization and testability

class MemeService
  def initialize(cache, db, redis, memes_yaml)
    @cache = cache
    @db = db
    @redis = redis
    @memes = memes_yaml
  end

  # Get meme pool from cache or build fresh - prioritizes API memes with local fallback
  def random_memes_pool(popular_subreddits, fetch_method)
    # Use cached pool if fresh (less than 2 minutes old)
    if @cache[:memes].is_a?(Array) && !@cache[:memes].empty? &&
       @cache[:last_refresh] && (Time.now - @cache[:last_refresh]) < 120
      return @cache[:memes]
    end

    # Always load local memes as guaranteed fallback
    local_memes = begin
      if @memes.is_a?(Hash)
        @memes.values.flatten.compact
      elsif @memes.is_a?(Array)
        @memes
      else
        []
      end
    rescue
      []
    end

    # Fetch fresh API memes first (primary source)
    api_memes = fetch_method.call(popular_subreddits, 200) rescue []
    
    # Combine: prefer API memes but always include local as fallback
    pool = api_memes + local_memes
    pool = pool.uniq { |m| m["url"] || m["file"] }

    # Validate memes - be lenient, accept if either file exists or URL is valid
    validated = pool.select do |m| 
      next true if m["file"] && File.exist?(File.join("public", m["file"]))
      next true if m["url"] && m["url"].match?(/^https?:\/\//)
      false
    end

    # If validation filtered everything, use local memes without strict validation as last resort
    if validated.empty? && !local_memes.empty?
      validated = local_memes
    end

    # Normalize file paths: remove leading / so File.join works correctly
    normalized = validated.map do |m|
      m_copy = m.dup
      if m_copy["file"] && m_copy["file"].start_with?("/")
        m_copy["file"] = m_copy["file"][1..-1]  # Remove leading slash
      end
      m_copy
    end

    @cache[:memes] = normalized.shuffle
    @cache[:last_refresh] = Time.now

    normalized
  end

  # Get likes safely
  def get_meme_likes(url)
    return 0 unless url
    likes = @redis&.get("meme:likes:#{url}")&.to_i
    return likes if likes

    row = @db.execute("SELECT likes FROM meme_stats WHERE url = ?", url).first
    likes = row ? row["likes"].to_i : 0
    @redis&.set("meme:likes:#{url}", likes)
    likes
  end

  # Smart Hybrid Search: Cache → API (if needed) → DB/YAML Fallback
  def search_memes(query, cache_memes, popular_subreddits, fetch_method, db)
    return [] unless query
    query_lower = query.downcase.strip
    return [] if query_lower.empty?
    
    # Tier 1: Search in-memory cache (instant, fresh Reddit memes)
    cache_results = (cache_memes || []).select do |m|
      (m["title"]&.downcase&.include?(query_lower) ||
       m["subreddit"]&.downcase&.include?(query_lower))
    end
    
    # Tier 2: If too few results, hit API for niche queries
    if cache_results.size < 3
      api_results = (fetch_method.call(popular_subreddits, 30) rescue []).select do |m|
        m["title"]&.downcase&.include?(query_lower) ||
        m["subreddit"]&.downcase&.include?(query_lower)
      end
      cache_results = (cache_results + api_results).uniq { |m| m["url"] }
    end
    
    # Tier 3: Fall back to DB + YAML if still empty
    if cache_results.empty?
      db_results = (db.execute("SELECT * FROM meme_stats WHERE title LIKE ? COLLATE NOCASE", ["%#{query_lower}%"]) rescue []).map { |r| r.transform_keys(&:to_s) }
      yaml_results = flatten_memes.select { |m| m["title"]&.downcase&.include?(query_lower) }
      cache_results = (db_results + yaml_results).uniq { |m| m["url"] || m["file"] }
    end
    
    # Rank results: exact match > title match > subreddit match, then by engagement
    ranked = cache_results.sort_by do |m|
      title = m["title"]&.downcase || ""
      subreddit = m["subreddit"]&.downcase || ""
      likes = m["likes"].to_i
      views = m["views"].to_i
      
      exact_match = title == query_lower ? 0 : 1
      title_match = title.include?(query_lower) ? 0 : 1
      subreddit_match = subreddit.include?(query_lower) ? 2 : 3
      engagement = -(likes * 2 + views) # Negative to sort descending
      
      [exact_match, title_match, subreddit_match, engagement]
    end
    
    ranked
  end

  # Flatten memes from YAML structure
  def flatten_memes
    return [] unless @memes.is_a?(Hash)
    @memes.values.flatten.compact
  end

  def self.toggle_like(url, liked_now, session, db = nil)
    db ||= defined?(DB) ? ::DB : nil
    return 0 unless db && url
    
    begin
      db.execute("CREATE TABLE IF NOT EXISTS meme_stats (url TEXT PRIMARY KEY, likes INTEGER DEFAULT 0, views INTEGER DEFAULT 0, created_at DATETIME DEFAULT CURRENT_TIMESTAMP, updated_at DATETIME DEFAULT CURRENT_TIMESTAMP)")
      
      # Ensure the record exists before updating
      db.execute("INSERT OR IGNORE INTO meme_stats (url, likes, views) VALUES (?, 0, 0)", [url])
      
      if liked_now
        db.execute("UPDATE meme_stats SET likes = likes + 1 WHERE url = ?", [url])
      else
        db.execute("UPDATE meme_stats SET likes = CASE WHEN likes > 0 THEN likes - 1 ELSE 0 END WHERE url = ?", [url])
      end
      
      get_likes(url, db)
    rescue => e
      0
    end
  end

  def self.get_likes(url, db = nil)
    db ||= defined?(DB) ? ::DB : nil
    return 0 unless db && url
    
    begin
      db.execute("CREATE TABLE IF NOT EXISTS meme_stats (url TEXT PRIMARY KEY, likes INTEGER DEFAULT 0, views INTEGER DEFAULT 0, created_at DATETIME DEFAULT CURRENT_TIMESTAMP, updated_at DATETIME DEFAULT CURRENT_TIMESTAMP)")
      result = db.execute("SELECT likes FROM meme_stats WHERE url = ?", [url]).first
      result ? result["likes"].to_i : 0
    rescue => e
      0
    end
  end
end
