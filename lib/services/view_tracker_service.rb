# frozen_string_literal: true

# View Tracker Service
# Enterprise-grade meme view tracking with proper deduplication,
# atomic operations, and multi-layer fallback.
#
# Design Principles:
# 1. Single Source of Truth: Database is canonical, Redis is cache
# 2. Visitor Fingerprinting: Stable IDs prevent inflation
# 3. Smart Deduplication: Time + visitor-based windows
# 4. Atomic Operations: ACID guarantees for PostgreSQL, proper locking for SQLite
# 5. Graceful Degradation: Works without Redis, handles DB failures
#
# @author Senior Ruby Developer
# @created June 6, 2026

class ViewTrackerService
  # Deduplication windows (in seconds)
  MEME_VIEW_WINDOW = 300        # 5 minutes - same meme from same visitor
  GLOBAL_VIEW_WINDOW = 10       # 10 seconds - any view from same visitor (bot protection)
  
  # Redis key TTLs
  REDIS_DEDUP_TTL = 600         # 10 minutes - keep dedup keys
  REDIS_VIEW_CACHE_TTL = 3600   # 1 hour - cache view counts
  
  class << self
    # Track a meme view with comprehensive deduplication
    #
    # @param meme_url [String] The meme URL or file path
    # @param visitor_id [String] Stable visitor identifier (session ID or user ID)
    # @param ip_address [String, nil] IP address for fingerprinting
    # @param user_id [Integer, nil] User ID if logged in
    # @param meme_metadata [Hash] Additional meme info (title, subreddit, etc.)
    # @return [Hash] Result with :counted boolean and :view_count
    def track_view(meme_url, visitor_id, ip_address: nil, user_id: nil, meme_metadata: {})
      return failure_result('Missing meme_url') unless meme_url
      return failure_result('Missing visitor_id') unless visitor_id
      
      # Generate stable fingerprint
      fingerprint = generate_fingerprint(visitor_id, ip_address)
      
      # Check deduplication
      if recently_viewed?(meme_url, fingerprint)
        return {
          counted: false,
          view_count: get_view_count(meme_url),
          reason: 'duplicate',
          dedup_window: MEME_VIEW_WINDOW
        }
      end
      
      # Record the view
      view_count = record_view_atomically(meme_url, meme_metadata)
      
      # Mark as viewed for deduplication
      mark_viewed(meme_url, fingerprint)
      
      # Track in Redis metrics (non-blocking)
      track_redis_metrics(meme_url, user_id, meme_metadata) if redis_available?
      
      # Log activity (for analytics)
      log_view_activity(meme_url, user_id, visitor_id) if db_available?
      
      {
        counted: true,
        view_count: view_count,
        fingerprint: fingerprint,
        timestamp: Time.now.to_i
      }
    rescue => e
      log_error("View tracking failed", e, meme_url: meme_url)
      failure_result("Error: #{e.message}")
    end
    
    # Get accurate view count for a meme
    # Uses Redis cache with DB fallback
    #
    # @param meme_url [String] The meme URL
    # @return [Integer] View count
    def get_view_count(meme_url)
      return 0 unless meme_url
      
      # Try Redis cache first (fast)
      if redis_available?
        cached = REDIS.get("view_count:#{cache_key(meme_url)}")
        return cached.to_i if cached
      end
      
      # Fallback to database (canonical source)
      count = get_db_view_count(meme_url)
      
      # Update cache
      cache_view_count(meme_url, count) if redis_available?
      
      count
    rescue => e
      log_error("Get view count failed", e, meme_url: meme_url)
      0
    end
    
    # Get comprehensive view statistics for a meme
    #
    # @param meme_url [String] The meme URL
    # @return [Hash] Statistics including views, unique viewers, trends
    def get_stats(meme_url)
      return {} unless meme_url
      
      {
        total_views: get_view_count(meme_url),
        unique_viewers: get_unique_viewers_count(meme_url),
        views_last_hour: get_recent_views(meme_url, 3600),
        views_last_day: get_recent_views(meme_url, 86400),
        first_seen: get_first_seen(meme_url),
        last_viewed: get_last_viewed(meme_url)
      }
    rescue => e
      log_error("Get stats failed", e, meme_url: meme_url)
      {}
    end
    
    # Bulk increment views (for migrations or batch operations)
    # Uses database transactions for atomicity
    #
    # @param view_data [Array<Hash>] Array of {meme_url:, count:} hashes
    # @return [Boolean] Success status
    def bulk_increment(view_data)
      return false unless view_data.is_a?(Array) && !view_data.empty?
      
      DB.transaction do
        view_data.each do |data|
          meme_url = data[:meme_url] || data['meme_url']
          count = (data[:count] || data['count'] || 1).to_i
          
          DB.execute(
            "INSERT INTO meme_stats (url, title, subreddit, views, likes, created_at, updated_at)
             VALUES (?, ?, ?, ?, 0, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
             ON CONFLICT(url) DO UPDATE SET 
               views = views + ?,
               updated_at = CURRENT_TIMESTAMP",
            [meme_url, 'Unknown', 'unknown', count, count]
          )
        end
      end
      
      true
    rescue => e
      log_error("Bulk increment failed", e)
      false
    end
    
    private
    
    # Generate stable visitor fingerprint
    # Combines visitor_id + IP for stronger deduplication
    def generate_fingerprint(visitor_id, ip_address)
      if visitor_id && !visitor_id.to_s.empty?
        # Primary: Use visitor ID (session-based or user ID)
        base = "vid:#{visitor_id}"
      elsif ip_address
        # Fallback: Use IP hash
        base = "ip:#{Digest::MD5.hexdigest(ip_address)}"
      else
        # Last resort: Timestamp + random (weak but prevents crashes)
        base = "temp:#{Time.now.to_i}_#{rand(100000)}"
      end
      
      # Add IP salt if available (prevents session hijacking inflation)
      if ip_address && visitor_id
        "#{base}+#{Digest::MD5.hexdigest(ip_address)[0..7]}"
      else
        base
      end
    end
    
    # Check if meme was recently viewed by this visitor
    def recently_viewed?(meme_url, fingerprint)
      return false unless redis_available?
      
      # Check meme-specific dedup
      meme_key = "viewed:#{cache_key(meme_url)}:#{fingerprint}"
      return true if REDIS.exists(meme_key)
      
      # Check global dedup (bot protection)
      global_key = "viewer:#{fingerprint}:active"
      REDIS.exists(global_key)
    rescue => e
      log_error("Dedup check failed", e)
      false # Fail open - allow view if check fails
    end
    
    # Mark meme as viewed by visitor
    def mark_viewed(meme_url, fingerprint)
      return unless redis_available?
      
      # Mark specific meme
      meme_key = "viewed:#{cache_key(meme_url)}:#{fingerprint}"
      REDIS.setex(meme_key, MEME_VIEW_WINDOW, '1')
      
      # Mark global activity (shorter window for bot protection)
      global_key = "viewer:#{fingerprint}:active"
      REDIS.setex(global_key, GLOBAL_VIEW_WINDOW, '1')
      
      true
    rescue => e
      log_error("Mark viewed failed", e)
      false
    end
    
    # Record view in database with atomic increment
    # Returns updated view count
    def record_view_atomically(meme_url, metadata)
      title = metadata[:title] || metadata['title'] || 'Unknown'
      subreddit = metadata[:subreddit] || metadata['subreddit'] || 'unknown'
      
      # Atomic UPSERT — PostgreSQL only (SQLite branch removed, app is PG-only)
      record_view_postgres(meme_url, title, subreddit)
    end

    # Atomic view recording with PostgreSQL UPSERT
    def record_view_postgres(meme_url, title, subreddit)
      result = DB.execute(
        "INSERT INTO meme_stats (url, title, subreddit, views, likes, created_at, updated_at)
         VALUES (?, ?, ?, 1, 0, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
         ON CONFLICT(url) DO UPDATE SET
           views      = meme_stats.views + 1,
           updated_at = CURRENT_TIMESTAMP
         RETURNING views",
        [meme_url, title, subreddit]
      ).first

      result ? result['views'].to_i : 1
    end
    
    # Track in Redis for real-time metrics
    def track_redis_metrics(meme_url, user_id, metadata)
      subreddit = metadata[:subreddit] || metadata['subreddit']
      
      REDIS.pipelined do |pipe|
        # Global counters
        pipe.incr('metrics:meme_views:total')
        pipe.incr("metrics:meme_views:daily:#{Date.today}")
        pipe.incr("metrics:meme_views:hourly:#{Time.now.strftime('%Y-%m-%d:%H')}")
        
        # Per-meme counter
        pipe.hincrby('metrics:meme_views:by_url', meme_url, 1)
        
        # Per-user counter
        pipe.hincrby('metrics:meme_views:by_user', user_id, 1) if user_id
        
        # Per-subreddit counter
        pipe.hincrby('metrics:meme_views:by_subreddit', subreddit, 1) if subreddit
        
        # Set TTLs
        pipe.expire("metrics:meme_views:daily:#{Date.today}", 2_592_000) # 30 days
        pipe.expire("metrics:meme_views:hourly:#{Time.now.strftime('%Y-%m-%d:%H')}", 86_400) # 1 day
      end
      
      # Update cached view count
      cache_key_name = "view_count:#{cache_key(meme_url)}"
      REDIS.incr(cache_key_name)
      REDIS.expire(cache_key_name, REDIS_VIEW_CACHE_TTL)
      
      true
    rescue => e
      log_error("Redis metrics tracking failed", e)
      false
    end
    
    # Log view activity for analytics
    def log_view_activity(meme_url, user_id, session_id)
      DB.execute(
        "INSERT INTO meme_activity_log (meme_url, activity_type, user_id, session_id, created_at)
         VALUES (?, 'view', ?, ?, CURRENT_TIMESTAMP)",
        [meme_url, user_id, session_id]
      )
    rescue => e
      # Fail silently if activity log table doesn't exist
      log_error("Activity log failed", e) unless e.message =~ /no such table/
    end
    
    # Get view count from database
    def get_db_view_count(meme_url)
      result = DB.execute(
        "SELECT views FROM meme_stats WHERE url = ?",
        [meme_url]
      ).first
      
      result ? result['views'].to_i : 0
    end
    
    # Cache view count in Redis
    def cache_view_count(meme_url, count)
      key = "view_count:#{cache_key(meme_url)}"
      REDIS.setex(key, REDIS_VIEW_CACHE_TTL, count)
    rescue => e
      log_error("Cache update failed", e)
    end
    
    # Get unique viewers count
    def get_unique_viewers_count(meme_url)
      # Try Redis HyperLogLog for approximation
      if redis_available?
        key = "unique_viewers:#{cache_key(meme_url)}"
        count = REDIS.pfcount(key)
        return count if count > 0
      end
      
      # Fallback: estimate from views (rough approximation)
      (get_view_count(meme_url) * 0.7).to_i # Assume 70% unique
    rescue => e
      log_error("Unique viewers count failed", e)
      0
    end
    
    # Get recent views count
    def get_recent_views(meme_url, seconds_ago)
      return 0 unless db_available?
      
      cutoff = Time.now - seconds_ago
      result = DB.execute(
        "SELECT COUNT(*) as count FROM meme_activity_log 
         WHERE meme_url = ? AND activity_type = 'view' AND created_at > ?",
        [meme_url, cutoff]
      ).first
      
      result ? result['count'].to_i : 0
    rescue => e
      0 # Table may not exist
    end
    
    # Get first seen timestamp
    def get_first_seen(meme_url)
      result = DB.execute(
        "SELECT created_at FROM meme_stats WHERE url = ?",
        [meme_url]
      ).first
      
      result ? result['created_at'] : nil
    rescue => e
      nil
    end
    
    # Get last viewed timestamp
    def get_last_viewed(meme_url)
      result = DB.execute(
        "SELECT updated_at FROM meme_stats WHERE url = ?",
        [meme_url]
      ).first
      
      result ? result['updated_at'] : nil
    rescue => e
      nil
    end
    
    # Generate cache key for meme URL
    def cache_key(meme_url)
      Digest::MD5.hexdigest(meme_url)
    end
    
    # Always PostgreSQL in production
    def postgresql?
      true
    end
    
    # Check if Redis is available
    def redis_available?
      defined?(REDIS) && RedisService.redis_available?
    rescue
      false
    end
    
    # Check if database is available
    def db_available?
      defined?(DB) && DB.respond_to?(:execute)
    rescue
      false
    end
    
    # Create failure result hash
    def failure_result(reason)
      {
        counted: false,
        view_count: 0,
        reason: reason
      }
    end
    
    # Log errors with context
    def log_error(message, error, context = {})
      error_msg = "ViewTrackerService: #{message} - #{error.class}: #{error.message}"
      puts "❌ #{error_msg}"
      puts "   Context: #{context.inspect}" unless context.empty?
      puts "   Backtrace: #{error.backtrace.first(3).join("\n   ")}" if error.respond_to?(:backtrace)
      
      AppLogger.error(message, error: error.message, context: context) if defined?(AppLogger)
    rescue
      # Fail silently if logging fails
    end
  end
end
