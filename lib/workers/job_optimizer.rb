# frozen_string_literal: true

# Background Job Optimizer
# Optimizes Sidekiq job processing
# Created: July 22, 2026

module JobOptimizer
  class << self
    # Batch similar jobs together
    def batch_jobs(job_class, items, batch_size: 100)
      items.each_slice(batch_size) do |batch|
        job_class.perform_async(batch)
      end
    end

    # Schedule jobs during off-peak hours
    def schedule_off_peak(job_class, *args)
      off_peak_time = next_off_peak_time
      job_class.perform_at(off_peak_time, *args)
    end

    # Monitor job queue health
    def queue_health
      stats = Sidekiq::Stats.new
      {
        enqueued: stats.enqueued,
        failed: stats.failed,
        processed: stats.processed,
        retry_size: stats.retry_size,
        dead_size: stats.dead_size,
        health: queue_health_status(stats)
      }
    end

    private

    def next_off_peak_time
      # Schedule for 2-6 AM
      now = Time.now
      target = now.change(hour: 3, min: 0, sec: 0)
      target += 1.day if target < now
      target
    end

    def queue_health_status(stats)
      return 'critical' if stats.failed > 1000
      return 'warning' if stats.enqueued > 10000
      'healthy'
    end
  end
end
