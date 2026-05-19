# Performance Monitor Middleware
# Tracks request performance and logs slow queries
# Generated: May 19, 2026

class PerformanceMonitor
  SLOW_REQUEST_THRESHOLD = 1.0 # seconds
  
  def initialize(app)
    @app = app
  end
  
  def call(env)
    request_start = Time.now
    
    # Add request ID for tracing
    request_id = generate_request_id
    env['HTTP_X_REQUEST_ID'] = request_id
    
    # Call the application
    status, headers, body = @app.call(env)
    
    # Calculate duration
    duration = Time.now - request_start
    
    # Log performance
    log_request_performance(env, status, duration, request_id)
    
    # Add performance headers in development
    if ENV['RACK_ENV'] == 'development'
      headers['X-Request-ID'] = request_id
      headers['X-Runtime'] = duration.round(3).to_s
    end
    
    # Track metrics
    track_performance_metrics(env['PATH_INFO'], duration, status)
    
    [status, headers, body]
  rescue => e
    # Log error with context
    puts "❌ Request failed: #{e.message}"
    puts "   Path: #{env['PATH_INFO']}"
    puts "   Method: #{env['REQUEST_METHOD']}"
    puts "   Duration: #{(Time.now - request_start).round(3)}s"
    
    Sentry.capture_exception(e, extra: {
      path: env['PATH_INFO'],
      method: env['REQUEST_METHOD'],
      duration: Time.now - request_start,
      request_id: request_id
    }) if defined?(Sentry)
    
    raise
  end
  
  private
  
  def generate_request_id
    "#{Time.now.to_i}-#{rand(100000..999999)}"
  end
  
  def log_request_performance(env, status, duration, request_id)
    method = env['REQUEST_METHOD']
    path = env['PATH_INFO']
    
    # Determine log level based on duration and status
    if duration > SLOW_REQUEST_THRESHOLD
      level = '⚠️  SLOW'
    elsif status >= 500
      level = '❌ ERROR'
    elsif status >= 400
      level = '⚠️  WARN'
    else
      level = '✅ OK'
    end
    
    # Format duration
    duration_ms = (duration * 1000).round(1)
    
    # Log the request
    puts "#{level} #{method} #{path} - #{status} (#{duration_ms}ms) [#{request_id}]"
    
    # Log additional details for slow requests
    if duration > SLOW_REQUEST_THRESHOLD
      puts "   ⏱️  Slow request details:"
      puts "   Query string: #{env['QUERY_STRING']}" if env['QUERY_STRING']
      puts "   User agent: #{env['HTTP_USER_AGENT']}"
    end
  end
  
  def track_performance_metrics(path, duration, status)
    # Skip static assets
    return if path =~ /\.(css|js|png|jpg|gif|ico|svg)$/
    
    # Aggregate metrics in cache
    metrics_key = "performance:#{path}"
    metrics = MEME_CACHE.get(metrics_key) || {
      count: 0,
      total_duration: 0.0,
      max_duration: 0.0,
      min_duration: Float::INFINITY,
      errors: 0
    }
    
    metrics[:count] += 1
    metrics[:total_duration] += duration
    metrics[:max_duration] = [metrics[:max_duration], duration].max
    metrics[:min_duration] = [metrics[:min_duration], duration].min
    metrics[:errors] += 1 if status >= 500
    metrics[:avg_duration] = metrics[:total_duration] / metrics[:count]
    
    MEME_CACHE.set(metrics_key, metrics)
    
    # Keep only last 100 endpoints
    cleanup_old_metrics if metrics[:count] % 100 == 0
  end
  
  def cleanup_old_metrics
    # This is a simplified version - in production use Redis with TTL
    # or a proper time-series database
  end
  
  # Class method to get performance report
  def self.performance_report
    # This would aggregate all metrics
    # Simplified for demonstration
    {
      slow_endpoints: [],
      error_endpoints: [],
      total_requests: 0
    }
  end
end
