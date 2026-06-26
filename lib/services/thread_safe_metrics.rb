# lib/services/thread_safe_metrics.rb
# P2 CRITICAL FIX: Thread-safe metrics to prevent race conditions

require 'concurrent'

module ThreadSafeMetrics
  class Collector
    def initialize
      @metrics = Concurrent::Hash.new
      @request_count = Concurrent::AtomicFixnum.new(0)
      @total_duration = Concurrent::AtomicReference.new(0.0)
      @lock = Mutex.new
    end
    
    # Thread-safe increment
    def increment(key, amount = 1)
      @metrics.compute(key) do |old_value|
        (old_value || 0) + amount
      end
    end
    
    # Thread-safe set
    def set(key, value)
      @metrics[key] = value
    end
    
    # Thread-safe get
    def get(key, default = 0)
      @metrics.fetch(key, default)
    end
    
    # Record request timing with atomic operations
    def record_request(duration_ms)
      count = @request_count.increment
      
      # Update average with thread-safe operations
      @lock.synchronize do
        current_total = @total_duration.value
        new_total = current_total + duration_ms
        @total_duration.set(new_total)
      end
      
      count
    end
    
    # Get average request time (thread-safe)
    def avg_request_time_ms
      @lock.synchronize do
        count = @request_count.value
        return 0.0 if count.zero?
        @total_duration.value / count.to_f
      end
    end
    
    # Get all metrics snapshot (thread-safe)
    def snapshot
      @lock.synchronize do
        {
          total_requests: @request_count.value,
          avg_request_time_ms: avg_request_time_ms,
          metrics: @metrics.dup
        }
      end
    end
    
    # Reset all metrics (thread-safe)
    def reset!
      @lock.synchronize do
        @metrics.clear
        @request_count.value = 0
        @total_duration.set(0.0)
      end
    end
  end
end
