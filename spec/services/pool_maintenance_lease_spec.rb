require_relative '../spec_helper'
require_relative '../../lib/services/meme_pool_manager'

RSpec.describe 'Pool maintenance lease' do
  let(:key) { MemePoolManager::MAINTENANCE_LOCK_KEY }

  before do
    allow(RedisService).to receive(:get).with(MemePoolManager::BOOTSTRAP_COOLDOWN_KEY).and_return(nil)
    allow(MemePoolManager).to receive(:get_pool_size).and_return(100)
  end

  after do
    RedisService.delete(key)
  end

  it 'skips a duplicate job before fetching and does not release the active owner' do
    owner = RedisService.acquire_lock(key, ttl: 60)
    expect(owner).to be_a(String)
    expect(MemePoolManager).not_to receive(:fetch_batch)
    expect(RedisService).not_to receive(:release_lock)
    expect(MemePoolManager.maintain_pool!).to include(success: false, error: 'Maintenance already running or Redis unavailable')
    expect(RedisService.with_redis { |redis| redis.get(key) }).to eq(owner)
  end

  it 'releases its lease after successful maintenance' do
    expect(MemePoolManager).to receive(:fetch_batch).with(size: 1000, priority: :high).and_return(stored: 100)
    expect(MemePoolManager.maintain_pool!).to include(success: true)
    expect(RedisService.with_redis { |redis| redis.get(key) }).to be_nil
  end

  it 'releases its lease after an unexpected failure' do
    allow(MemePoolManager).to receive(:fetch_batch).and_raise('Fetch failed')
    expect(MemePoolManager.maintain_pool!).to include(success: false, error: 'Fetch failed')
    expect(RedisService.with_redis { |redis| redis.get(key) }).to be_nil
  end

  it 'does not acquire a lease while cooling down' do
    allow(RedisService).to receive(:get).with(MemePoolManager::BOOTSTRAP_COOLDOWN_KEY).and_return('true')
    expect(RedisService).not_to receive(:acquire_lock)
    expect(MemePoolManager).not_to receive(:fetch_batch)
    expect(MemePoolManager.maintain_pool!).to include(success: false, error: 'Cooling down after recent rate limit')
  end

  it 'rechecks cooldown after acquiring the lease and releases it on early return' do
    allow(RedisService).to receive(:get).with(MemePoolManager::BOOTSTRAP_COOLDOWN_KEY).and_return(nil, 'true')
    expect(MemePoolManager).not_to receive(:fetch_batch)
    expect(MemePoolManager.maintain_pool!).to include(success: false, error: 'Cooling down after recent rate limit')
    expect(RedisService.with_redis { |redis| redis.get(key) }).to be_nil
  end

  it 'does not delete a successor lease if the original lease expired' do
    allow(MemePoolManager).to receive(:fetch_batch) do
      RedisService.with_redis { |redis| redis.set(key, 'successor-owner', ex: 60) }
      { stored: 100 }
    end
    expect(MemePoolManager.maintain_pool!).to include(success: true)
    expect(RedisService.with_redis { |redis| redis.get(key) }).to eq('successor-owner')
  end
end