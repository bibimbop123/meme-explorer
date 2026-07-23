# frozen_string_literal: true

# Database Query Profiler
# Tracks slow queries and optimization opportunities
# Created: July 22, 2026

module QueryProfiler
  class << self
    SLOW_QUERY_THRESHOLD = 100 # milliseconds

    def profile(query_name, &block)
      start_time = Time.now
      result = block.call
      duration = ((Time.now - start_time) * 1000).round(2)
      
      log_query(query_name, duration) if duration > SLOW_QUERY_THRESHOLD
      
      result
    end

    def log_query(query_name, duration)
      @slow_queries ||= []
      @slow_queries << {
        name: query_name,
        duration: duration,
        timestamp: Time.now
      }
      
      AppLogger.warn("[SlowQuery] #{query_name} took #{duration}ms")
    end

    def report
      return {} unless @slow_queries
      
      {
        total_slow_queries: @slow_queries.size,
        average_duration: @slow_queries.sum { |q| q[:duration] } / @slow_queries.size,
        slowest_queries: @slow_queries.sort_by { |q| -q[:duration] }.take(10)
      }
    end

    def reset
      @slow_queries = []
    end
  end
end
