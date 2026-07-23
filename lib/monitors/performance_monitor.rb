# frozen_string_literal: true

# Performance Monitor
# Real-time performance metrics
# Created: July 22, 2026

module PerformanceMonitor
  class << self
    def record_request(duration_ms, path)
      metrics[:requests] ||= []
      metrics[:requests] << {
        duration: duration_ms,
        path: path,
        timestamp: Time.now
      }
      
      # Keep last 1000 requests
      metrics[:requests] = metrics[:requests].last(1000)
    end

    def record_cache_hit(key)
      metrics[:cache_hits] ||= 0
      metrics[:cache_hits] += 1
    end

    def record_cache_miss(key)
      metrics[:cache_misses] ||= 0
      metrics[:cache_misses] += 1
    end

    def stats
      requests = metrics[:requests] || []
      
      {
        total_requests: requests.size,
        avg_response_time: avg_response_time(requests),
        p95_response_time: percentile_response_time(requests, 95),
        p99_response_time: percentile_response_time(requests, 99),
        cache_hit_rate: cache_hit_rate,
        slowest_endpoints: slowest_endpoints(requests)
      }
    end

    def reset
      @metrics = {}
    end

    private

    def metrics
      @metrics ||= {}
    end

    def avg_response_time(requests)
      return 0 if requests.empty?
      requests.sum { |r| r[:duration] } / requests.size
    end

    def percentile_response_time(requests, percentile)
      return 0 if requests.empty?
      sorted = requests.map { |r| r[:duration] }.sort
      index = (sorted.size * percentile / 100.0).ceil - 1
      sorted[index] || 0
    end

    def cache_hit_rate
      hits = metrics[:cache_hits] || 0
      misses = metrics[:cache_misses] || 0
      total = hits + misses
      return 0 if total.zero?
      (hits.to_f / total * 100).round(2)
    end

    def slowest_endpoints(requests)
      requests
        .group_by { |r| r[:path] }
        .transform_values { |reqs| reqs.sum { |r| r[:duration] } / reqs.size }
        .sort_by { |_, avg| -avg }
        .take(5)
        .to_h
    end
  end
end
