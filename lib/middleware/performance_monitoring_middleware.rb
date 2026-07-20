# frozen_string_literal: true

# Performance Monitoring Middleware
# Tracks response times and identifies slow requests

class PerformanceMonitoringMiddleware
  SLOW_REQUEST_THRESHOLD = ENV.fetch('SLOW_REQUEST_MS', 1000).to_i
  
  def initialize(app)
    @app = app
  end
  
  def call(env)
    start_time = Time.now
    
    status, headers, body = @app.call(env)
    
    duration_ms = ((Time.now - start_time) * 1000).round(2)
    
    # Log slow requests
    if duration_ms > SLOW_REQUEST_THRESHOLD
      AppLogger.warn(
        "SLOW REQUEST: " + env['REQUEST_METHOD'].to_s + " " + env['PATH_INFO'].to_s + " " +
        "took " + duration_ms.to_s + "ms (threshold: " + SLOW_REQUEST_THRESHOLD.to_s + "ms)"
      )
    end
    
    # Add timing header for debugging
    headers['X-Response-Time'] = duration_ms.to_s + "ms"
    
    # Track metrics if StatsD available
    track_metrics(env['PATH_INFO'], duration_ms) if defined?(StatsD)
    
    [status, headers, body]
  end
  
  private
  
  def track_metrics(path, duration_ms)
    # Normalize path (remove IDs)
    normalized_path = path.gsub(/\/d+/, '/:id')
    
    StatsD.increment("http.requests." + normalized_path + ".total")
    StatsD.timing("http.requests." + normalized_path + ".duration", duration_ms)
  rescue StandardError => e
    AppLogger.error("Metrics tracking failed: " + e.message)
  end
end
