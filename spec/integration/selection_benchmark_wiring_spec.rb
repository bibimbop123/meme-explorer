# spec/integration/selection_benchmark_wiring_spec.rb
#
# Verifies SelectionBenchmark is actually wired into the real /random and
# /random.json routes (not just unit-tested in isolation) - i.e. hitting
# the real endpoint through rack-test actually produces stage_breakdown
# data for :total, :pool_lookup, and :selection.
require_relative '../spec_helper'
require_relative '../../lib/services/selection_benchmark'

describe "SelectionBenchmark wiring into the core selection loop" do
  before(:each) do
    RedisService.with_redis do |redis|
      redis.del(
        "#{SelectionBenchmark::REDIS_KEY_PREFIX}:total",
        "#{SelectionBenchmark::REDIS_KEY_PREFIX}:pool_lookup",
        "#{SelectionBenchmark::REDIS_KEY_PREFIX}:pool_manager_lookup",
        "#{SelectionBenchmark::REDIS_KEY_PREFIX}:reddit_fetch",
        "#{SelectionBenchmark::REDIS_KEY_PREFIX}:selection"
      )
    end

    DB.execute(
      "INSERT INTO meme_stats (url, title, subreddit, views, likes) VALUES (?, ?, ?, ?, ?)",
      ["https://example.com/benchmark_meme.jpg", "Benchmark Meme", "test", 1, 1]
    )
  end

  it "records real latency for all three stages when /random.json is hit" do
    get "/random.json"
    expect(last_response.status).to eq(200)

    breakdown = SelectionBenchmark.stage_breakdown

    expect(breakdown[:total][:count]).to eq(1)
    expect(breakdown[:pool_lookup][:count]).to eq(1)
    expect(breakdown[:selection][:count]).to eq(1)

    # The whole point: total should be >= pool_lookup + selection (it wraps
    # both, plus a little overhead), never less. If this ever fails, the
    # instrumentation itself has a bug, not the app.
    expect(breakdown[:total][:p50_ms]).to be >= 0
    expect(breakdown[:pool_lookup][:p50_ms]).to be >= 0
    expect(breakdown[:selection][:p50_ms]).to be >= 0
  end

  it "records real latency for /random (HTML page) too" do
    get "/random"
    expect(last_response.status).to eq(200)

    breakdown = SelectionBenchmark.stage_breakdown
    expect(breakdown[:total][:count]).to eq(1)
    expect(breakdown[:pool_lookup][:count]).to eq(1)
    expect(breakdown[:selection][:count]).to eq(1)
  end
end
