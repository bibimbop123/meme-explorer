# frozen_string_literal: true

require_relative '../spec_helper'
require_relative '../../lib/helpers/meme_pool_helpers'

RSpec.describe MemePoolHelpers do
  # Minimal test double that includes the module under test, exposing the
  # module-level `DB` constant it relies on via a method override.
  let(:context_class) do
    Class.new do
      include MemePoolHelpers
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
end
