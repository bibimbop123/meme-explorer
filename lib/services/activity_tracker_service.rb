# Activity Tracker Service
# Tracks real-time user activity for social proof and engagement
# Uses Redis for fast, real-time counters with proper visitor deduplication

class ActivityTrackerService
  ACTIVE_USER_TTL = 300 # 5 minutes - user considered active
  VIEWING_USER_TTL = 60 # 1 minute - user currently viewing
  PAGE_VIEW_DEDUP_TTL = 10 # 10 seconds - prevent rapid-fire duplicate page views
  
  class << self
    # Mark user as active
    # @param visitor_id [String] Persistent visitor identifier (session ID or user ID)
    # @param page [String] Page being viewed (optional)
    # @param ip_address [String] IP address for additional deduplication (optional)
    def mark_active(visitor_id, page: nil, ip_address: nil)
      return unless redis_available?
      
      timestamp = Time.now.to_i
      
      # Create composite key for better deduplication
      # Use visitor_id as primary, IP as backup fingerprint
      tracking_id = generate_tracking_id(visitor_id, ip_address)
      
      # Add to active users set with score = timestamp
      # ZADD with XX flag would update only if exists, but we want to add new ones too
      # The timestamp score ensures older entries get pruned automatically
      REDIS.zadd('active_users', timestamp, tracking_id)
      
      # Track page-specific activity if provided
      if page
        REDIS.zadd("active_users:#{page}", timestamp, tracking_id)
        REDIS.expire("active_users:#{page}", ACTIVE_USER_TTL)
      end
      
      # Only increment total page views if this visitor hasn't been counted recently
      # Use a separate deduplication key to prevent double-counting rapid clicks
      pageview_key = "pageview_dedup:#{tracking_id}"
      unless REDIS.exists(pageview_key)
        REDIS.incr('stats:total_page_views')
        REDIS.setex(pageview_key, PAGE_VIEW_DEDUP_TTL, '1')
      end
      
      true
    rescue => e
      puts "⚠️ [ACTIVITY TRACKER] Error marking active: #{e.message}"
      false
    end
    
    # Mark user as currently viewing a meme
    # @param visitor_id [String] Persistent visitor identifier
    # @param meme_url [String] Meme being viewed
    # @param ip_address [String] IP address for deduplication (optional)
    def mark_viewing(visitor_id, meme_url, ip_address: nil)
      return unless redis_available?
      
      timestamp = Time.now.to_i
      tracking_id = generate_tracking_id(visitor_id, ip_address)
      
      # Add to currently viewing set
      REDIS.zadd('viewing_users', timestamp, tracking_id)
      
      # Track specific meme viewers
      meme_key = "viewing:#{Digest::MD5.hexdigest(meme_url)}"
      REDIS.zadd(meme_key, timestamp, tracking_id)
      REDIS.expire(meme_key, VIEWING_USER_TTL)
      
      true
    rescue => e
      puts "⚠️ [ACTIVITY TRACKER] Error marking viewing: #{e.message}"
      false
    end
    
    # Get count of active users
    # @param page [String, nil] Specific page to check, or nil for global
    # @return [Integer] Number of active users
    def active_users_count(page: nil)
      return 0 unless redis_available?
      
      cutoff = Time.now.to_i - ACTIVE_USER_TTL
      key = page ? "active_users:#{page}" : 'active_users'
      
      # Remove expired entries
      REDIS.zremrangebyscore(key, 0, cutoff)
      
      # Count remaining
      REDIS.zcard(key).to_i
    rescue => e
      puts "⚠️ [ACTIVITY TRACKER] Error getting active count: #{e.message}"
      0
    end
    
    # Get count of users currently viewing memes
    # @return [Integer] Number of users viewing right now
    def viewing_users_count
      return 0 unless redis_available?
      
      cutoff = Time.now.to_i - VIEWING_USER_TTL
      
      # Remove expired
      REDIS.zremrangebyscore('viewing_users', 0, cutoff)
      
      # Count
      REDIS.zcard('viewing_users').to_i
    rescue => e
      puts "⚠️ [ACTIVITY TRACKER] Error getting viewing count: #{e.message}"
      0
    end
    
    # Get count of users viewing a specific meme
    # @param meme_url [String] Meme URL
    # @return [Integer] Number of users viewing this meme
    def meme_viewers_count(meme_url)
      return 0 unless redis_available?
      
      meme_key = "viewing:#{Digest::MD5.hexdigest(meme_url)}"
      cutoff = Time.now.to_i - VIEWING_USER_TTL
      
      REDIS.zremrangebyscore(meme_key, 0, cutoff)
      REDIS.zcard(meme_key).to_i
    rescue => e
      0
    end
    
    # Get comprehensive activity stats
    # @return [Hash] Activity statistics
    def stats
      return offline_stats unless redis_available?
      
      {
        active_users: active_users_count,
        viewing_users: viewing_users_count,
        total_page_views: REDIS.get('stats:total_page_views').to_i,
        active_on_random: active_users_count(page: 'random'),
        active_on_trending: active_users_count(page: 'trending'),
        active_on_profile: active_users_count(page: 'profile'),
        timestamp: Time.now.to_i
      }
    rescue => e
      puts "⚠️ [ACTIVITY TRACKER] Error getting stats: #{e.message}"
      offline_stats
    end
    
    # Record a specific action
    # @param action [String] Action name (like, save, share, etc.)
    # @param user_id [Integer, String] User performing action
    def record_action(action, user_id)
      return unless redis_available?
      
      # Increment action counter
      REDIS.incr("stats:action:#{action}")
      
      # Track user's action count
      REDIS.hincrby("user:#{user_id}:actions", action, 1)
      
      # Track hourly action for trending
      hour_key = Time.now.strftime('%Y%m%d%H')
      REDIS.zincrby("trending:actions:#{hour_key}", 1, action)
      REDIS.expire("trending:actions:#{hour_key}", 7200) # 2 hours
      
      true
    rescue => e
      puts "⚠️ [ACTIVITY TRACKER] Error recording action: #{e.message}"
      false
    end
    
    # Get trending actions in the last hour
    # @param limit [Integer] Number of top actions to return
    # @return [Array<Hash>] Top actions with counts
    def trending_actions(limit: 10)
      return [] unless redis_available?
      
      hour_key = Time.now.strftime('%Y%m%d%H')
      
      # Get top actions
      actions = REDIS.zrevrange("trending:actions:#{hour_key}", 0, limit - 1, with_scores: true)
      
      actions.map do |action, count|
        { action: action, count: count.to_i }
      end
    rescue => e
      []
    end
    
    # Clean up old tracking data (run periodically)
    def cleanup!
      return unless redis_available?
      
      cutoff = Time.now.to_i - ACTIVE_USER_TTL
      
      # Clean main sets
      REDIS.zremrangebyscore('active_users', 0, cutoff)
      REDIS.zremrangebyscore('viewing_users', 0, cutoff - VIEWING_USER_TTL)
      
      # Clean page-specific sets
      %w[random trending profile search].each do |page|
        REDIS.zremrangebyscore("active_users:#{page}", 0, cutoff)
      end
      
      puts "✅ [ACTIVITY TRACKER] Cleanup completed"
      true
    rescue => e
      puts "⚠️ [ACTIVITY TRACKER] Cleanup error: #{e.message}"
      false
    end
    
    private
    
    # Generate a stable tracking ID for visitor deduplication
    # @param visitor_id [String] Primary visitor identifier (session ID or user ID)
    # @param ip_address [String, nil] Optional IP address for fingerprinting
    # @return [String] Composite tracking identifier
    def generate_tracking_id(visitor_id, ip_address = nil)
      # Primary: Use visitor_id if it's not nil/empty
      return visitor_id.to_s if visitor_id && !visitor_id.to_s.empty?
      
      # Fallback: Use IP-based identifier
      if ip_address
        "ip:#{Digest::MD5.hexdigest(ip_address)}"
      else
        # Last resort: Use timestamp-based temp ID (not ideal but prevents crashes)
        "temp:#{Time.now.to_i}_#{rand(10000)}"
      end
    end
    
    def redis_available?
      RedisService.redis_available?
    end
    
    def offline_stats
      {
        active_users: 0,
        viewing_users: 0,
        total_page_views: 0,
        redis_available: false,
        timestamp: Time.now.to_i
      }
    end
  end
end
