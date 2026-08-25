# frozen_string_literal: true

require 'redis'

# Regression test for the production incident (Aug 25, 2026, round 8) where
# config/initializers/redis_cluster.rb passed `reconnect_delay:` /
# `reconnect_delay_max:` to Redis.new. Those are NOT valid keyword
# arguments for the installed redis gem (5.4.1) - only
# `reconnect_attempts:` is supported - so Redis.new raised
# `ArgumentError: unknown keyword: :reconnect_delay` immediately, before
# any network connection was even attempted. Because REDIS_POOL lazily
# constructs the Redis client inside the ConnectionPool block, this meant
# EVERY real attempt to talk to Redis failed in production, and
# RedisService#redis_available?'s bare rescue silently reported this as
# "Redis unavailable" - masking the fact that Redis itself was never the
# problem; the client object could never even be constructed.
#
# This spec doesn't require a live Redis connection - it only proves the
# exact Redis.new(...) keyword combination used by this initializer
# doesn't raise ArgumentError, which is the actual bug that occurred.
describe "Redis.new keyword compatibility (config/initializers/redis_cluster.rb)" do
  it "constructs a single-instance Redis client without raising ArgumentError" do
    expect {
      Redis.new(
        url: 'redis://localhost:6379/0',
        reconnect_attempts: 3,
        timeout: 5
      )
    }.not_to raise_error
  end

  # NOTE: this test documents a SECOND, separate landmine found while
  # fixing the reconnect_delay bug above: the base `redis` gem no longer
  # supports `cluster:` at all - it was moved to the `redis-clustering`
  # gem - so Redis.new(cluster: [...]) raises RuntimeError immediately.
  # This branch is only reached when REDIS_CLUSTER_URLS/REDIS_CLUSTER are
  # set, which isn't the case in this environment today (confirmed the
  # single-instance branch is what's actually used in production), but if
  # cluster mode is ever enabled without adding the redis-clustering gem,
  # it will fail exactly like the reconnect_delay bug did.
  it "documents that cluster-mode currently requires the redis-clustering gem (not installed)" do
    expect {
      Redis.new(
        cluster: ['redis://localhost:6379/0', 'redis://localhost:6380/0'],
        reconnect_attempts: 3,
        timeout: 5
      )
    }.to raise_error(RuntimeError, /redis-clustering/)
  end

  # Explicitly documents the exact bug that occurred, so it's obvious in
  # test output if this regression is ever reintroduced.
  it "raises ArgumentError if reconnect_delay/reconnect_delay_max are passed (documents the bug that occurred)" do
    expect {
      Redis.new(
        url: 'redis://localhost:6379/0',
        reconnect_attempts: 3,
        reconnect_delay: 1,
        timeout: 5
      )
    }.to raise_error(ArgumentError, /unknown keyword/)
  end
end
