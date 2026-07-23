# frozen_string_literal: true

require 'concurrent'

# Thread-Safe Metrics Tracking
# Replaces the unsafe METRICS hash with atomic counters
# Safe for 32+ concurrent Puma threads

module ThreadSafeMetrics
  class << self
    def initialize_metrics!
      @metrics = {
        total_requests: Concurrent::AtomicFixnum.new(0),
        total_errors: Concurrent::AtomicFixnum.new(0),
        total_duration_ms: Concurrent::AtomicFixnum.new(0)
      }
      @metrics_lock = Mutex.new
    end

    def increment(metric, value = 1)
      return unless @metrics&.key?(metric)
      @metrics[metric].increment(value)
    end

    def get(metric)
      return 0 unless @metrics&.key?(metric)
      @metrics[metric].value
    end

    def get_all
      return {} unless @metrics
      @metrics_lock.synchronize do
        {
          total_requests: @metrics[:total_requests].value,
          total_errors: @metrics[:total_errors].value,
          avg_request_time_ms: calculate_average
        }
      end
    end

    private

    def calculate_average
      total = @metrics[:total_requests].value
      return 0.0 if total.zero?
      
      duration = @metrics[:total_duration_ms].value
      (duration.to_f / total).round(2)
    end
  end

  # Initialize on load
  initialize_metrics!
end
