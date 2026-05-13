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
end
