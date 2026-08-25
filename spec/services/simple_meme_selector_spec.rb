# frozen_string_literal: true

require_relative '../spec_helper'
require_relative '../../lib/services/simple_meme_selector'

RSpec.describe MemeExplorer::SimpleMemeSelector do
  let(:session_id) { "test_session_#{SecureRandom.hex(4)}" }

  before do
    MemeExplorer::ViewingHistoryService.clear_history(session_id)
  end

  after do
    MemeExplorer::ViewingHistoryService.clear_history(session_id)
  end

  describe '.select' do
    it 'returns nil for an empty pool' do
      expect(described_class.select([], session_id)).to be_nil
    end

    it 'selects a meme and tags it with selection metadata' do
      pool = [
        { 'url' => 'meme1', 'likes' => 5, 'views' => 10 },
        { 'url' => 'meme2', 'likes' => 3, 'views' => 8 }
      ]

      selected = described_class.select(pool, session_id, boost_fresh: false)

      expect(selected).not_to be_nil
      expect(%w[meme1 meme2]).to include(selected['url'])
      expect(selected['selection_method']).to be_a(String)
      expect(selected['pool_size']).to be_a(Integer)
      expect(selected['total_unseen']).to be_a(Integer)
    end

    it 'does not repeat memes that have already been marked as seen' do
      pool = [
        { 'url' => 'meme1', 'likes' => 1, 'views' => 1 },
        { 'url' => 'meme2', 'likes' => 1, 'views' => 1 }
      ]

      first = described_class.select(pool, session_id, boost_fresh: false)
      # Mark the *other* meme seen too, leaving nothing unseen
      other_url = (%w[meme1 meme2] - [first['url']]).first
      MemeExplorer::ViewingHistoryService.mark_seen(session_id, other_url)

      # Pool is now fully seen -> selector should reset history rather than error
      second = described_class.select(pool, session_id, boost_fresh: false)
      expect(second).not_to be_nil
    end
  end

  describe '.select_random_meme (compatibility alias)' do
    it 'delegates to .select with keyword args' do
      pool = [{ 'url' => 'only_meme', 'likes' => 0, 'views' => 0 }]
      result = described_class.select_random_meme(pool, session_id: session_id)
      expect(result['url']).to eq('only_meme')
    end
  end

  describe 'private #weighted_sample' do
    it 'statistically favors memes with higher engagement scores' do
      pool = [
        { 'url' => 'low', 'likes' => 0, 'views' => 1 },
        { 'url' => 'high', 'likes' => 1000, 'views' => 5000 }
      ]

      counts = Hash.new(0)
      2000.times { counts[described_class.send(:weighted_sample, pool)['url']] += 1 }

      expect(counts['high']).to be > counts['low'] * 3
    end

    it 'falls back to uniform sampling when all weights are zero' do
      pool = [{ 'url' => 'a' }, { 'url' => 'b' }]
      expect { 100.times { described_class.send(:weighted_sample, pool) } }.not_to raise_error
    end

    it 'returns nil for an empty pool' do
      expect(described_class.send(:weighted_sample, [])).to be_nil
    end
  end

  describe 'private #has_engagement_data?' do
    it 'returns true when any meme has likes or views' do
      pool = [{ 'url' => 'a', 'likes' => 0 }, { 'url' => 'b', 'views' => 5 }]
      expect(described_class.send(:has_engagement_data?, pool)).to eq(true)
    end

    it 'returns false when no meme has engagement data' do
      pool = [{ 'url' => 'a' }, { 'url' => 'b' }]
      expect(described_class.send(:has_engagement_data?, pool)).to eq(false)
    end
  end
end
