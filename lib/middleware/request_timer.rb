# Request Timer Middleware
# Tracks request duration and logs slow requests
# Integrates with Sentry for performance monitoring

class RequestTimer
  SLOW_REQUEST_THRESHOLD = 500  # milliseconds
  
  def initialize(app)
    @app = app
  end
  
  def call(env)
    start_time = Time.now
    request_id = SecureRandom.hex(8)
    
    # Add request ID to env for tracking
    env['REQUEST_ID'] = request_id
    
    # Call the app
    status, headers, response = @app.call(env)
    
    # Calculate duration
    duration = ((Time.now - start_time) * 1000).round(2)
    
    # Extract path and method
    path = env['PATH_INFO']
    method = env['REQUEST_METHOD']
    
    # Add timing header
    headers['X-Request-Duration'] = "#{duration}ms"
    headers['X-Request-ID'] = request_id
    
    # Log request
    log_request(method, path, status, duration, request_id)
    
    # Track slow requests
    if duration > SLOW_REQUEST_THRESHOLD
      track_slow_request(method, path, duration, request_id)
    end
    
    [status, headers, response]
  rescue => e
    # Log error with request context
    puts "❌ [REQUEST ERROR] #{env['REQUEST_METHOD']} #{env['PATH_INFO']}: #{e.class} - #{e.message}"
    Sentry.capture_exception(e, extra: {
      path: env['PATH_INFO'],
      method: env['REQUEST_METHOD'],
      request_id: request_id
    }) if defined?(Sentry)
    
    raise e
  end
  
  private
  
  def log_request(method, path, status, duration, request_id)
    # Color-code based on duration
    color = case
    when duration > 1000 then :red
    when duration > 500 then :yellow
    when duration > 200 then :light_yellow
    else :green
    end
    
    status_color = status >= 500 ? :red : (status >= 400 ? :yellow : :green)
    
    puts "[#{request_id}] #{method} #{path} - #{status.to_s.colorize(status_color)} - #{duration}ms".colorize(color)
  end
  
  def track_slow_request(method, path, duration, request_id)
    # Log to Sentry
    if defined?(Sentry)
      Sentry.capture_message(
        "Slow request: #{method} #{path}",
        level: :warning,
        extra: {
          duration_ms: duration,
          path: path,
          method: method,
          request_id: request_id,
          threshold_ms: SLOW_REQUEST_THRESHOLD
        }
      )
    end
    
    # Store in metrics (if metrics tracking is available)
    if defined?(METRICS)
      METRICS[:slow_requests] ||= []
      METRICS[:slow_requests] << {
        path: path,
        method: method,
        duration: duration,
        timestamp: Time.now,
        request_id: request_id
      }
      
      # Keep only last 100 slow requests
      METRICS[:slow_requests] = METRICS[:slow_requests].last(100)
    end
  end
end
