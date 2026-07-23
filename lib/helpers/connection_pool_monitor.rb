# frozen_string_literal: true

# Connection Pool Monitoring Helper
# Tracks and logs connection pool health
# Created: July 22, 2026

module ConnectionPoolMonitor
  class << self
    def stats
      return {} unless defined?(ActiveRecord::Base)
      
      pool = ActiveRecord::Base.connection_pool
      {
        size: pool.size,
        connections: pool.connections.size,
        in_use: pool.connections.count(&:in_use?),
        available: pool.available_connection_count,
        waiting: pool.num_waiting_in_queue,
        utilization: utilization_percentage(pool)
      }
    end

  def log_stats
    return unless should_log?
    
    data = stats
    return if data.empty?
    
    if data[:utilization] > 80
      AppLogger.warn("[ConnectionPool] High utilization: #{data[:utilization]}%", data)
    elsif data[:waiting] > 0
      AppLogger.warn("[ConnectionPool] Connections waiting: #{data[:waiting]}", data)
    else
      AppLogger.debug("[ConnectionPool] Health check", data)
    end
  end

  def health_check
    data = stats
    return :unknown if data.empty?
    
    return :critical if data[:utilization] > 95
    return :warning if data[:utilization] > 80
      return :healthy
    end

    private

    def utilization_percentage(pool)
      return 0 if pool.size.zero?
      ((pool.connections.count(&:in_use?).to_f / pool.size) * 100).round(1)
    end

    def should_log?
      ENV['CONNECTION_POOL_MONITORING'] == 'true' || ENV['RACK_ENV'] == 'development'
    end
  end
end
