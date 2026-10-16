require_relative '../spec_helper'
require_relative '../../lib/services/meme_pool_manager'

RSpec.describe 'Pool expansion fetch budget' do
  let(:fetcher) { instance_double(RedditFetcherService) }

  it 'allocates requested inventory across the communities actually fetched' do
    communities = 80.times.map { |i| "community#{i}" }
    allow(MemePoolManager).to receive(:load_tier_subreddits).and_return(communities)
    expect(fetcher).to receive(:fetch_memes) do |selected, limit:|
      expect(selected.size).to eq(25)
      expect(selected.uniq.size).to eq(25)
      expect(limit).to eq(40)
      []
    end
    MemePoolManager.send(:fetch_from_tier, :tier_1, 1000, fetcher: fetcher)
  end

  it 'rounds up small budgets and caps listings at 100' do
    allow(MemePoolManager).to receive(:load_tier_subreddits).and_return(['cats', 'funny'])
    expect(fetcher).to receive(:fetch_memes).with(match_array(['cats', 'funny']), limit: 3).and_return([])
    MemePoolManager.send(:fetch_from_tier, :tier_1, 5, fetcher: fetcher)
    expect(fetcher).to receive(:fetch_memes).with(match_array(['cats', 'funny']), limit: 100).and_return([])
    MemePoolManager.send(:fetch_from_tier, :tier_1, 5000, fetcher: fetcher)
  end

  it 'makes no requests for zero budgets or empty tiers' do
    expect(fetcher).not_to receive(:fetch_memes)
    MemePoolManager.send(:fetch_from_tier, :tier_1, 0, fetcher: fetcher)
    allow(MemePoolManager).to receive(:load_tier_subreddits).and_return([])
    expect(MemePoolManager.send(:fetch_from_tier, :tier_1, 100, fetcher: fetcher)).to eq([])
  end
end