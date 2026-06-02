# Thread Pool Configuration for Background Analytics
# Fixes memory leak from unbounded thread creation
# Date: June 2, 2026

require 'concurrent-ruby'

# Create a fixed thread pool for non-critical background tasks
# Max 5 concurrent threads prevents memory exhaustion
ANALYTICS_POOL = Concurrent::FixedThreadPool.new(
  5,                      # max_threads: Only 5 threads exist at any time
  max_queue: 1000,        # Queue up to 1000 tasks before dropping
  fallback_policy: :discard, # Drop new tasks if queue is full (prevents memory issues)
  idletime: 60            # Kill idle threads after 60 seconds
)

# Graceful shutdown on SIGTERM
at_exit do
  puts "🛑 [THREAD POOL] Shutting down gracefully..."
  ANALYTICS_POOL.shutdown
  ANALYTICS_POOL.wait_for_termination(10) # Wait up to 10 seconds
  puts "✅ [THREAD POOL] Shutdown complete"
end

puts "✅ [THREAD POOL] Analytics thread pool initialized (5 threads, 1000 queue)"
