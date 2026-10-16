require_relative '../spec_helper'
require_relative '../../lib/services/api_cache_service'

RSpec.describe 'API meme cache recovery' do
  let(:service) { ApiCacheService }
  let(:redis) { double('isolated Redis') }
  let(:memes) { [{ 'url' => 'https://i.redd.it/backup.jpg', 'title' => 'Backup' }] }

  around do |example|
    backup = service.memory_lock.synchronize { service.memory_cache.dup }
    example.run
  ensure
    service.memory_lock.synchronize { service.memory_cache.replace(backup) }
  end

  before do
    allow(service).to receive(:redis).and_return(redis)
    service.memory_lock.synchronize do
      service.memory_cache.delete('api_memes:latest')
      service.memory_cache.delete('api_memes:timestamp')
    end
  end

  it 'keeps a memory backup when Redis writes fail' do
    allow(redis).to receive(:setex).and_raise(Redis::CannotConnectError)
    allow(redis).to receive(:get).and_raise(Redis::CannotConnectError)
    expect(service.set_cached_memes(memes)).to eq(true)
    expect(service.get_cached_memes).to eq(memes)
    expect(service.cache_age).to be_between(0, 2)
  end

  it 'recovers a memory backup from corrupt or wrong-shaped Redis payloads' do
    allow(redis).to receive(:setex)
    service.set_cached_memes(memes)
    ['invalid JSON', '{}', '[]', 'null'].each do |payload|
      allow(redis).to receive(:get).with('cache:api_memes:latest').and_return(payload)
      expect(service.get_cached_memes).to eq(memes)
    end
  end

  it 'returns nil rather than inventing content when all caches miss' do
    allow(redis).to receive(:get).and_return(nil)
    expect(service.get_cached_memes).to be_nil
    expect(service.cache_age).to be_nil
    expect(service.cache_fresh?).to be_nil
  end

  it 'does not overwrite existing content with empty or invalid refresh data' do
    allow(redis).to receive(:setex)
    service.set_cached_memes(memes)
    [nil, {}, []].each { |value| expect(service.set_cached_memes(value)).to eq(false) }
    allow(redis).to receive(:get).and_return(nil)
    expect(service.get_cached_memes).to eq(memes)
  end

  it 'refreshes at the five-minute-before-expiry boundary' do
    now = Time.utc(2026, 10, 15, 12)
    allow(Time).to receive(:now).and_return(now)
    allow(redis).to receive(:get).with('cache:api_memes:timestamp').and_return(
      (now.to_i - 3299).to_s, (now.to_i - 3300).to_s
    )
    expect(service.cache_fresh?).to eq(true)
    expect(service.cache_fresh?).to eq(false)
  end

  it 'sorts valid content by quality and bounds publication to 200 memes' do
    candidates = 205.times.map do |index|
      { 'url' => "https://i.redd.it/#{index}.jpg", 'likes' => 100, 'upvote_ratio' => 0.9, 'quality_score' => index }
    end
    result = service.send(:validate_and_filter_quality_memes, candidates)
    expect(result.size).to eq(200)
    expect(result.first['quality_score']).to eq(204)
    expect(result.last['quality_score']).to eq(5)
    expect(service.send(:calculate_quality_score, 200, 10, 0.8)).to eq(427.5)
    expect(service.send(:calculate_quality_score, 100, 10, 0.8)).to eq(185.0)
  end
end