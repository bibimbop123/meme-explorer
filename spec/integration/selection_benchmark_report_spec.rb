# spec/integration/selection_benchmark_report_spec.rb
#
# Not a correctness test - a measurement run. Hits the real /random.json
# endpoint repeatedly in a single warm process and prints stage_breakdown
# for two distinct, deliberately-separated scenarios:
#
#   1. MemePoolManager's pool empty -> local YAML fallback (cheapest branch)
#   2. MemePoolManager's pool warm & populated -> the realistic prod case
#
# WHY TWO SCENARIOS: an earlier version of this spec seeded meme_stats
# directly and reported ~2ms p50, which looked like great news - until
# tracing the code path showed random_memes_pool tries
# MemePoolManager.get_pool FIRST (backed by the 'meme_pool' Redis key),
# and only reaches meme_stats via entirely separate helper methods
# (get_trending_pool etc.) that this endpoint doesn't call. That earlier
# result was measuring the local-YAML-fallback branch by accident, not a
# representative warm pool. lib/helpers/meme_pool_helpers.rb's own
# "BUG FIX (rounds 3-5)" comment documents the on-demand Reddit fetch
# branch historically completing in ~300ms even on a rate-limited
# failure - a completely different order of magnitude. Measuring both
# scenarios explicitly, side by side, is how you avoid drawing a
# conclusion from the wrong branch.
#
# Even scenario 2 here is still a synthetic, local, in-process
# measurement - it does not include real network latency to Reddit, a
# real Redis over the network, or real concurrent load. It is a useful
# lower bound and a regression guard (these numbers should never get
# *worse*), not a replacement for reading /metrics under real traffic.
#
# Run directly to see the report:
#   bundle exec rspec spec/integration/selection_benchmark_report_spec.rb
require_relative '../spec_helper'
require_relative '../../lib/services/selection_benchmark'

describe "SelectionBenchmark measurement report (informational, not a correctness check)" do
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

    # Give the pool something real to select from - 50 distinct memes,
    # not the 10-item local fallback list, so this reflects a realistically
    # warm pool rather than the cold-start degenerate case.
    50.times do |i|
      DB.execute(
        "INSERT INTO meme_stats (url, title, subreddit, views, likes) VALUES (?, ?, ?, ?, ?)",
        ["https://example.com/bench_meme_#{i}.jpg", "Bench Meme #{i}", "test", i, i]
      )
    end
  end

  def print_report(label, breakdown)
    puts "\n" + "=" * 70
    puts label
    puts "=" * 70
    [:total, :pool_lookup, :pool_manager_lookup, :reddit_fetch, :selection].each do |stage|
      stat = breakdown[stage]
      puts format(
        "%-20s count=%-5d p50=%-8sms p95=%-8sms p99=%-8sms",
        stage, stat[:count], stat[:p50_ms], stat[:p95_ms], stat[:p99_ms]
      )
    end
    puts "=" * 70
  end

  def clear_benchmark_window
    RedisService.with_redis do |redis|
      redis.del(
        "#{SelectionBenchmark::REDIS_KEY_PREFIX}:total",
        "#{SelectionBenchmark::REDIS_KEY_PREFIX}:pool_lookup",
        "#{SelectionBenchmark::REDIS_KEY_PREFIX}:pool_manager_lookup",
        "#{SelectionBenchmark::REDIS_KEY_PREFIX}:reddit_fetch",
        "#{SelectionBenchmark::REDIS_KEY_PREFIX}:selection"
      )
    end
  end

  it "reports latency when MemePoolManager's pool is empty (local YAML fallback path)" do
    # IMPORTANT: this is actually what the earlier version of this spec was
    # measuring, even though the seeded meme_stats rows above suggested
    # otherwise. random_memes_pool tries MemePoolManager.get_pool FIRST
    # (backed by the 'meme_pool' Redis key, not meme_stats), and only
    # reaches the meme_stats-backed helpers (get_trending_pool etc.) via a
    # completely different call path this endpoint doesn't use. With a
    # fresh test Redis, MemePoolManager's pool is empty, so this falls
    # through to the local YAML meme list - the cheapest possible branch,
    # not a representative "warm production pool."
    100.times { get "/random.json" }
    print_report("EMPTY MemePoolManager pool -> local YAML fallback (100 requests)", SelectionBenchmark.stage_breakdown)
    expect(SelectionBenchmark.stage_breakdown[:total][:count]).to eq(100)
  end

  it "reports latency when MemePoolManager's pool is warm and populated (realistic production case)" do
    # Populate the actual key MemePoolManager.get_current_pool reads, so
    # get_pool takes its fast "pool exists, return it" branch - this is
    # what a healthy, already-bootstrapped production pool looks like.
    warm_pool = (1..500).map do |i|
      { "url" => "https://example.com/warm_#{i}.jpg", "title" => "Warm #{i}", "subreddit" => "test" }
    end
    RedisService.with_redis { |redis| redis.set('meme_pool', warm_pool.to_json) }
    clear_benchmark_window

    100.times { get "/random.json" }
    print_report("WARM MemePoolManager pool, 500 memes (100 requests)", SelectionBenchmark.stage_breakdown)
    expect(SelectionBenchmark.stage_breakdown[:total][:count]).to eq(100)
  end

  it "the :reddit_fetch stage correctly captures a slow on-demand fetch, isolated from everything else" do
    # Force the exact branch neither scenario above reaches: MemePoolManager
    # empty AND its own cooldown/lock checks fall through to the on-demand
    # InlineRedditFetcher.fetch call in lib/helpers/meme_pool_helpers.rb.
    # Stub that one call to simulate a slow real network round-trip (the
    # thing a local rack-test can never produce on its own), and confirm
    # the instrument attributes that delay to :reddit_fetch specifically -
    # not to :pool_lookup as an undifferentiated blob, and not bleeding
    # into :selection.
    # MEME_CACHE is a process-global in-memory cache (not reset between
    # specs), and random_memes_pool checks it BEFORE the on-demand Reddit
    # fetch - clear it explicitly so this test actually reaches the branch
    # it's trying to exercise, regardless of what earlier specs left behind.
    MemeExplorer::App::MEME_CACHE.set(:memes, [])
    RedisService.with_redis { |redis| redis.del('meme_pool') }

    allow(MemePoolHelpers).to receive(:on_demand_fetch_cooling_down?).and_return(false)
    allow(RedisService).to receive(:get).and_call_original
    allow(RedisService).to receive(:get).with("meme_pool:on_demand_fetch_cooldown").and_return(nil)
    allow(InlineRedditFetcher).to receive(:fetch) do
      sleep(0.05) # simulate a slow Reddit round-trip
      [{ "url" => "https://example.com/slow_fetch.jpg", "title" => "Slow Fetch Meme", "subreddit" => "test" }]
    end

    get "/random.json"

    breakdown = SelectionBenchmark.stage_breakdown
    print_report("Forced :reddit_fetch branch (1 request, simulated 50ms Reddit call)", breakdown)

    expect(breakdown[:reddit_fetch][:count]).to eq(1)
    expect(breakdown[:reddit_fetch][:p50_ms]).to be >= 50.0
    # The slow call should dominate :pool_lookup's total too, since
    # pool_lookup wraps the whole random_memes_pool call including this
    # fetch - but :selection (a separate, later stage) should stay fast,
    # proving the delay didn't leak into the wrong bucket.
    expect(breakdown[:pool_lookup][:p50_ms]).to be >= 50.0
    expect(breakdown[:selection][:p50_ms]).to be < 50.0
  end
end
