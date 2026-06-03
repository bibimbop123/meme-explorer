# frozen_string_literal: true

require_relative '../app_logger'

# Metrics Tracker Service
# Tracks business metrics and application performance
# Week 2 Implementation - June 3, 2026

class MetricsTrackerService
  class << self
    # Track meme view
    def track_meme_view(meme_url, user_id: nil, subreddit: nil)
      REDIS_POOL.with do |r|
        # Global metrics
        r.incr('metrics:meme_views:total')
        r.incr("metrics:meme_views:daily:#{Date.today}")
        r.incr("metrics:meme_views:hourly:#{Time.now.strftime('%Y-%m-%d:%H')}")
        
        # Per-meme metrics
        r.hincrby('metrics:meme_views:by_url', meme_url, 1) if meme_url
        
        # Per-user metrics
        r.hincrby('metrics:meme_views:by_user', user_id, 1) if user_id
        
        # Per-subreddit metrics
        r.hincrby('metrics:meme_views:by_subreddit', subreddit, 1) if subreddit
        
        # Set expiration for daily/hourly keys (keep 30 days)
        r.expire("metrics:meme_views:daily:#{Date.today}", 2_592_000)  # 30 days
        r.expire("metrics:meme_views:hourly:#{Time.now.strftime('%Y-%m-%d:%H')}", 86_400)  # 1 day
      end
      
      AppLogger.info("Meme viewed", 
        meme_url: meme_url, 
        user_id: user_id, 
        subreddit: subreddit
      )
    rescue => e
      AppLogger.error("Failed to track meme view", 
        error: e.message, 
        meme_url: meme_url
      )
    end
    
    # Track like
    def track_like(meme_url, user_id, subreddit: nil)
      REDIS_POOL.with do |r|
        r.incr('metrics:likes:total')
        r.incr("metrics:likes:daily:#{Date.today}")
        r.hincrby('metrics:likes:by_subreddit', subreddit, 1) if subreddit
        
        r.expire("metrics:likes:daily:#{Date.today}", 2_592_000)
      end
      
      AppLogger.info("Meme liked", 
        meme_url: meme_url, 
        user_id: user_id,
        subreddit: subreddit
      )
    rescue => e
      AppLogger.error("Failed to track like", 
        error: e.message, 
        meme_url: meme_url
      )
    end
    
    # Track user signup
    def track_signup(user_id, method: 'email')
      REDIS_POOL.with do |r|
        r.incr('metrics:signups:total')
        r.incr("metrics:signups:daily:#{Date.today}")
        r.hincrby('metrics:signups:by_method', method, 1)
        
        r.expire("metrics:signups:daily:#{Date.today}", 2_592_000)
      end
      
      AppLogger.info("User signed up", 
        user_id: user_id, 
        method: method
      )
    rescue => e
      AppLogger.error("Failed to track signup", 
        error: e.message, 
        user_id: user_id
      )
    end
    
    # Track error
    def track_error(error_class, status_code, path: nil)
      REDIS_POOL.with do |r|
        # Increment error counters
        r.incr('metrics:errors:total')
        r.incr("metrics:errors:daily:#{Date.today}")
        r.incr("metrics:errors:5m:#{Time.now.to_i / 300}")  # 5-minute window
        r.hincrby('metrics:errors:by_class', error_class, 1)
        r.hincrby('metrics:errors:by_status', status_code, 1)
        r.hincrby('metrics:errors:by_path', path, 1) if path
        
        # Set expiration
        r.expire("metrics:errors:daily:#{Date.today}", 2_592_000)
        r.expire("metrics:errors:5m:#{Time.now.to_i / 300}", 600)  # 10 minutes
      end
    rescue => e
      # Don't log here to avoid infinite loop
      puts "Failed to track error metric: #{e.message}"
    end
    
    # Track request
    def track_request(method, path, status_code, duration_ms)
      REDIS_POOL.with do |r|
        # Request counters
        r.incr('metrics:requests:total')
        r.incr("metrics:requests:5m:#{Time.now.to_i / 300}")
        r.hincrby('metrics:requests:by_status', status_code, 1)
        
        # Performance tracking (simplified)
        r.lpush("metrics:performance:#{path}", duration_ms)
        r.ltrim("metrics:performance:#{path}", 0, 99)  # Keep last 100
        
        # Set expiration
        r.expire("metrics:requests:5m:#{Time.now.to_i / 300}", 600)
      end
    rescue => e
      # Silent failure for metrics
    end
    
    # Get daily metrics
    def get_daily_metrics(date = Date.today)
      REDIS_POOL.with do |r|
        {
          views: r.get("metrics:meme_views:daily:#{date}")&.to_i || 0,
          likes: r.get("metrics:likes:daily:#{date}")&.to_i || 0,
          signups: r.get("metrics:signups:daily:#{date}")&.to_i || 0,
          errors: r.get("metrics:errors:daily:#{date}")&.to_i || 0
        }
      end
    rescue => e
      AppLogger.error("Failed to get daily metrics", error: e.message)
      { views: 0, likes: 0, signups: 0, errors: 0 }
    end
    
    # Get error rate (last 5 minutes)
    def get_error_rate
      current_window = Time.now.to_i / 300
      
      REDIS_POOL.with do |r|
        error_count = r.get("metrics:errors:5m:#{current_window}")&.to_i || 0
        request_count = r.get("metrics:requests:5m:#{current_window}")&.to_i || 1
        
        (error_count.to_f / request_count * 100).round(2)
      end
    rescue => e
      AppLogger.error("Failed to get error rate", error: e.message)
      0.0
    end
    
    # Get top subreddits by views
    def get_top_subreddits(limit = 10)
      REDIS_POOL.with do |r|
        r.hgetall('metrics:meme_views:by_subreddit')
          .sort_by { |_, count| -count.to_i }
          .first(limit)
          .to_h
      end
    rescue => e
      AppLogger.error("Failed to get top subreddits", error: e.message)
      {}
    end
  end
end
