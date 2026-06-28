# Analytics Service - Phase 1
# Comprehensive dashboard metrics for infinite variety monitoring
# Created: June 3, 2026

class AnalyticsService
  class << self
    # Get all dashboard metrics in one call
    def get_dashboard_metrics
      {
        content_health: content_health_metrics,
        user_engagement: user_engagement_metrics,
        algorithm_performance: algorithm_performance_metrics,
        phase_1_targets: phase_1_target_metrics
      }
    rescue => e
      log_error("Get dashboard metrics error", e)
      { error: e.message }
    end
    
    private
    
    # Content Health Metrics
    def content_health_metrics
      {
        total_memes_in_pool: get_pool_size,
        fresh_memes_24h: count_fresh_memes(24),
        quality_score_avg: average_quality_score,
        broken_image_rate: broken_image_rate,
        subreddit_count: count_active_subreddits,
        unique_sources: count_unique_sources
      }
    rescue => e
      log_error("Content health metrics error", e)
      {}
    end
    
    # User Engagement Metrics
    def user_engagement_metrics
      {
        dau: count_daily_active_users,
        like_rate: calculate_like_rate,
        avg_session_duration: calculate_avg_session_duration,
        total_likes_24h: count_likes_24h,
        total_views_24h: count_views_24h
      }
    rescue => e
      log_error("User engagement metrics error", e)
      {}
    end
    
    # Algorithm Performance Metrics
    def algorithm_performance_metrics
      {
        variety_score: calculate_variety_score,
        quality_pipeline_pass_rate: quality_pass_rate,
        cache_hit_rate: cache_hit_rate,
        avg_response_time: avg_response_time
      }
    rescue => e
      log_error("Algorithm performance metrics error", e)
      {}
    end
    
    # Phase 1 Target Metrics
    def phase_1_target_metrics
      pool_size = get_pool_size
      subreddit_count = count_active_subreddits
      quality_avg = average_quality_score
      
      {
        pool_target: 2000,
        pool_actual: pool_size,
        pool_progress: ((pool_size.to_f / 2000) * 100).round(1),
        
        subreddit_target: 300,
        subreddit_actual: subreddit_count,
        subreddit_progress: ((subreddit_count.to_f / 300) * 100).round(1),
        
        quality_target: 80.0,
        quality_actual: quality_avg,
        quality_progress: ((quality_avg.to_f / 80.0) * 100).round(1)
      }
    rescue => e
      log_error("Phase 1 metrics error", e)
      {}
    end
    
    # Helper methods
    
    def get_pool_size
      if defined?(RedisService)
        cached = RedisService.get('meme_pool:count')
        return cached.to_i if cached
      end
      
      # Count from meme cache
      if defined?(MemeExplorer::App::MEME_CACHE)
        memes = MemeExplorer::App::MEME_CACHE[:memes] || []
        return memes.size
      end
      
      0
    rescue => e
      log_error("Get pool size error", e)
      0
    end
    
    def count_fresh_memes(hours)
      return 0 unless defined?(DB)
      
      cutoff = Time.now - (hours * 3600)
      result = DB.execute(
        "SELECT COUNT(*) as count FROM meme_stats WHERE created_at >= ?",
        [cutoff]
      ).first
      
      result ? result['count'].to_i : 0
    rescue => e
      log_error("Count fresh memes error", e)
      0
    end
    
    def average_quality_score
      return 0.0 unless defined?(DB)
      
      result = DB.execute(
        "SELECT AVG(quality_score) as avg FROM meme_stats WHERE quality_score > 0"
      ).first
      
      result && result['avg'] ? result['avg'].to_f.round(2) : 0.0
    rescue => e
      log_error("Average quality score error", e)
      0.0
    end
    
    def broken_image_rate
      return 0.0 unless defined?(DB)
      
      total = DB.execute("SELECT COUNT(*) as count FROM meme_stats").first
      broken = DB.execute("SELECT COUNT(*) as count FROM meme_stats WHERE failure_count >= 3").first
      
      return 0.0 unless total && broken
      return 0.0 if total['count'].to_i == 0
      
      ((broken['count'].to_f / total['count'].to_f) * 100).round(2)
    rescue => e
      log_error("Broken image rate error", e)
      0.0
    end
    
    def count_active_subreddits
      subreddits = YAML.load_file('data/subreddits.yml', aliases: true)
      popular = subreddits['popular'] || []
      popular.size
    rescue => e
      log_error("Count active subreddits error", e)
      0
    end
    
    def count_unique_sources
      return 0 unless defined?(DB)
      
      result = DB.execute(
        "SELECT COUNT(DISTINCT subreddit) as count FROM meme_stats"
      ).first
      
      result ? result['count'].to_i : 0
    rescue => e
      log_error("Count unique sources error", e)
      0
    end
    
    def count_daily_active_users
      return 0 unless defined?(DB)
      
      cutoff = Time.now - 86400 # 24 hours
      result = DB.execute(
        "SELECT COUNT(DISTINCT user_id) as count FROM user_activity WHERE created_at >= ?",
        [cutoff]
      ).first
      
      result ? result['count'].to_i : 0
    rescue => e
      0
    end
    
    def calculate_like_rate
      return 0.0 unless defined?(DB)
      
      cutoff = Time.now - 86400
      stats = DB.execute(
        "SELECT SUM(likes) as total_likes, SUM(views) as total_views 
         FROM meme_stats WHERE updated_at >= ?",
        [cutoff]
      ).first
      
      return 0.0 unless stats && stats['total_views'].to_i > 0
      
      ((stats['total_likes'].to_f / stats['total_views'].to_f) * 100).round(2)
    rescue => e
      0.0
    end
    
    def calculate_avg_session_duration
      return 0 unless defined?(DB)
      
      result = DB.execute(
        "SELECT AVG(duration) as avg FROM user_sessions WHERE updated_at >= datetime('now', '-24 hours')"
      ).first
      
      result && result['avg'] ? result['avg'].to_f.round(0) : 0
    rescue => e
      0
    end
    
    def count_likes_24h
      return 0 unless defined?(DB)
      
      cutoff = Time.now - 86400
      result = DB.execute(
        "SELECT SUM(likes) as total FROM meme_stats WHERE updated_at >= ?",
        [cutoff]
      ).first
      
      result ? result['total'].to_i : 0
    rescue => e
      0
    end
    
    def count_views_24h
      return 0 unless defined?(DB)
      
      cutoff = Time.now - 86400
      result = DB.execute(
        "SELECT SUM(views) as total FROM meme_stats WHERE updated_at >= ?",
        [cutoff]
      ).first
      
      result ? result['total'].to_i : 0
    rescue => e
      0
    end
    
    def calculate_variety_score
      unique_subreddits = count_unique_sources
      total_subreddits = count_active_subreddits
      
      return 0.0 if total_subreddits == 0
      
      ((unique_subreddits.to_f / total_subreddits.to_f) * 100).round(2)
    rescue => e
      0.0
    end
    
    def quality_pass_rate
      return 0.0 unless defined?(DB)
      
      total = DB.execute("SELECT COUNT(*) as count FROM meme_stats").first
      passing = DB.execute("SELECT COUNT(*) as count FROM meme_stats WHERE quality_score >= 80").first
      
      return 0.0 unless total && passing
      return 0.0 if total['count'].to_i == 0
      
      ((passing['count'].to_f / total['count'].to_f) * 100).round(2)
    rescue => e
      0.0
    end
    
    def cache_hit_rate
      if defined?(RedisService)
        hits = RedisService.get('metrics:cache_hits').to_i
        misses = RedisService.get('metrics:cache_misses').to_i
        total = hits + misses
        
        return 0.0 if total == 0
        return ((hits.to_f / total.to_f) * 100).round(2)
      end
      
      0.0
    rescue => e
      0.0
    end
    
    def avg_response_time
      if defined?(RedisService)
        total_time = RedisService.get('metrics:total_response_time').to_f
        total_requests = RedisService.get('metrics:total_requests').to_i
        
        return 0 if total_requests == 0
        return (total_time / total_requests).round(0)
      end
      
      0
    rescue => e
      0
    end
    
    # Centralized error logging
    def log_error(context, error)
      message = error.is_a?(String) ? error : error.message
      AppLogger.warn("⚠️  [AnalyticsService] #{context}: #{message}")
      
      if defined?(Sentry) && error.is_a?(Exception)
        Sentry.capture_exception(error, extra: { context: context })
      end
    end
  end
end
