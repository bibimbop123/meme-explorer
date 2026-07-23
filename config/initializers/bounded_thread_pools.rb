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
