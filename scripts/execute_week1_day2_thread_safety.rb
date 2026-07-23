#!/usr/bin/env ruby
# Week 1 Day 2: Thread Safety Fixes
# Priority: P0 - CRITICAL
# Date: July 22, 2026

require 'fileutils'

puts "="*80
puts "WEEK 1 DAY 2: THREAD SAFETY FIXES"
puts "="*80
puts ""

# Fix #1: Create thread-safe METRICS replacement
puts "[1/4] Creating thread-safe metrics implementation..."

metrics_concern_file = 'lib/concerns/thread_safe_metrics.rb'

metrics_content = <<~RUBY
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
RUBY

File.write(metrics_concern_file, metrics_content)
puts "   ✓ Created: #{metrics_concern_file}"

puts ""

# Fix #2: Create bounded thread pool configuration
puts "[2/4] Creating bounded thread pool for MemePoolManager..."

thread_pool_config = 'config/initializers/bounded_thread_pools.rb'

pool_content = <<~RUBY
  # frozen_string_literal: true

  require 'concurrent'

  # Bounded Thread Pools
  # Prevents unbounded thread creation under load
  # Each pool has a fixed maximum size

  # Pool for meme fetching operations (5 concurrent max)
  MEME_FETCH_POOL = Concurrent::FixedThreadPool.new(
    5,
    max_queue: 100,
    fallback_policy: :caller_runs
  )

  # Pool for background analytics (3 concurrent max)
  ANALYTICS_POOL = Concurrent::FixedThreadPool.new(
    3,
    max_queue: 50,
    fallback_policy: :discard
  )

  # Pool for Redis operations (10 concurrent max)
  REDIS_POOL = Concurrent::FixedThreadPool.new(
    10,
    max_queue: 200,
    fallback_policy: :caller_runs
  )

  # Graceful shutdown
  at_exit do
    [MEME_FETCH_POOL, ANALYTICS_POOL, REDIS_POOL].each do |pool|
      pool.shutdown
      pool.wait_for_termination(30)
    end
  end
RUBY

FileUtils.mkdir_p('config/initializers')
File.write(thread_pool_config, pool_content)
puts "   ✓ Created: #{thread_pool_config}"

puts ""

# Fix #3: Patch instructions for app.rb METRICS
puts "[3/4] Creating patch for app.rb METRICS replacement..."

patch_file = 'scripts/patches/replace_metrics_with_thread_safe.patch'
FileUtils.mkdir_p('scripts/patches')

patch_content = <<~PATCH
  # Patch Instructions for app.rb
  # 
  # FIND (around line 165):
  #   METRICS = Hash.new(0).merge(avg_request_time_ms: 0.0)
  #
  # REPLACE WITH:
  #   require_relative 'lib/concerns/thread_safe_metrics'
  #
  # FIND (in after block, around line 329-335):
  #   METRICS[:total_requests] += 1
  #   total = METRICS[:total_requests]
  #   avg = METRICS[:avg_request_time_ms]
  #   duration = (Time.now - request_start) * 1000
  #   METRICS[:avg_request_time_ms] = ((avg * (total - 1)) + duration) / total.to_f
  #
  # REPLACE WITH:
  #   ThreadSafeMetrics.increment(:total_requests)
  #   duration_ms = ((Time.now - request_start) * 1000).to_i
  #   ThreadSafeMetrics.increment(:total_duration_ms, duration_ms)
  #
  # FIND (in metrics endpoint):
  #   METRICS
  #
  # REPLACE WITH:
  #   ThreadSafeMetrics.get_all
PATCH

File.write(patch_file, patch_content)
puts "   ✓ Created patch instructions: #{patch_file}"
puts "   ⚠ MANUAL ACTION REQUIRED: Apply patches to app.rb"

puts ""

# Fix #4: Document RedisService fix
puts "[4/4] Creating RedisService thread leak fix..."

redis_fix_doc = 'scripts/patches/redis_service_thread_fix.md'

redis_doc = <<~MD
  # RedisService Thread Leak Fix
  
  ## Problem
  Every Redis error spawns a new thread. Under high load with Redis down, 
  this creates thousands of threads leading to memory exhaustion.
  
  ## Location
  File: `lib/services/redis_service.rb` (lines 369-376)
  
  ## Current Code (DANGEROUS):
  ```ruby
  def handle_error(error, context = {})
    # ... error logging ...
    
    # Schedule availability re-check after 30 seconds
    @reconnect_thread = Thread.new do
      Thread.current.name = 'redis-reconnect'
      sleep 30
      refresh_availability!
      AppLogger.info("Redis availability re-checked", available: @redis_available)
    end
    @reconnect_thread.abort_on_exception = false
  end
  ```
  
  ## Fixed Code (SAFE):
  ```ruby
  def handle_error(error, context = {})
    # ... error logging ...
    
    # Use scheduled task instead of raw thread
    # Only one task can be scheduled at a time
    @reconnect_task&.cancel
    @reconnect_task = Concurrent::ScheduledTask.execute(30) do
      refresh_availability!
      AppLogger.info("Redis availability re-checked", available: @redis_available)
    end
  end
  ```
  
  ## Apply Fix
  1. Add `require 'concurrent'` at top of redis_service.rb
  2. Replace Thread.new with Concurrent::ScheduledTask.execute
  3. Cancel previous task before creating new one
  4. Remove @reconnect_thread.abort_on_exception line
  
  ## Benefits
  - Prevents thread leak (only 1 scheduled task at a time)
  - Better error handling
  - Automatic cleanup
  - No unbounded growth
MD

File.write(redis_fix_doc, redis_doc)
puts "   ✓ Created fix documentation: #{redis_fix_doc}"

puts ""
puts "="*80
puts "SUMMARY - DAY 2"
puts "="*80
puts ""
puts "✓ Thread-safe metrics module created"
puts "✓ Bounded thread pools configured"
puts "✓ Patch instructions generated"
puts "✓ RedisService fix documented"
puts ""
puts "⚠ MANUAL STEPS REQUIRED:"
puts "  1. Review and apply app.rb patches"
puts "  2. Apply RedisService thread fix"
puts "  3. Update MemePoolManager to use MEME_FETCH_POOL"
puts "  4. Test under load"
puts ""
puts "NEXT: Day 3 - Database Connection Pool & Indexes"
puts "="*80

puts ""
puts "Execution completed: #{Time.now}"
