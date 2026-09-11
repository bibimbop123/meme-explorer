# frozen_string_literal: true

# SelectionBenchmark - the one number this product actually cares about.
#
# Product thesis: Meme Explorer is a selection engine. Given a person and a
# moment, it picks the one meme that keeps them here. Everything else in
# this app - the leaderboard, the blog, the admin dashboard - is secondary.
# If we don't know, continuously and honestly, how fast and how reliably
# that one decision gets made, we don't actually know how our product is
# doing, no matter how many other metrics dashboards exist.
#
# RequestTimer (lib/middleware/request_timer.rb) already times every HTTP
# request generically and logs slow ones. This is deliberately narrower:
# it times ONLY the meme-selection step itself (pool lookup + selection
# algorithm, not routing/rendering/ad-serving overhead around it), and
# keeps a small rolling window in Redis so /metrics can show a live
# p50/p95 for the one loop the business is actually betting on - not
# buried inside a generic "average response time" number that also
# includes /blog and /admin.
#
# Usage:
#   result = SelectionBenchmark.measure { MemePoolManager.get_pool }
#   # => returns the block's return value; latency is recorded as a side effect
#
#   SelectionBenchmark.stats
#   # => { count: 500, p50_ms: 4.2, p95_ms: 38.1, p99_ms: 112.0 }
#
# STAGES: the total loop is `measure` (stage: :total, the default) - the
# whole "pick this person their next meme" decision as one black box. Once
# a live number showed that total was ~217ms median (nowhere near
# "instant"), the natural next question is WHERE those 217ms go: finding
# the pool, or choosing from it? Rather than guess, `measure(stage: ...)`
# lets call sites label which piece they're timing, each stage gets its
# own Redis key/rolling window, and `stats(stage: ...)` reports them
# independently. Refactor based on which stage's numbers actually justify
# it - not on a guess about which one "feels" slow.
class SelectionBenchmark
  REDIS_KEY_PREFIX = "selection_benchmark:latencies_ms"
  MAX_SAMPLES = 500 # rolling window - recent performance, not all-time average

  class << self
    # Times the given block and records the latency under `stage`.
    # Returns the block's own return value untouched, so this can wrap an
    # existing call without changing its behavior.
    def measure(stage: :total)
      start = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      result = yield
      record((Process.clock_gettime(Process::CLOCK_MONOTONIC) - start) * 1000, stage: stage)
      result
    end

    # Records a latency sample (milliseconds) into the rolling window for
    # the given stage.
    def record(duration_ms, stage: :total)
      key = redis_key(stage)
      RedisService.rpush(key, duration_ms.round(2))
      # Trim to the most recent MAX_SAMPLES entries directly via the pool -
      # RedisService doesn't expose ltrim, and this is the one spot narrow
      # enough to justify reaching past it rather than growing its public
      # API for a single caller.
      RedisService.with_redis { |redis| redis.ltrim(key, -MAX_SAMPLES, -1) }
    rescue => e
      AppLogger.warn("⚠️  [SelectionBenchmark] Failed to record latency (stage=#{stage}): #{e.message}") if defined?(AppLogger)
    end

    # Returns p50/p95/p99 latency (ms) over the current rolling window for
    # the given stage, or nil values if there's no data yet (e.g. fresh
    # boot, Redis down).
    def stats(stage: :total)
      samples = RedisService.lrange(redis_key(stage)) || []
      values = samples.map(&:to_f).sort

      return { count: 0, p50_ms: nil, p95_ms: nil, p99_ms: nil } if values.empty?

      {
        count: values.size,
        p50_ms: percentile(values, 50),
        p95_ms: percentile(values, 95),
        p99_ms: percentile(values, 99)
      }
    end

    # Convenience: every stage's stats together, for dashboards that want
    # to show the full breakdown in one call.
    #
    # :pool_manager_lookup and :reddit_fetch are sub-stages of
    # :pool_lookup, added specifically to test the hypothesis (from
    # comparing local synthetic benchmarks against real-world curl
    # timings) that real network I/O - not Ruby-side logic - explains the
    # gap between "a few ms" locally and "~217-480ms" observed manually.
    # :pool_manager_lookup isolates MemePoolManager's own Redis round-trip;
    # :reddit_fetch isolates the on-demand Reddit API call. If those two
    # numbers stay small in production while :pool_lookup is large, the
    # cost is in the surrounding fallback-chain logic instead, which
    # would point back at a refactor of lib/helpers/meme_pool_helpers.rb.
    def stage_breakdown
      {
        total: stats(stage: :total),
        pool_lookup: stats(stage: :pool_lookup),
        pool_manager_lookup: stats(stage: :pool_manager_lookup),
        reddit_fetch: stats(stage: :reddit_fetch),
        selection: stats(stage: :selection)
      }
    end

    private

    def redis_key(stage)
      "#{REDIS_KEY_PREFIX}:#{stage}"
    end

    def percentile(sorted_values, pct)
      return nil if sorted_values.empty?
      index = ((pct / 100.0) * (sorted_values.size - 1)).round
      sorted_values[index].round(2)
    end
  end
end
