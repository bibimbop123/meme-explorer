# Search Service - Secured with Input Validation
# Handles meme searching and ranking with security hardening

require_relative '../validators'

class SearchService
  def self.search(query, meme_cache, popular_subreddits)
    # Validate and sanitize query FIRST
    begin
      query = Validators.validate_search_query(query, min_length: 1, max_length: 200)
    rescue Validators::ValidationError => e
      return { success: false, error: e.message, results: [] }
    end
    
    query_lower = query.downcase.strip
    return { success: true, results: [], query: query } if query_lower.empty?
    
    # Tier 1: Search in-memory cache (instant, fresh Reddit memes)
    cache_results = (meme_cache || []).select do |m|
      (m["title"]&.downcase&.include?(query_lower) ||
       m["subreddit"]&.downcase&.include?(query_lower))
    end
    
    # Tier 2: If too few results, hit API for niche queries
    if cache_results.size < 3
      api_results = begin
        MemeService.fetch_reddit_memes(popular_subreddits, 30).select do |m|
          m["title"]&.downcase&.include?(query_lower) ||
          m["subreddit"]&.downcase&.include?(query_lower)
        end
      rescue
        []
      end
      cache_results = (cache_results + api_results).uniq { |m| m["url"] }
    end
    
    # Tier 3: Fall back to DB + YAML if still empty
    if cache_results.empty?
      db_results = begin
        DB.execute(
          "SELECT * FROM meme_stats WHERE title LIKE ? COLLATE NOCASE",
          ["%#{query_lower}%"]
        ).map { |r| r.transform_keys(&:to_s) }
      rescue
        []
      end
      yaml_results = flatten_memes.select { |m| m["title"]&.downcase&.include?(query_lower) }
      cache_results = (db_results + yaml_results).uniq { |m| m["url"] || m["file"] }
    end
    
    # Rank results
    ranked = rank_results(cache_results, query_lower)
    
    { success: true, results: ranked, query: query, total: ranked.size }
  end

  private

  def self.rank_results(results, query_lower)
    results.sort_by do |m|
      title = m["title"]&.downcase || ""
      subreddit = m["subreddit"]&.downcase || ""
      likes = m["likes"].to_i
      views = m["views"].to_i
      
      exact_match = title == query_lower ? 0 : 1
      title_match = title.include?(query_lower) ? 0 : 1
      subreddit_match = subreddit.include?(query_lower) ? 2 : 3
      engagement = -(likes * 2 + views)
      
      [exact_match, title_match, subreddit_match, engagement]
    end
  end

  def self.flatten_memes
    memes = YAML.load_file("data/memes.yml") rescue {}
    return [] unless memes.is_a?(Hash)
    memes.values.flatten.compact
  end
end
