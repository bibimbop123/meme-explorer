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
        if MemeExplorer::App::MEMES.is_a?(Hash)
          MemeExplorer::App::MEMES.values.flatten.compact.map do |m|
            # Convert file paths: remove leading / so File.join works correctly
            m_copy = m.dup
            if m_copy["file"] && m_copy["file"].start_with?("/")
              m_copy["file"] = m_copy["file"][1..-1]  # Remove leading slash
            end
            m_copy
          end
        elsif MemeExplorer::App::MEMES.is_a?(Array)
          MemeExplorer::App::MEMES.map do |m|
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
    
    # Return up to 60% preferred + remainder neutral for variety.
    # (Previous formula `preferred.size * 0.6 / preferred.size` always
    # simplified to 0, so personalization never actually boosted
    # preferred subreddits — users never saw more of what they liked.)
    desired_preferred = (pool.size * 0.6).to_i
    ratio = [desired_preferred, preferred.size].min
    neutral_count = [pool.size - ratio, neutral.size].min
    (preferred.sample(ratio) + neutral.sample(neutral_count)).compact.shuffle
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

  # Get random exploration memes.
  #
  # NOTE: This previously used `ORDER BY RANDOM()`, which forces SQLite to
  # assign a random value to and sort *every* qualifying row on every call.
  # That's an O(n log n) full-table-scan-and-sort that gets progressively
  # more expensive as meme_stats grows, and this pool is rebuilt on the hot
  # /random path. Instead, we grab a bounded candidate window (cheap, uses
  # the primary key / any index on id) and shuffle it in Ruby — same
  # "explore something different" feel for users, without the DB cost.
  def get_exploration_pool(limit = 20)
    candidate_window = [limit * 10, 500].min

    # Pick a random starting point across the id range so exploration
    # surfaces content from anywhere in the table (not just the newest
    # rows), while still only ever fetching/sorting a bounded window —
    # far cheaper than `ORDER BY RANDOM()` over the whole table.
    max_id_row = DB.execute("SELECT MAX(id) AS max_id FROM meme_stats").first rescue nil
    max_id = max_id_row ? (max_id_row["max_id"] || max_id_row["MAX(id)"]).to_i : 0
    random_start = max_id > 0 ? rand(0..max_id) : 0

    candidates = DB.execute(
      "SELECT * FROM meme_stats WHERE id >= ? AND (failure_count IS NULL OR failure_count < 2) ORDER BY id ASC LIMIT ?",
      [random_start, candidate_window]
    ) rescue []

    candidates = [] if candidates.nil?

    # If the random window landed near the end of the table and came up
    # short, wrap around and fill from the start.
    if candidates.size < limit
      remaining = limit - candidates.size
      seen_ids = candidates.map { |m| m["id"] }
      wrap = DB.execute(
        "SELECT * FROM meme_stats WHERE (failure_count IS NULL OR failure_count < 2) ORDER BY id ASC LIMIT ?",
        [candidate_window]
      ) rescue []
      candidates += (wrap || []).reject { |m| seen_ids.include?(m["id"]) }.first(remaining)
    end

    candidates.sample(limit)
  end

  # Get meme pool - NOW USING 5,000-MEME INTELLIGENT POOL (Phase 2)
  # Uses MemePoolManager with tier-based distribution and quality filtering
  def random_memes_pool
    # Try new 5,000-meme intelligent pool first
    begin
      require_relative '../services/meme_pool_manager'
      
      pool_result = MemePoolManager.get_pool
      
      if pool_result[:success] && pool_result[:memes]&.any?
        AppLogger.info("✅ [POOL] Using MemePoolManager: #{pool_result[:pool_size]} memes (tier-distributed)")
        return pool_result[:memes]
      else
        AppLogger.error("⚠️  [POOL] MemePoolManager not ready: #{pool_result[:error]}")
      end
    rescue => e
      AppLogger.error("⚠️  [POOL] MemePoolManager error: #{e.message}")
    end
    
    # Fallback to old cache system (backward compatible)
    cache_memes = MemeExplorer::App::MEME_CACHE.get(:memes)
    if cache_memes.is_a?(Array) && !cache_memes.empty?
      valid_memes = cache_memes.select { |m| has_valid_media?(m) }
      AppLogger.info("[POOL FALLBACK] Using legacy cache: #{valid_memes.size} memes")
      return valid_memes unless valid_memes.empty?
    end

    # BUG FIX (Aug 25, 2026, round 3): This on-demand inline fetch used to
    # fire unconditionally on EVERY request that reached this point, with
    # zero rate-limit awareness of its own. In production this meant every
    # single incoming request independently launched its own synchronous
    # Reddit fetch, all from the same server/IP within seconds of each
    # other - Reddit's rate limiter (429) responds almost instantly, far
    # faster than a real timeout, which is exactly why these requests kept
    # completing in ~300ms with "0 memes" and no visible exception (a 429
    # isn't an exception; fetch_static/fetch_authenticated just silently
    # return no results). This also piled additional concurrent Reddit
    # calls on top of MemePoolManager's own coordinated background
    # bootstrap, from the same IP, making Reddit more likely to rate-limit
    # the whole server.
    #
    # ROUND 3 FOLLOW-UP: peeking at MemePoolManager's own bootstrap lock
    # from here turned out to be an unreliable signal - that lock is only
    # held for as long as bootstrap_pool's rate-limit probe takes, which
    # can be well under a second when Reddit is already rate-limiting us,
    # so nearly every other request's check simply missed the tiny window
    # where the lock existed. Instead, this on-demand path now owns and
    # respects its OWN dedicated cooldown key: the moment it discovers
    # Reddit is rate-limiting it, it sets a cooldown so every subsequent
    # request skips the fetch entirely (falling straight to the fast local
    # pool) until the cooldown expires - no racing against another
    # subsystem's transient lock required.
    on_demand_cooldown_key = "meme_pool:on_demand_fetch_cooldown"
    on_demand_cooldown_ttl = 60 # seconds - short enough to retry soon after Reddit calms down

    if RedisService.get(on_demand_cooldown_key)
      AppLogger.info("[POOL] Cache empty, but on-demand fetch is cooling down after a recent rate limit - skipping")
    else
      begin
        if defined?(InlineRedditFetcher)
          AppLogger.info("[POOL] Cache empty — fetching from Reddit via OAuth...")
          subreddits = defined?(POPULAR_SUBREDDITS) ? POPULAR_SUBREDDITS.first(15) : ['funny', 'memes', 'dankmemes', 'AdviceAnimals', 'me_irl', 'wholesome', 'therewasanattempt', 'facepalm', 'tifu', 'HolUp']
          fresh_memes = InlineRedditFetcher.fetch(subreddits, limit: 25)
          if fresh_memes.any?
            MemeExplorer::App::MEME_CACHE.set(:memes, fresh_memes)
            MemeExplorer::App::MEME_CACHE.set(:last_refresh, Time.now)
            AppLogger.info("[POOL] Fetched and cached #{fresh_memes.size} memes from Reddit")
            return fresh_memes
          else
            AppLogger.warn("[POOL] On-demand Reddit fetch returned zero memes (likely rate-limited) - cooling down for #{on_demand_cooldown_ttl}s")
            RedisService.set(on_demand_cooldown_key, "true", ttl: on_demand_cooldown_ttl)
          end
        end
      rescue => e
        AppLogger.warn("[POOL] On-demand Reddit fetch failed", error: e.message)
        RedisService.set(on_demand_cooldown_key, "true", ttl: on_demand_cooldown_ttl)
      end
    end

    # Last resort: local memes
    local_memes = begin
      if MemeExplorer::App::MEMES.is_a?(Hash)
        MemeExplorer::App::MEMES.values.flatten.compact
      elsif MemeExplorer::App::MEMES.is_a?(Array)
        MemeExplorer::App::MEMES
      else
        []
      end
    rescue
      []
    end
    
    valid_local_memes = local_memes.select { |m| has_valid_media?(m) }
    AppLogger.info("✅ [POOL FALLBACK] Using local memes: #{valid_local_memes.size} memes")
    valid_local_memes
  end
end
