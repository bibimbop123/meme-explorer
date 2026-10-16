# spec/services/api_cache_service_spec.rb
require_relative '../spec_helper'
require_relative '../../lib/services/api_cache_service'

RSpec.describe ApiCacheService do
  let(:service) { described_class }
  let(:test_key) { 'test_key' }
  let(:test_data) { {data: 'test_value', count: 42} }
  
  before(:each) do
    # Clear Redis cache before each test
    service.redis.flushdb rescue nil
  end
  
  describe '.set' do
    context 'with valid data' do
      it 'stores data in Redis' do
        service.set(test_key, test_data)
        retrieved = service.get(test_key)
        expect(retrieved).to eq(test_data)
      end
      
      it 'sets default TTL' do
        service.set(test_key, test_data)
        ttl = service.redis.ttl("cache:#{test_key}")
        expect(ttl).to be > 0
        expect(ttl).to be <= 3600  # Default TTL matches CACHE_TTL constant
      end
      
      it 'respects custom TTL' do
        service.set(test_key, test_data, ttl: 60)
        ttl = service.redis.ttl("cache:#{test_key}")
        expect(ttl).to be > 0
        expect(ttl).to be <= 60
      end
    end
    
    context 'with nil data' do
      it 'does not store nil values' do
        service.set(test_key, nil)
        expect(service.get(test_key)).to be_nil
      end
    end
    
    context 'with empty data' do
      it 'stores empty arrays' do
        service.set(test_key, [])
        expect(service.get(test_key)).to eq([])
      end
      
      it 'stores empty hashes' do
        service.set(test_key, {})
        expect(service.get(test_key)).to eq({})
      end
    end
  end
  
  describe '.get' do
    context 'with existing key' do
      before do
        service.set(test_key, test_data)
      end
      
      it 'retrieves cached data' do
        result = service.get(test_key)
        expect(result).to eq(test_data)
      end
      
      it 'returns symbolized keys for hashes' do
        result = service.get(test_key)
        expect(result.keys).to all(be_a(Symbol))
      end
    end
    
    context 'with non-existent key' do
      it 'returns nil' do
        expect(service.get('nonexistent')).to be_nil
      end
    end
    
    context 'with expired key' do
      it 'returns nil for expired data' do
        service.set(test_key, test_data, ttl: 1)
        sleep 2
        expect(service.get(test_key)).to be_nil
      end
    end
  end
  
  describe '.delete' do
    before do
      service.set(test_key, test_data)
    end
    
    it 'removes cached data' do
      service.delete(test_key)
      expect(service.get(test_key)).to be_nil
    end
    
    it 'returns true on successful deletion' do
      expect(service.delete(test_key)).to be_truthy
    end
    
    it 'handles non-existent keys gracefully' do
      expect { service.delete('nonexistent') }.not_to raise_error
    end
  end
  
  describe '.clear_pattern' do
    before do
      service.set('user:1:data', {id: 1})
      service.set('user:2:data', {id: 2})
      service.set('meme:1:data', {id: 1})
    end
    
    it 'deletes keys matching pattern' do
      service.clear_pattern('user:*')
      expect(service.get('user:1:data')).to be_nil
      expect(service.get('user:2:data')).to be_nil
      expect(service.get('meme:1:data')).not_to be_nil
    end
    
    it 'returns count of deleted keys' do
      count = service.clear_pattern('user:*')
      expect(count).to eq(2)
    end
  end
  
  describe '.exists?' do
    context 'with existing key' do
      before do
        service.set(test_key, test_data)
      end
      
      it 'returns true' do
        expect(service.exists?(test_key)).to be true
      end
    end
    
    context 'with non-existent key' do
      it 'returns false' do
        expect(service.exists?('nonexistent')).to be false
      end
    end
  end
  
  describe '.increment' do
    it 'increments a counter' do
      service.increment('view_count')
      service.increment('view_count')
      expect(service.get('view_count')).to eq(2)
    end
    
    it 'increments by custom amount' do
      service.increment('like_count', by: 5)
      expect(service.get('like_count')).to eq(5)
    end
  end
  
  describe '.cache_or_fetch' do
    let(:expensive_operation) { -> { {computed: Time.now.to_i} } }
    
    it 'returns cached value if exists' do
      service.set(test_key, test_data)
      result = service.cache_or_fetch(test_key) { expensive_operation.call }
      expect(result).to eq(test_data)
    end
    
    it 'executes block and caches result if not cached' do
      result = service.cache_or_fetch(test_key) { expensive_operation.call }
      expect(result).to have_key(:computed)
      expect(service.get(test_key)).to eq(result)
    end
    
    it 'only executes block once for multiple calls' do
      call_count = 0
      block = -> { call_count += 1; {count: call_count} }
      
      result1 = service.cache_or_fetch(test_key) { block.call }
      result2 = service.cache_or_fetch(test_key) { block.call }
      
      expect(result1).to eq(result2)
      expect(call_count).to eq(1)
    end
  end
  
  describe 'error handling' do
    context 'when Redis is unavailable' do
      before do
        allow(service).to receive(:redis).and_raise(Redis::CannotConnectError)
      end
      
      it 'handles connection errors gracefully' do
        expect { service.get(test_key) }.not_to raise_error
        expect(service.get(test_key)).to be_nil
      end
    end
  end

  describe 'memory fallback TTL and invalidation' do
    let(:prefix) { "fallback-#{SecureRandom.hex(8)}" }

    before { allow(service).to receive(:redis).and_return(nil) }
    after { service.clear_pattern("#{prefix}*") }

    it 'expires reads and existence checks without background threads' do
      service.set(prefix, { value: 'temporary' }, ttl: 10)
      expect(service.get(prefix)).to eq(value: 'temporary')
      future = Time.now + 11
      allow(Time).to receive(:now).and_return(future)
      expect(service.get(prefix)).to be_nil
      expect(service.exists?(prefix)).to be false
    end

    it 'keeps explicit non-expiring entries and clears an old expiry when overwritten' do
      service.set(prefix, 1, ttl: 1)
      service.set(prefix, 2, ttl: nil)
      future = Time.now + 100
      allow(Time).to receive(:now).and_return(future)
      expect(service.get(prefix)).to eq(2)
    end

    it 'starts an expired counter from zero' do
      service.set(prefix, 20, ttl: 1)
      future = Time.now + 2
      allow(Time).to receive(:now).and_return(future)
      expect(service.increment(prefix, by: 3)).to eq(3)
    end

    it 'honors internal wildcards rather than deleting unrelated prefixes' do
      service.set("#{prefix}:one:data", 1)
      service.set("#{prefix}:two:data", 2)
      service.set("#{prefix}:one:other", 3)
      expect(service.clear_pattern("#{prefix}:*:data")).to eq(2)
      expect(service.get("#{prefix}:one:data")).to be_nil
      expect(service.get("#{prefix}:one:other")).to eq(3)
    end

    it 'removes memory fallback data even after Redis recovers' do
      service.set(prefix, 'stale')
      redis = double('redis', scan_each: [].each)
      allow(service).to receive(:redis).and_return(redis)
      service.clear_pattern("#{prefix}*")
      allow(service).to receive(:redis).and_return(nil)
      expect(service.get(prefix)).to be_nil
    end
  end

  describe 'bounded Redis invalidation' do
    it 'streams scan results into bounded deletion batches' do
      keys = 451.times.map { |index| "cache:batch-spec:#{index}" }
      redis = double('redis')
      allow(service).to receive(:redis).and_return(redis)
      expect(redis).to receive(:scan_each).with(match: 'cache:batch-spec:*').and_return(keys.each)
      batches = []
      allow(redis).to receive(:del) do |*batch|
        batches << batch.size
        batch.size
      end
      expect(service.clear_pattern('batch-spec:*')).to eq(451)
      expect(batches).to eq([200, 200, 51])
    end

    it 'counts actual removals rather than duplicate scan results' do
      redis = double('redis')
      allow(service).to receive(:redis).and_return(redis)
      allow(redis).to receive(:scan_each).and_return(['cache:duplicate-spec:1', 'cache:duplicate-spec:1'].each)
      expect(redis).to receive(:del).with('cache:duplicate-spec:1', 'cache:duplicate-spec:1').and_return(1)
      expect(service.clear_pattern('duplicate-spec:*')).to eq(1)
    end

    it 'still invalidates memory when a Redis deletion batch fails' do
      allow(service).to receive(:redis).and_return(nil)
      service.set('batch-failure-spec:item', 'stale')
      redis = double('redis', scan_each: ['cache:batch-failure-spec:item'].each)
      allow(redis).to receive(:del).and_raise(Redis::CannotConnectError)
      allow(service).to receive(:redis).and_return(redis)
      expect(service.clear_pattern('batch-failure-spec:*')).to eq(1)
      allow(service).to receive(:redis).and_return(nil)
      expect(service.get('batch-failure-spec:item')).to be_nil
    end
  end

  describe 'refresh lease ownership' do
    it 'returns the existing cache when a completed fetch has lost publication ownership' do
      lease = { token: 'expired-owner', redis: nil }
      existing = [{ 'url' => '/current-cache.jpg' }]
      fetched = [{ 'url' => '/late-fetch.jpg' }]
      allow(service).to receive(:cache_fresh?).and_return(false)
      allow(service).to receive(:acquire_lock).and_return(lease)
      allow(service).to receive(:fetch_reddit_memes_unauthenticated).and_return(fetched)
      allow(service).to receive(:validate_and_filter_quality_memes).with(fetched).and_return(fetched)
      expect(service).to receive(:publish_refreshed_memes).with(fetched, lease).and_return(false)
      allow(service).to receive(:get_cached_memes).and_return(existing)
      expect(service).to receive(:release_lock).with(lease)
      expect(service.fetch_and_cache_memes(['funny'])).to eq(existing)
    end

    it 'atomically publishes only the current Redis owners content and timestamp' do
      first = service.acquire_lock
      service.redis.pexpire('cache:api_memes:lock', 0)
      second = service.acquire_lock
      fresh = [{ 'url' => '/successor.jpg' }]
      expect(service.publish_refreshed_memes(fresh, second)).to be true
      expect(service.publish_refreshed_memes([{ 'url' => '/expired.jpg' }], first)).to be false
      expect(service.get_cached_memes).to eq(fresh)
      expect(service.cache_age).to be_between(0, 2)
      service.release_lock(second)
    end

    it 'rejects expired memory publication without overwriting the successor' do
      allow(service).to receive(:redis).and_return(nil)
      first = service.acquire_lock
      future = Time.now + described_class::LOCK_TTL + 1
      allow(Time).to receive(:now).and_return(future)
      expect(service.publish_refreshed_memes([{ 'url' => '/expired.jpg' }], first)).to be false
      second = service.acquire_lock
      fresh = [{ 'url' => '/memory-successor.jpg' }]
      expect(service.publish_refreshed_memes(fresh, second)).to be true
      expect(service.publish_refreshed_memes([{ 'url' => '/expired.jpg' }], first)).to be false
      expect(service.get_cached_memes).to eq(fresh)
      service.release_lock(second)
    end

    it 'does not let an expired Redis owner release its successor' do
      first = service.acquire_lock
      expect(first[:token]).to be_a(String)
      expect(service.acquire_lock).to be false
      service.redis.pexpire('cache:api_memes:lock', 0)
      second = service.acquire_lock
      expect(service.release_lock(first)).to be false
      expect(service.redis.get('cache:api_memes:lock')).to eq(second[:token])
      expect(service.release_lock(second)).to be true
    end

    it 'protects memory ownership after lease expiry and Redis recovery' do
      allow(service).to receive(:redis).and_return(nil)
      first = service.acquire_lock
      expect(service.acquire_lock).to be false
      future = Time.now + described_class::LOCK_TTL + 1
      allow(Time).to receive(:now).and_return(future)
      second = service.acquire_lock
      expect(service.release_lock(first)).to be false
      # Release must use the original backend, not delete a recovered Redis key.
      allow(service).to receive(:redis).and_return(double('recovered redis'))
      expect(service.release_lock(second)).to be true
    end

    it 'returns existing cache to a follower without another upstream fetch' do
      allow(service).to receive(:cache_fresh?).and_return(false)
      allow(service).to receive(:acquire_lock).and_return(false)
      allow(service).to receive(:get_cached_memes).and_return([{ 'url' => '/stale.jpg' }])
      expect(service).not_to receive(:fetch_reddit_memes_unauthenticated)
      expect(service.fetch_and_cache_memes(['funny'])).to eq([{ 'url' => '/stale.jpg' }])
    end

    it 'returns fresh cached content without acquiring a lease' do
      allow(service).to receive(:cache_fresh?).and_return(true)
      allow(service).to receive(:get_cached_memes).and_return([{ 'url' => '/fresh.jpg' }])
      expect(service).not_to receive(:acquire_lock)
      expect(service.fetch_and_cache_memes(['funny'])).to eq([{ 'url' => '/fresh.jpg' }])
    end
  end

  describe 'refresh outcome contracts' do
    let(:lease) { { token: 'test-owner', redis: nil } }
    let(:existing) { [{ 'url' => '/cached.jpg' }] }
    let(:fresh) { [{ 'url' => 'https://i.redd.it/fresh.jpg', 'likes' => 100, 'upvote_ratio' => 0.9, 'quality_score' => 200 }] }

    around do |example|
      saved = ENV.values_at('REDDIT_CLIENT_ID', 'REDDIT_CLIENT_SECRET')
      ENV['REDDIT_CLIENT_ID'] = ''
      ENV['REDDIT_CLIENT_SECRET'] = ''
      example.run
    ensure
      ENV['REDDIT_CLIENT_ID'], ENV['REDDIT_CLIENT_SECRET'] = saved
    end

    before do
      allow(service).to receive(:cache_fresh?).and_return(false)
      allow(service).to receive(:acquire_lock).and_return(lease)
      allow(service).to receive(:get_cached_memes).and_return(existing)
      expect(service).to receive(:release_lock).with(lease)
    end

    it 'validates and publishes successful content' do
      allow(service).to receive(:fetch_reddit_memes_unauthenticated).and_return(fresh)
      expect(service).to receive(:publish_refreshed_memes).with(fresh, lease).and_return(true)
      expect(service.fetch_and_cache_memes(['funny'])).to eq(fresh)
    end

    [Timeout::Error, SocketError].each do |error|
      it "preserves existing content and releases ownership after #{error}" do
        allow(service).to receive(:fetch_reddit_memes_unauthenticated).and_raise(error)
        expect(service).not_to receive(:publish_refreshed_memes)
        expect(service.fetch_and_cache_memes(['funny'])).to eq(existing)
      end
    end

    it 'does not publish empty upstream results' do
      allow(service).to receive(:fetch_reddit_memes_unauthenticated).and_return([])
      expect(service).not_to receive(:publish_refreshed_memes)
      expect(service.fetch_and_cache_memes(['funny'])).to eq(existing)
    end

    it 'does not publish content rejected by quality validation' do
      allow(service).to receive(:fetch_reddit_memes_unauthenticated).and_return([{ 'url' => 'javascript:bad', 'likes' => 100 }])
      expect(service).not_to receive(:publish_refreshed_memes)
      expect(service.fetch_and_cache_memes(['funny'])).to eq(existing)
    end
  end

  describe 'media quality validation' do
    it 'rejects malformed entries and media-host lookalikes' do
      base = { 'likes' => 100, 'upvote_ratio' => 0.9, 'quality_score' => 10 }
      candidates = [nil, 12, base.merge('url' => 'https://i.redd.it.attacker.example/page'),
        base.merge('url' => 'https://user:secret@i.redd.it/a.jpg'),
        base.merge('url' => 'https://i.redd.it/valid.jpg')]
      expect(service.send(:validate_and_filter_quality_memes, candidates)).to eq([candidates.last])
    end
  end
end
