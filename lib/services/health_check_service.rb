# Health Check Service
# Comprehensive application health monitoring
# Created: June 2, 2026

class HealthCheckService
  class << self
    # Perform comprehensive health check
    # @return [Hash] Health status with detailed metrics
    def check
      {
        status: overall_status,
        timestamp: Time.now.iso8601,
        uptime: uptime_info,
        database: database_check,
        cache: cache_check,
        redis: redis_check,
        services: services_check,
        performance: performance_metrics,
        errors: error_metrics
      }
    end
    
    # Quick health check for load balancer
    # @return [Hash] Basic health status
    def quick_check
      {
        status: database_alive? && cache_alive? ? 'healthy' : 'unhealthy',
        timestamp: Time.now.iso8601
      }
    end
    
    private
    
    def overall_status
      checks = [
        database_alive?,
        cache_alive?,
        error_rate_acceptable?
      ]
      
      if checks.all?
        'healthy'
      elsif checks.any?
        'degraded'
      else
        'unhealthy'
      end
    end
    
    def uptime_info
      {
        seconds: uptime_seconds,
        started_at: $start_time&.iso8601,
        human: humanize_duration(uptime_seconds)
      }
    end
    
    def database_check
      start = Time.now
      alive = database_alive?
      duration_ms = ((Time.now - start) * 1000).round(2)
      
      {
        status: alive ? 'connected' : 'disconnected',
        response_time_ms: duration_ms,
        type: db_type,
        pool_size: db_pool_size
      }
    end
    
    def cache_check
      start = Time.now
      alive = cache_alive?
      duration_ms = ((Time.now - start) * 1000).round(2)
      
      memes_count = begin
        MEME_CACHE.get(:memes)&.size || 0
      rescue
        0
      end
      
      {
        status: alive ? 'operational' : 'offline',
        response_time_ms: duration_ms,
        cached_memes: memes_count,
        last_refresh: cache_last_refresh
      }
    end
    
    def redis_check
      if defined?(REDIS) && REDIS
        begin
          start = Time.now
          REDIS.ping
          duration_ms = ((Time.now - start) * 1000).round(2)
          
          {
            status: 'connected',
            response_time_ms: duration_ms,
            url: ENV['REDIS_URL'] ? 'configured' : 'not_configured'
          }
        rescue => e
          {
            status: 'error',
            error: e.message
          }
        end
      else
        {
          status: 'not_configured'
        }
      end
    end
    
    def services_check
      {
        sidekiq: sidekiq_status,
        sentry: sentry_status,
        api: api_status
      }
    end
    
    def performance_metrics
      {
        avg_response_time_ms: (METRICS[:avg_request_time_ms] rescue 0),
        total_requests: (METRICS[:total_requests] rescue 0),
        thread_pool: thread_pool_status
      }
    end
    
    def error_metrics
      if defined?(ErrorHandler::Logger)
        {
          recent_errors: ErrorHandler::Logger.recent(10).size,
          error_rate_5m: ErrorHandler::Logger.error_rate(300),
          critical_errors_5m: ErrorHandler::Logger.critical_errors(300).size
        }
      else
        {
          recent_errors: 0,
          error_rate_5m: 0,
          critical_errors_5m: 0
        }
      end
    end
    
    # Helper methods
    
    def database_alive?
      DB.execute("SELECT 1").any?
    rescue
      false
    end
    
    def cache_alive?
      MEME_CACHE.get(:memes).is_a?(Array)
    rescue
      false
    end
    
    def error_rate_acceptable?
      if defined?(ErrorHandler::Logger)
        ErrorHandler::Logger.error_rate(300) < 0.05 # Less than 5% error rate
      else
        true
      end
    end
    
    def uptime_seconds
      return 0 unless defined?($start_time) && $start_time.is_a?(Time)
      (Time.now - $start_time).to_i
    end
    
    def humanize_duration(seconds)
      days = seconds / 86400
      hours = (seconds % 86400) / 3600
      minutes = (seconds % 3600) / 60
      
      parts = []
      parts << "#{days}d" if days > 0
      parts << "#{hours}h" if hours > 0
      parts << "#{minutes}m" if minutes > 0
      
      parts.empty? ? "0m" : parts.join(' ')
    end
    
    def db_type
      if defined?(DB) && DB
        DB.class.name
      else
        'unknown'
      end
    end
    
    def db_pool_size
      begin
        ENV.fetch('DB_POOL_SIZE', '5').to_i
      rescue
        5
      end
    end
    
    def cache_last_refresh
      refresh_time = MEME_CACHE.get(:last_refresh) rescue nil
      refresh_time&.iso8601 || 'never'
    end
    
    def sidekiq_status
      if defined?(Sidekiq)
        'configured'
      else
        'not_configured'
      end
    end
    
    def sentry_status
      if defined?(Sentry) && ENV['SENTRY_DSN']
        'configured'
      else
        'not_configured'
      end
    end
    
    def api_status
      {
        reddit: {
          client_id: !ENV.fetch('REDDIT_CLIENT_ID', '').empty?,
          client_secret: !ENV.fetch('REDDIT_CLIENT_SECRET', '').empty?
        }
      }
    end
    
    def thread_pool_status
      if defined?(ANALYTICS_POOL)
        {
          configured: true,
          max_threads: (ANALYTICS_POOL.max_length rescue 'unknown'),
          max_queue: (ANALYTICS_POOL.max_queue rescue 'unknown')
        }
      else
        {
          configured: false
        }
      end
    end
  end
end
