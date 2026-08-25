# frozen_string_literal: true

require_relative '../spec_helper'
require_relative '../../lib/helpers/meme_pool_helpers'
require_relative '../../lib/helpers/meme_navigation_helpers'
require_relative '../../lib/services/meme_pool_manager'
require_relative '../../lib/services/inline_reddit_fetcher'

RSpec.describe MemePoolHelpers do
  # Minimal test double that includes the module under test, exposing the
  # module-level `DB` constant it relies on via a method override.
  # has_valid_media? lives in meme_navigation_helpers.rb (a plain top-level
  # method, mixed into Object at load time via app.rb's helpers stack), so
  # it's already available - no separate include needed.
  let(:context_class) do
    Class.new do
      include MemePoolHelpers

      # has_valid_media? is normally provided by meme_navigation_helpers.rb
      # (defined as a plain top-level method mixed in via app.rb's Sinatra
      # `helpers` stack at boot). Stub a permissive version here so we can
      # exercise random_memes_pool's fallback logic in isolation.
      def has_valid_media?(_meme)
        true
      end
    end
  end

  subject(:ctx) { context_class.new }

  describe '#apply_user_preferences' do
    # Regression test for the ratio bug: `preferred.size * 0.6 / preferred.size`
    # always simplified to 0, so preference-based personalization silently
    # never boosted preferred subreddits.
    it 'surfaces preferred-subreddit memes instead of dropping them entirely' do
      user_prefs = [{ 'subreddit' => 'funny', 'preference_score' => 2.0 }]
      allow(DB).to receive(:execute)
        .with(/user_subreddit_preferences/, [1])
        .and_return(user_prefs)

      pool = (1..100).map do |i|
        { 'subreddit' => (i <= 40 ? 'funny' : 'other'), 'url' => "m#{i}" }
      end

      result = ctx.apply_user_preferences(pool, 1)
      preferred_count = result.count { |m| m['subreddit'] == 'funny' }

      expect(result.size).to eq(pool.size)
      # Previously this was always 0 due to the ratio bug.
      expect(preferred_count).to be > 0
      expect(preferred_count).to be >= 30
    end

    it 'falls back to a shuffled pool when the user has no preferences' do
      allow(DB).to receive(:execute)
        .with(/user_subreddit_preferences/, [1])
        .and_return([])

      pool = (1..10).map { |i| { 'subreddit' => 'other', 'url' => "m#{i}" } }
      result = ctx.apply_user_preferences(pool, 1)

      expect(result.size).to eq(pool.size)
    end
  end

  describe '#get_exploration_pool' do
    it 'returns the requested number of memes without sorting the whole table' do
      rows = (1..200).map { |i| { 'id' => i, 'url' => "m#{i}", 'failure_count' => nil } }

      allow(DB).to receive(:execute) do |sql, params = []|
        if sql.include?('MAX(id)')
          [{ 'max_id' => rows.map { |r| r['id'] }.max }]
        elsif sql.include?('id >=')
          start_id, limit = params
          rows.select { |r| r['id'] >= start_id }.first(limit)
        else
          rows.first(params.first)
        end
      end

      # Explicitly assert the expensive `ORDER BY RANDOM()` pattern is gone.
      expect(DB).not_to receive(:execute).with(/ORDER BY RANDOM/, anything)

      result = ctx.get_exploration_pool(20)
      expect(result.size).to eq(20)
    end

    it 'wraps around to the start of the table if the random window runs short' do
      rows = (1..10).map { |i| { 'id' => i, 'url' => "m#{i}", 'failure_count' => nil } }

      allow(DB).to receive(:execute) do |sql, params = []|
        if sql.include?('MAX(id)')
          [{ 'max_id' => 10 }]
        elsif sql.include?('id >=')
          start_id, limit = params
          rows.select { |r| r['id'] >= start_id }.first(limit)
        else
          rows.first(params.first)
        end
      end

      allow(ctx).to receive(:rand).and_return(9) # near the end of the table

      result = ctx.get_exploration_pool(5)
      expect(result.size).to eq(5)
    end
  end

  describe '#random_memes_pool' do
    before do
      # Force straight through MemePoolManager (unsuccessful) and an empty
      # legacy cache so we exercise the on-demand InlineRedditFetcher path.
      allow(MemePoolManager).to receive(:get_pool).and_return(success: false, memes: [], pool_size: 0, error: 'no pool')
      allow(MemeExplorer::App::MEME_CACHE).to receive(:get).with(:memes).and_return(nil)
      allow(MemeExplorer::App::MEMES).to receive(:is_a?).and_call_original
      MemePoolHelpers.clear_on_demand_fetch_cooldown!
    end

    after { MemePoolHelpers.clear_on_demand_fetch_cooldown! }

    # Regression test for the production incident (Aug 25, 2026, rounds 3
    # and 4). Round 3 found this on-demand fetch fired unconditionally on
    # EVERY request reaching this point, uncoordinated with anything else,
    # meaning every single incoming request independently launched its own
    # synchronous Reddit fetch from the same server/IP - Reddit's rate
    # limiter kicked in almost instantly, returning zero memes for every
    # request. An initial fix peeked at MemePoolManager's own bootstrap
    # lock, but that lock is only held for as long as the rate-limit probe
    # takes (often under a second), so nearly every request's check missed
    # the tiny window where it existed and the fetch kept firing anyway
    # (round 4). The fix now uses a dedicated cooldown key that THIS
    # on-demand path owns and sets itself the moment it discovers Reddit is
    # rate-limiting it - no racing against another subsystem's transient
    # lock lifetime.
    let(:on_demand_cooldown_key) { "meme_pool:on_demand_fetch_cooldown" }

    it 'does not attempt an on-demand Reddit fetch while its own cooldown is active' do
      allow(RedisService).to receive(:get).with(on_demand_cooldown_key).and_return('true')

      expect(InlineRedditFetcher).not_to receive(:fetch)

      ctx.random_memes_pool
    end

    it 'still attempts the on-demand fetch when no cooldown is active' do
      allow(RedisService).to receive(:get).with(on_demand_cooldown_key).and_return(nil)

      expect(InlineRedditFetcher).to receive(:fetch).and_return([])

      ctx.random_memes_pool
    end

    it 'sets its own cooldown when the fetch comes back empty (likely rate-limited)' do
      allow(RedisService).to receive(:get).with(on_demand_cooldown_key).and_return(nil)
      allow(InlineRedditFetcher).to receive(:fetch).and_return([])

      expect(RedisService).to receive(:set).with(on_demand_cooldown_key, "true", ttl: 60)

      ctx.random_memes_pool
    end

    it 'sets its own cooldown when the fetch raises an error' do
      allow(RedisService).to receive(:get).with(on_demand_cooldown_key).and_return(nil)
      allow(InlineRedditFetcher).to receive(:fetch).and_raise(StandardError.new("boom"))

      expect(RedisService).to receive(:set).with(on_demand_cooldown_key, "true", ttl: 60)

      ctx.random_memes_pool
    end

    it 'does not set a cooldown when the fetch succeeds' do
      allow(RedisService).to receive(:get).with(on_demand_cooldown_key).and_return(nil)
      allow(InlineRedditFetcher).to receive(:fetch).and_return([{ 'url' => 'a' }])
      allow(MemeExplorer::App::MEME_CACHE).to receive(:set)

      expect(RedisService).not_to receive(:set).with(on_demand_cooldown_key, anything, anything)

      ctx.random_memes_pool
    end

    # Regression test for the production incident (Aug 25, 2026, round 5):
    # a Redis-only cooldown was silently defeated whenever RedisService's
    # cached `redis_available?` circuit breaker was false (or Redis was
    # otherwise flaky) - RedisService.set/get would then no-op with no
    # error, so the cooldown never actually persisted and the on-demand
    # fetch kept firing on every request forever. The in-process cooldown
    # must work as the primary gate completely independently of Redis.
    context 'when RedisService is entirely unavailable (simulating a circuit-breaker trip)' do
      before do
        allow(RedisService).to receive(:get).and_return(nil)
        allow(RedisService).to receive(:set).and_return(false)
      end

      it 'still skips the on-demand fetch once the in-process cooldown is active' do
        MemePoolHelpers.start_on_demand_fetch_cooldown!(60)

        expect(InlineRedditFetcher).not_to receive(:fetch)

        ctx.random_memes_pool
      end

      it 'still starts an in-process cooldown after a rate-limited fetch, even though Redis silently no-ops' do
        allow(InlineRedditFetcher).to receive(:fetch).and_return([])

        ctx.random_memes_pool

        expect(MemePoolHelpers.on_demand_fetch_cooling_down?).to eq(true)
      end

      it 'skips the fetch on the very next call after the in-process cooldown was set, with Redis still unavailable' do
        allow(InlineRedditFetcher).to receive(:fetch).and_return([])

        ctx.random_memes_pool # first call: fetches, gets rate-limited, starts in-process cooldown

        expect(InlineRedditFetcher).not_to receive(:fetch)
        ctx.random_memes_pool # second call: must be skipped purely via the in-process flag
      end
    end
  end
end
