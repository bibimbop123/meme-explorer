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
    end

    # Regression test for the production incident (Aug 25, 2026, round 3)
    # where this on-demand fetch fired unconditionally on EVERY request
    # that reached this point, with zero coordination with
    # MemePoolManager's own bootstrap lock. In production this meant every
    # single incoming request independently launched its own synchronous
    # Reddit fetch AT THE SAME TIME as MemePoolManager's legitimate
    # background bootstrap thread, all from the same server/IP - Reddit's
    # rate limiter kicked in almost instantly, returning zero memes for
    # every request, and the pile-up of extra concurrent calls actively
    # sabotaged the one bootstrap fetch that actually mattered.
    it 'does not attempt an on-demand Reddit fetch while MemePoolManager already holds the bootstrap lock' do
      allow(RedisService).to receive(:get).with(MemePoolManager::BOOTSTRAP_LOCK_KEY).and_return('1')
      allow(RedisService).to receive(:get).with(MemePoolManager::BOOTSTRAP_COOLDOWN_KEY).and_return(nil)

      expect(InlineRedditFetcher).not_to receive(:fetch)

      ctx.random_memes_pool
    end

    it 'does not attempt an on-demand Reddit fetch during a rate-limit cooldown' do
      allow(RedisService).to receive(:get).with(MemePoolManager::BOOTSTRAP_LOCK_KEY).and_return(nil)
      allow(RedisService).to receive(:get).with(MemePoolManager::BOOTSTRAP_COOLDOWN_KEY).and_return('true')

      expect(InlineRedditFetcher).not_to receive(:fetch)

      ctx.random_memes_pool
    end

    it 'still attempts the on-demand fetch when no bootstrap/cooldown is active' do
      allow(RedisService).to receive(:get).with(MemePoolManager::BOOTSTRAP_LOCK_KEY).and_return(nil)
      allow(RedisService).to receive(:get).with(MemePoolManager::BOOTSTRAP_COOLDOWN_KEY).and_return(nil)

      expect(InlineRedditFetcher).to receive(:fetch).and_return([])

      ctx.random_memes_pool
    end
  end
end
