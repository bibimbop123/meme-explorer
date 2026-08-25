# frozen_string_literal: true

require_relative '../spec_helper'
require_relative '../../lib/services/meme_pool_manager'
require 'benchmark'

RSpec.describe MemePoolManager do
  describe 'initialization' do
    it 'initializes successfully' do
      expect { described_class.new }.not_to raise_error
    end
  end

  describe '.get_pool' do
    after do
      # Don't leak lock/cooldown state between examples.
      RedisService.delete(MemePoolManager::BOOTSTRAP_LOCK_KEY)
      RedisService.delete(MemePoolManager::BOOTSTRAP_COOLDOWN_KEY)
    end

    it 'returns the cached pool immediately when one already exists' do
      allow(described_class).to receive(:get_current_pool).and_return([{ 'url' => 'a' }, { 'url' => 'b' }])

      result = described_class.get_pool

      expect(result[:success]).to eq(true)
      expect(result[:memes].size).to eq(2)
    end

    it 'returns a fast, non-blocking fallback when the pool is empty and cooling down' do
      allow(described_class).to receive(:get_current_pool).and_return([])
      allow(RedisService).to receive(:get).with(MemePoolManager::BOOTSTRAP_COOLDOWN_KEY).and_return('true')

      result = described_class.get_pool

      expect(result[:success]).to eq(false)
      expect(result[:memes]).to eq([])
    end

    # Regression test for the production incident (Aug 25, 2026) where every
    # request that lost the bootstrap-lock race blocked for up to 15 seconds
    # (BOOTSTRAP_WAIT_RETRIES x BOOTSTRAP_WAIT_INTERVAL) before falling back,
    # causing every page load to take ~15s and risking Puma thread pool
    # exhaustion under any real traffic. Followers must now return almost
    # immediately instead of blocking the request thread.
    it 'returns quickly instead of blocking when another request is already bootstrapping' do
      allow(described_class).to receive(:get_current_pool).and_return([])
      allow(RedisService).to receive(:get).with(MemePoolManager::BOOTSTRAP_COOLDOWN_KEY).and_return(nil)
      # Simulate someone else already holding the lock.
      allow(RedisService).to receive(:acquire_lock).with(MemePoolManager::BOOTSTRAP_LOCK_KEY, ttl: MemePoolManager::BOOTSTRAP_LOCK_TTL).and_return(false)

      elapsed = Benchmark.realtime { described_class.get_pool }

      # Old behavior could block up to BOOTSTRAP_WAIT_RETRIES * BOOTSTRAP_WAIT_INTERVAL (15s).
      # New behavior should return well under 1 second.
      expect(elapsed).to be < 1.0
    end

    it 'does not block the calling request while bootstrapping in the background' do
      allow(described_class).to receive(:get_current_pool).and_return([])
      allow(RedisService).to receive(:get).with(MemePoolManager::BOOTSTRAP_COOLDOWN_KEY).and_return(nil)
      allow(RedisService).to receive(:acquire_lock).with(MemePoolManager::BOOTSTRAP_LOCK_KEY, ttl: MemePoolManager::BOOTSTRAP_LOCK_TTL).and_return(true)

      # Make bootstrap_pool artificially slow to prove get_pool doesn't wait on it.
      allow(described_class).to receive(:bootstrap_pool) do
        sleep 2
        { success: true, size: 1, memes: [{ 'url' => 'fresh' }], error: nil }
      end
      allow(RedisService).to receive(:delete)

      elapsed = Benchmark.realtime { @result = described_class.get_pool }

      expect(elapsed).to be < 1.0
      expect(@result[:success]).to eq(false)
      expect(@result[:memes]).to eq([])
    end
  end
end

