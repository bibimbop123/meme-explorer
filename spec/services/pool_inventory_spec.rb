require_relative '../spec_helper'
require_relative '../../lib/services/meme_pool_manager'

RSpec.describe 'Unique pool inventory retention' do
  it 'keeps more than 300 unique memes and reports unique rather than overlapping tier count' do
    memes = 350.times.map { |i| { 'url' => "https://i.redd.it/#{i}.jpg", 'subreddit' => 'funny', 'title' => "Meme #{i}" } }
    allow(MemePoolManager).to receive(:categorize_by_tier).and_return(random: memes, fresh: memes, trending: [], surprise: [], diverse: [])
    writes = {}
    allow(RedisService).to receive(:set) { |key, value, **_| writes[key] = value; true }
    [:delete, :hset, :rpush, :expire].each { |method| allow(RedisService).to receive(method).and_return(true) }
    expect(MemePoolManager.send(:store_in_pool, memes)).to eq(350)
    expect(writes['meme_pool:count']).to eq(350)
    expect(JSON.parse(writes['meme_pool']).size).to eq(350)
  end

  it 'retains older unique content when a maintenance batch overlaps the pool' do
    old = { 'url' => '/old.jpg' }
    fresh = { 'url' => '/fresh.jpg' }
    allow(MemePoolManager).to receive(:create_fetcher).and_return(double)
    allow(MemePoolManager).to receive(:fetch_from_tier).and_return([fresh])
    allow(MemePoolManager).to receive(:quality_filter) { |items| items }
    allow(MemePoolManager).to receive(:get_current_pool).and_return([old, fresh])
    allow(RedisService).to receive(:delete)
    expect(MemePoolManager).to receive(:store_in_pool).with([fresh, old]).and_return(2)
    expect(MemePoolManager.send(:fetch_batch, size: 100)[:stored]).to eq(2)
  end
end