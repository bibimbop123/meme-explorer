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
      DB.execute(
        "INSERT INTO performance_metrics (operation, duration_ms, metadata, created_at) VALUES (?, ?, ?, ?)",
        [operation, (duration * 1000).round(2), metadata.to_json, Time.now]
      )
    rescue => e
      AppLogger.debug("Failed to record metric: #{e.message}")
    end

    def slow_operations(since: Time.now - 3600, limit: 20)
      DB.execute(
        "SELECT * FROM performance_metrics WHERE created_at > ? AND duration_ms > 1000 ORDER BY duration_ms DESC LIMIT ?",
        [since, limit]
      )
    rescue => e
      AppLogger.debug("Failed to query slow operations: #{e.message}")
      []
    end

    def average_duration(operation, since: Time.now - 3600)
      result = DB.get_first_value(
        "SELECT AVG(duration_ms) FROM performance_metrics WHERE created_at > ? AND operation = ?",
        [since, operation]
      )
      result.to_f.round(2)
    rescue => e
      AppLogger.debug("Failed to query average duration: #{e.message}")
      0
    end

    def operation_stats(since: Time.now - 3600)
      DB.execute(
        "SELECT operation, AVG(duration_ms) AS avg_duration, MAX(duration_ms) AS max_duration, COUNT(*) AS count
         FROM performance_metrics
         WHERE created_at > ?
         GROUP BY operation
         ORDER BY avg_duration DESC",
        [since]
      )
    rescue => e
      AppLogger.debug("Failed to query operation stats: #{e.message}")
      []
    end
  end
end
