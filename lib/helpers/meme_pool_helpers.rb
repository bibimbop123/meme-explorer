# frozen_string_literal: true

# MemePoolHelpers - Extracted from app.rb Phase 3
# Handles meme pool generation, distribution, and user preference application
module MemePoolHelpers
  # Get intelligent pool with mixed distribution (70% trending, 20% fresh, 10% exploration)
  def get_intelligent_pool(user_id = nil, limit = 100)
    # 70% Trending, 20% Fresh, 10% Exploration
    trending = get_trending_pool(limit * 0.7)
    fresh = get_fresh_pool(limit * 0.2, 48)
    exploration = get_exploration_pool(limit * 0.1)
    
    pool = trending + fresh + exploration
    pool = pool.uniq { |m| m["url"] }
    
    # CRITICAL FIX: If DB is empty, fallback to local memes
    if pool.empty?
      local_memes = begin
        if MEMES.is_a?(Hash)
          MEMES.values.flatten.compact.map do |m|
            # Convert file paths: remove leading / so File.join works correctly
            m_copy = m.dup
            if m_copy["file"] && m_copy["file"].start_with?("/")
              m_copy["file"] = m_copy["file"][1..-1]  # Remove leading slash
            end
            m_copy
          end
        elsif MEMES.is_a?(Array)
          MEMES.map do |m|
            m_copy = m.dup
            if m_copy["file"] && m_copy["file"].start_with?("/")
              m_copy["file"] = m_copy["file"][1..-1]
            end
            m_copy
          end
        else
          []
        end
      rescue
        []
      end
      pool = local_memes
    end
    
    # Apply user preferences if logged in
    if user_id
      apply_user_preferences(pool, user_id)
    else
      pool.shuffle
    end
  end

  # Apply user preferences - boost preferred subreddits
  def apply_user_preferences(pool, user_id)
    user_prefs = DB.execute(
      "SELECT subreddit, preference_score FROM user_subreddit_preferences WHERE user_id = ? ORDER BY preference_score DESC",
      [user_id]
    )
    
    return pool.shuffle if user_prefs.empty?
    
    # Separate memes by preference
    preferred = []
    neutral = []
    
    pool.each do |meme|
      sub = meme["subreddit"]&.downcase
      pref = user_prefs.find { |p| p["subreddit"].downcase == sub }
      if pref && pref["preference_score"] > 1.0
        preferred << meme
      else
        neutral << meme
      end
    end
    
    # Return 60% preferred + 40% neutral for variety
    ratio = (preferred.size * 0.6 / [preferred.size, 1].max).to_i
    (preferred.sample(ratio) + neutral.sample((pool.size - ratio))).compact.shuffle
  end

  # Get time-based pool distribution for personalization
  def get_time_based_pools(user_id = nil, limit = 100)
    hour = Time.now.hour
    
    if (9..11).include?(hour) || (18..21).include?(hour)
      # Peak hours: 80% trending, 15% fresh, 5% exploration
      ratios = { trending: 0.8, fresh: 0.15, exploration: 0.05 }
    elsif (0..6).include?(hour)
      # Off-hours: 60% trending, 30% fresh, 10% exploration
      ratios = { trending: 0.6, fresh: 0.3, exploration: 0.1 }
    else
      # Normal hours: 70% trending, 20% fresh, 10% exploration
      ratios = { trending: 0.7, fresh: 0.2, exploration: 0.1 }
    end
    
    trending = get_trending_pool((limit * ratios[:trending]).to_i)
    fresh = get_fresh_pool((limit * ratios[:fresh]).to_i, 48)
    exploration = get_exploration_pool((limit * ratios[:exploration]).to_i)
    
    pool = (trending + fresh + exploration).uniq { |m| m["url"] }
    
    user_id ? apply_user_preferences(pool, user_id) : pool.shuffle
  end

  # Get trending memes based on engagement score
  def get_trending_pool(limit = 50)
    result = DB.execute(
      "SELECT *, (likes * 2 + views) AS score 
       FROM meme_stats 
       WHERE failure_count IS NULL OR failure_count < 2 
       ORDER BY score DESC 
       LIMIT ?",
      [limit]
    ) rescue []
    result || []
  end

  # Get fresh memes from recent hours
  def get_fresh_pool(limit = 30, hours_ago = 24)
    result = DB.execute(
      "SELECT * FROM meme_stats WHERE updated_at > datetime('now', '-#{hours_ago} hours') AND (failure_count IS NULL OR failure_count < 2) ORDER BY updated_at DESC LIMIT ?",
      [limit]
    ) rescue []
    result || []
  end

  # Get random exploration memes
  def get_exploration_pool(limit = 20)
    result = DB.execute(
      "SELECT * FROM meme_stats WHERE failure_count IS NULL OR failure_count < 2 ORDER BY RANDOM() LIMIT ?",
      [limit]
    ) rescue []
    result || []
  end

  # Get meme pool - NOW USING 5,000-MEME INTELLIGENT POOL (Phase 2)
  # Uses MemePoolManager with tier-based distribution and quality filtering
  def random_memes_pool
    # Try new 5,000-meme intelligent pool first
    begin
      require_relative '../services/meme_pool_manager'
      
      pool_result = MemePoolManager.get_pool
      
      if pool_result[:success] && pool_result[:memes]&.any?
        puts "✅ [POOL] Using MemePoolManager: #{pool_result[:pool_size]} memes (tier-distributed)"
        return pool_result[:memes]
      else
        puts "⚠️  [POOL] MemePoolManager not ready: #{pool_result[:error]}"
      end
    rescue => e
      puts "⚠️  [POOL] MemePoolManager error: #{e.message}"
    end
    
    # Fallback to old cache system (backward compatible)
    cache_memes = MEME_CACHE.get(:memes)
    if cache_memes.is_a?(Array) && !cache_memes.empty?
      valid_memes = cache_memes.select { |m| has_valid_media?(m) }
      AppLogger.info("[POOL FALLBACK] Using legacy cache: #{valid_memes.size} memes")
      return valid_memes unless valid_memes.empty?
    end

    # Cache is empty — fetch directly from Reddit via OAuth (no Sidekiq needed)
    # This ensures memes load immediately in development without running workers
    begin
      if defined?(InlineRedditFetcher)
        AppLogger.info("[POOL] Cache empty — fetching from Reddit via OAuth...")
        subreddits = defined?(POPULAR_SUBREDDITS) ? POPULAR_SUBREDDITS.first(15) : ['funny', 'memes', 'dankmemes', 'AdviceAnimals', 'me_irl', 'wholesome', 'therewasanattempt', 'facepalm', 'tifu', 'HolUp']
        fresh_memes = InlineRedditFetcher.fetch(subreddits, limit: 25)
        if fresh_memes.any?
          MEME_CACHE.set(:memes, fresh_memes)
          MEME_CACHE.set(:last_refresh, Time.now)
          AppLogger.info("[POOL] Fetched and cached #{fresh_memes.size} memes from Reddit")
          return fresh_memes
        end
      end
    rescue => e
      AppLogger.warn("[POOL] On-demand Reddit fetch failed", error: e.message)
    end

    # Last resort: local memes
    local_memes = begin
      if MEMES.is_a?(Hash)
        MEMES.values.flatten.compact
      elsif MEMES.is_a?(Array)
        MEMES
      else
        []
      end
    rescue
      []
    end
    
    valid_local_memes = local_memes.select { |m| has_valid_media?(m) }
    puts "✅ [POOL FALLBACK] Using local memes: #{valid_local_memes.size} memes"
    valid_local_memes
  end
end
