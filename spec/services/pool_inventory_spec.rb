require_relative '../spec_helper'
require_relative '../../lib/services/meme_pool_manager'

RSpec.describe 'Unique pool inventory retention' do
  it 'stops later tiers and preserves cooldown even after partial publication' do
    fetcher = double(rate_limited?: true)
    fresh = { 'url' => '/partial.jpg' }
    allow(MemePoolManager).to receive(:create_fetcher).and_return(fetcher)
    expect(MemePoolManager).to receive(:fetch_from_tier).once.and_return([fresh])
    allow(MemePoolManager).to receive(:quality_filter) { |items| items }
    allow(MemePoolManager).to receive(:get_current_pool).and_return([])
    allow(MemePoolManager).to receive(:store_in_pool).with([fresh], expected_pool: anything).and_return(1)
    expect(RedisService).to receive(:set).with(MemePoolManager::BOOTSTRAP_COOLDOWN_KEY, 'true', ttl: MemePoolManager::BOOTSTRAP_COOLDOWN_TTL)
    expect(RedisService).not_to receive(:delete).with(MemePoolManager::BOOTSTRAP_COOLDOWN_KEY)
    expect(MemePoolManager.send(:fetch_batch, size: 100)[:stored]).to eq(1)
  end

  it 'keeps more than 300 unique memes and reports unique rather than overlapping tier count' do
    memes = 350.times.map { |i| { 'url' => "https://i.redd.it/#{i}.jpg", 'subreddit' => 'funny', 'title' => "Meme #{i}" } }
    allow(MemePoolManager).to receive(:categorize_by_tier).and_return(random: memes, fresh: memes, trending: [], surprise: [], diverse: [])
    expect(MemePoolManager.send(:store_in_pool, memes)).to eq(350)
    expect(RedisService.get('meme_pool:count')).to eq(350)
    expect(RedisService.get('meme_pool').size).to eq(350)
  end

  it 'retains older unique content when a maintenance batch overlaps the pool' do
    old = { 'url' => '/old.jpg' }
    fresh = { 'url' => '/fresh.jpg' }
    allow(MemePoolManager).to receive(:create_fetcher).and_return(double)
    allow(MemePoolManager).to receive(:fetch_from_tier).and_return([fresh])
    allow(MemePoolManager).to receive(:quality_filter) { |items| items }
    allow(MemePoolManager).to receive(:get_current_pool).and_return([old, fresh])
    allow(RedisService).to receive(:delete)
    expect(MemePoolManager).to receive(:store_in_pool).with([fresh, old], expected_pool: anything).and_return(2)
    expect(MemePoolManager.send(:fetch_batch, size: 100)[:stored]).to eq(2)
  end
end