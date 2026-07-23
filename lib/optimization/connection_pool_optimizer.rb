# frozen_string_literal: true

# Connection Pool Optimizer
# Dynamically adjusts pool size based on load
# Created: July 22, 2026

module ConnectionPoolOptimizer
  class << self
    # Analyze pool usage and recommend size
    def analyze_pool
      stats = ConnectionPoolMonitor.stats
      recommendations = []
      
      if stats[:utilization] > 90
        recommendations << {
          severity: :critical,
          message: "Pool utilization at #{stats[:utilization]}%",
          action: "Increase pool size from #{stats[:size]} to #{stats[:size] * 1.5}"
        }
      elsif stats[:utilization] > 70
        recommendations << {
          severity: :warning,
          message: "Pool utilization at #{stats[:utilization]}%",
          action: "Monitor and consider increasing pool size"
        }
      end
      
      if stats[:waiting] > 0
        recommendations << {
          severity: :critical,
          message: "#{stats[:waiting]} connections waiting",
          action: "Immediate pool size increase needed"
        }
      end
      
      recommendations
    end

    # Auto-tune pool based on metrics
    def auto_tune
      stats = ConnectionPoolMonitor.stats
      current_size = stats[:size]
      
      # Increase pool if utilization > 80%
      if stats[:utilization] > 80
        new_size = [current_size * 1.5, 100].min.to_i
        AppLogger.info("[PoolOptimizer] Increasing pool from #{current_size} to #{new_size}")
        return new_size
      end
      
      # Decrease pool if utilization < 30%
      if stats[:utilization] < 30
        new_size = [current_size * 0.8, 10].max.to_i
        AppLogger.info("[PoolOptimizer] Decreasing pool from #{current_size} to #{new_size}")
        return new_size
      end
      
      current_size
    end
  end
end
