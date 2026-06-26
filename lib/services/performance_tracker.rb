# frozen_string_literal: true

# Performance tracking service for monitoring application performance
class PerformanceTracker
  class << self
    def track(operation, metadata: {})
      start_time = Time.now
      result = yield
      duration = Time.now - start_time
      
      record_metric(operation, duration, metadata)
      
      result
    end
    
    def record_metric(operation, duration, metadata)
      return if duration < 0.1 # Ignore very fast operations
      
      DB[:performance_metrics].insert(
        operation: operation,
        duration_ms: (duration * 1000).round(2),
        metadata: metadata.to_json,
        created_at: Time.now
      )
    rescue => e
      AppLogger.debug("Failed to record metric: #{e.message}")
    end
    
    def slow_operations(since: Time.now - 3600, limit: 20)
      return [] unless DB.table_exists?(:performance_metrics)
      
      DB[:performance_metrics]
        .where('created_at > ?', since)
        .where('duration_ms > 1000') # > 1 second
        .order(Sequel.desc(:duration_ms))
        .limit(limit)
        .all
    end
    
    def average_duration(operation, since: Time.now - 3600)
      return 0 unless DB.table_exists?(:performance_metrics)
      
      result = DB[:performance_metrics]
        .where('created_at > ?', since)
        .where(operation: operation)
        .avg(:duration_ms)
      
      result.to_f.round(2)
    end
    
    def operation_stats(since: Time.now - 3600)
      return [] unless DB.table_exists?(:performance_metrics)
      
      DB[:performance_metrics]
        .where('created_at > ?', since)
        .select(:operation)
        .select_append { avg(duration_ms).as(avg_duration) }
        .select_append { max(duration_ms).as(max_duration) }
        .select_append { count.function.*.as(count) }
        .group(:operation)
        .order(Sequel.desc(:avg_duration))
        .all
    end
  end
end
