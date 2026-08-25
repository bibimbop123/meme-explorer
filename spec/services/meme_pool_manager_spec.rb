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

  describe '.create_fetcher (private)' do
    around do |example|
      original_id = ENV['REDDIT_CLIENT_ID']
      original_secret = ENV['REDDIT_CLIENT_SECRET']
      example.run
      ENV['REDDIT_CLIENT_ID'] = original_id
      ENV['REDDIT_CLIENT_SECRET'] = original_secret
    end

    # Regression test for the production incident (Aug 25, 2026) where
    # render.yaml set REDDIT_CLIENT_ID/SECRET via `value: ${REDDIT_CLIENT_ID}`
    # - which Render Blueprints do NOT shell-interpolate, so the app received
    # the literal placeholder string as a "configured" credential, attempted
    # (and always failed) OAuth, and silently degraded to the unauthenticated,
    # heavily rate-limited Reddit endpoint - resulting in only the 10-meme
    # local fallback pool ever being served (API memes never rendered).
    it 'treats unresolved placeholder-style credentials as absent and falls back to static auth' do
      ENV['REDDIT_CLIENT_ID'] = '${REDDIT_CLIENT_ID}'
      ENV['REDDIT_CLIENT_SECRET'] = '${REDDIT_CLIENT_SECRET}'

      expect(OAuth2::Client).not_to receive(:new) if defined?(OAuth2::Client)

      fetcher = described_class.send(:create_fetcher)
      expect(fetcher.instance_variable_get(:@auth_strategy)).to eq(:static)
    end

    it 'uses static auth when credentials are genuinely absent' do
      ENV['REDDIT_CLIENT_ID'] = ''
      ENV['REDDIT_CLIENT_SECRET'] = ''

      fetcher = described_class.send(:create_fetcher)
      expect(fetcher.instance_variable_get(:@auth_strategy)).to eq(:static)
    end
  end
end

