# Cache Strategy Concern
# Improved caching patterns with TTL and invalidation
# Generated: May 19, 2026

module CacheStrategy
  # Cache with automatic TTL
  def cache_with_ttl(key, ttl: 3600, &block)
    cached = MEME_CACHE.get(key)
    
    if cached && !cache_expired?(key, ttl)
      return cached
    end
    
    result = yield
    MEME_CACHE.set(key, result)
    MEME_CACHE.set("#{key}:timestamp", Time.now.to_i)
    result
  end
  
  # Check if cache entry is expired
  def cache_expired?(key, ttl)
    timestamp = MEME_CACHE.get("#{key}:timestamp")
    return true unless timestamp
    
    (Time.now.to_i - timestamp) > ttl
  end
  
  # Smart cache for meme pool with refresh logic
  def get_or_refresh_meme_pool(force_refresh: false)
    cache_key = :memes
    timestamp_key = :last_refresh
    
    if force_refresh || should_refresh_meme_pool?
      refresh_meme_pool
    end
    
    MEME_CACHE.get(cache_key) || []
  end
  
  # Check if meme pool needs refresh
  def should_refresh_meme_pool?
    last_refresh = MEME_CACHE.get(:last_refresh)
    return true unless last_refresh
    
    pool = MEME_CACHE.get(:memes)
    return true unless pool
    return true if pool.size < AppConstants::Health::MIN_MEME_POOL_SIZE
    
    age_minutes = (Time.now - last_refresh) / 60
    age_minutes > AppConstants::Health::CACHE_STALE_THRESHOLD_MINUTES
  end
  
  # Refresh meme pool (move to background job in production)
  def refresh_meme_pool
    # This should be called from a Sidekiq job
    # For now, returns quickly to avoid blocking
    return if ENV['SKIP_POOL_REFRESH'] == 'true'
    
    MEME_CACHE.set(:refreshing, true)
    MEME_CACHE.set(:last_refresh, Time.now)
    
    # Actual refresh happens in background
    nil
  end
  
  # Cache user-specific data with user_id namespace
  def cache_user_data(user_id, key, ttl: 1800, &block)
    cache_key = "user:#{user_id}:#{key}"
    cache_with_ttl(cache_key, ttl: ttl, &block)
  end
  
  # Invalidate user cache
  def invalidate_user_cache(user_id, key = nil)
    if key
      MEME_CACHE.delete("user:#{user_id}:#{key}")
      MEME_CACHE.delete("user:#{user_id}:#{key}:timestamp")
    else
      # Invalidate all user caches (requires cache iteration)
      # Better to use specific keys when possible
      MEME_CACHE.delete("user:#{user_id}:profile")
      MEME_CACHE.delete("user:#{user_id}:stats")
      MEME_CACHE.delete("user:#{user_id}:saved_memes")
    end
  end
  
  # Cache trending data with smart invalidation
  def cache_trending(period: 'week', limit: 20, &block)
    cache_key = "trending:#{period}:#{limit}"
    ttl = case period
          when 'day' then 300    # 5 minutes
          when 'week' then 900   # 15 minutes
          when 'month' then 1800 # 30 minutes
          else 900
          end
    
    cache_with_ttl(cache_key, ttl: ttl, &block)
  end
  
  # Multi-get cache pattern for batch operations
  def cache_multi_get(keys)
    keys.map { |key| [key, MEME_CACHE.get(key)] }.to_h
  end
  
  # Multi-set cache pattern for batch operations
  def cache_multi_set(key_value_pairs, ttl: 3600)
    timestamp = Time.now.to_i
    
    key_value_pairs.each do |key, value|
      MEME_CACHE.set(key, value)
      MEME_CACHE.set("#{key}:timestamp", timestamp)
    end
  end
  
  # Fragment caching for rendered content
  def cache_fragment(fragment_key, ttl: 3600, &block)
    cached_html = MEME_CACHE.get("fragment:#{fragment_key}")
    
    if cached_html && !cache_expired?("fragment:#{fragment_key}", ttl)
      return cached_html
    end
    
    html = yield
    MEME_CACHE.set("fragment:#{fragment_key}", html)
    MEME_CACHE.set("fragment:#{fragment_key}:timestamp", Time.now.to_i)
    html
  end
  
  # Cache statistics
  def cache_stats
    {
      size: (MEME_CACHE.size rescue 0),
      meme_pool_size: (MEME_CACHE.get(:memes)&.size || 0),
      last_refresh: MEME_CACHE.get(:last_refresh),
      refreshing: (MEME_CACHE.get(:refreshing) || false)
    }
  end
end
