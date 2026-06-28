# Performance Profiler
# Provides lightweight performance profiling without external dependencies
# Created: June 2, 2026

module PerformanceProfiler
  class << self
    # Profile a block of code and return execution time
    # @param label [String] Description of the code being profiled
    # @param threshold_ms [Integer] Log warning if exceeds threshold
    # @return [Object] Return value of the block
    def profile(label, threshold_ms: 1000)
      start_time = Time.now
      result = yield
      duration_ms = ((Time.now - start_time) * 1000).round(2)
      
      if duration_ms > threshold_ms
        AppLogger.warn("⚠️  [SLOW] #{label}: #{duration_ms}ms (threshold: #{threshold_ms}ms)")
      else
        AppLogger.info("✓ #{label}: #{duration_ms}ms")
      end
      
      # Store for analytics
      record_metric(label, duration_ms)
      
      result
    rescue => e
      AppLogger.error("❌ [PROFILE ERROR] #{label}: #{e.message}")
      raise
    end
    
    # Profile database queries
    # @param query [String] SQL query
    # @param params [Array] Query parameters
    # @return [Array] Query results
    def profile_query(query, params = [])
      short_query = query.gsub(/\s+/, ' ').strip[0..100]
      profile("SQL: #{short_query}", threshold_ms: 100) do
        DB.execute(query, params)
      end
    end
    
    # Profile HTTP requests
    # @param url [String] Request URL
    # @return [Net::HTTPResponse] Response
    def profile_http(url)
      profile("HTTP: #{url}", threshold_ms: 2000) do
        yield
      end
    end
    
    # Get performance metrics
    # @return [Hash] Performance stats
    def metrics
      @metrics ||= {}
    end
    
    # Record a metric
    # @param label [String] Metric label
    # @param value [Numeric] Metric value
    def record_metric(label, value)
      @metrics ||= {}
      @metrics[label] ||= { count: 0, total: 0, min: Float::INFINITY, max: 0 }
      
      @metrics[label][:count] += 1
      @metrics[label][:total] += value
      @metrics[label][:min] = [value, @metrics[label][:min]].min
      @metrics[label][:max] = [value, @metrics[label][:max]].max
      @metrics[label][:avg] = (@metrics[label][:total] / @metrics[label][:count]).round(2)
    end
    
    # Get summary of all metrics
    # @return [Hash] Metrics summary
    def summary
      @metrics ||= {}
      @metrics.map do |label, stats|
        {
          label: label,
          calls: stats[:count],
          avg_ms: stats[:avg],
          min_ms: stats[:min],
          max_ms: stats[:max],
          total_ms: stats[:total].round(2)
        }
      end.sort_by { |m| -m[:total_ms] }
    end
    
    # Clear all metrics
    def reset!
      @metrics = {}
    end
    
    # Memory profiling
    # @param label [String] Description
    # @return [Object] Block return value
    def profile_memory(label)
      before = get_memory_usage
      result = yield
      after = get_memory_usage
      delta_mb = ((after - before) / 1024.0 / 1024.0).round(2)
      
      AppLogger.info("📊 [MEMORY] #{label}: #{delta_mb}MB delta (#{after_mb(after)}MB total)")
      
      result
    end
    
    private
    
    def get_memory_usage
      # Ruby 2.1+
      if defined?(GC) && GC.respond_to?(:stat)
        GC.stat(:heap_live_slots) * GC.stat(:malloc_increase_bytes_limit) / GC.stat(:heap_available_slots)
      else
        0
      end
    rescue
      0
    end
    
    def after_mb(bytes)
      (bytes / 1024.0 / 1024.0).round(2)
    end
  end
end
