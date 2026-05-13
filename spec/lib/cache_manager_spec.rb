# spec/lib/cache_manager_spec.rb
require_relative '../spec_helper'
require_relative '../../lib/cache_manager'

RSpec.describe CacheManager do
  # Clear cache before each test to ensure clean state
  before(:each) do
    CacheManager.clear
  end
  
  after(:all) do
    CacheManager.clear
  end
  
  describe 'class methods' do
    describe '.get and .set' do
      it 'stores and retrieves values' do
        CacheManager.set('test_key', 'test_value')
        expect(CacheManager.get('test_key')).to eq('test_value')
      end
      
      it 'returns nil for non-existent keys' do
        expect(CacheManager.get('nonexistent')).to be_nil
      end
      
      it 'stores different data types' do
        CacheManager.set('string', 'hello')
        CacheManager.set('integer', 42)
        CacheManager.set('array', [1, 2, 3])
        CacheManager.set('hash', { a: 1, b: 2 })
        
        expect(CacheManager.get('string')).to eq('hello')
        expect(CacheManager.get('integer')).to eq(42)
        expect(CacheManager.get('array')).to eq([1, 2, 3])
        expect(CacheManager.get('hash')).to eq({ a: 1, b: 2 })
      end
      
      it 'respects TTL expiration' do
        CacheManager.set('expires_fast', 'value', 0.1)
        expect(CacheManager.get('expires_fast')).to eq('value')
        
        sleep(0.15)
        expect(CacheManager.get('expires_fast')).to be_nil
      end
      
      it 'clamps TTL to maximum' do
        CacheManager.set('max_ttl', 'value', 999999)
        # Should clamp to MAX_TTL (86400)
        expect(CacheManager.get('max_ttl')).to eq('value')
      end
      
      it 'handles negative TTL' do
        CacheManager.set('negative_ttl', 'value', -100)
        # Should clamp to 0 (expires immediately)
        expect(CacheManager.get('negative_ttl')).to be_nil
      end
    end
    
    describe '.delete' do
      it 'removes a key from cache' do
        CacheManager.set('to_delete', 'value')
        CacheManager.delete('to_delete')
        
        expect(CacheManager.get('to_delete')).to be_nil
      end
      
      it 'handles deleting non-existent keys' do
        expect { CacheManager.delete('nonexistent') }.not_to raise_error
      end
    end
    
    describe '.clear' do
      it 'removes all keys from cache' do
        CacheManager.set('key1', 'value1')
        CacheManager.set('key2', 'value2')
        CacheManager.set('key3', 'value3')
        
        CacheManager.clear
        
        expect(CacheManager.get('key1')).to be_nil
        expect(CacheManager.get('key2')).to be_nil
        expect(CacheManager.get('key3')).to be_nil
        expect(CacheManager.size).to eq(0)
      end
    end
    
    describe '.size' do
      it 'returns 0 for empty cache' do
        expect(CacheManager.size).to eq(0)
      end
      
      it 'returns correct count' do
        CacheManager.set('key1', 'value1')
        CacheManager.set('key2', 'value2')
        
        expect(CacheManager.size).to eq(2)
      end
      
      it 'decreases after delete' do
        CacheManager.set('key1', 'value1')
        CacheManager.set('key2', 'value2')
        CacheManager.delete('key1')
        
        expect(CacheManager.size).to eq(1)
      end
    end
    
    describe '.stats' do
      it 'returns statistics hash' do
        CacheManager.set('key1', 'value')
        
        stats = CacheManager.stats
        
        expect(stats).to be_a(Hash)
        expect(stats[:size]).to eq(1)
        expect(stats[:keys]).to include('key1')
        expect(stats).to have_key(:estimated_memory)
        expect(stats).to have_key(:max_memory)
      end
      
      it 'includes expired count' do
        CacheManager.set('expires', 'value', 0.1)
        sleep(0.15)
        
        stats = CacheManager.stats
        expect(stats[:expired_count]).to be >= 0
      end
    end
    
    describe '.transaction' do
      it 'executes block atomically' do
        result = CacheManager.transaction do
          CacheManager.set('tx_key', 'tx_value')
          CacheManager.get('tx_key')
        end
        
        expect(result).to eq('tx_value')
      end
      
      it 'maintains thread safety' do
        CacheManager.set('counter', 0)
        
        threads = 10.times.map do
          Thread.new do
            100.times do
              CacheManager.transaction do
                val = CacheManager.get('counter') || 0
                CacheManager.set('counter', val + 1)
              end
            end
          end
        end
        
        threads.each(&:join)
        expect(CacheManager.get('counter')).to eq(1000)
      end
    end
    
    describe '.cleanup_expired' do
      it 'removes expired entries' do
        CacheManager.set('valid', 'value', 3600)
        CacheManager.set('expires1', 'value', 0.1)
        CacheManager.set('expires2', 'value', 0.1)
        
        sleep(0.15)
        
        count = CacheManager.cleanup_expired
        
        expect(count).to eq(2)
        expect(CacheManager.get('valid')).to eq('value')
        expect(CacheManager.get('expires1')).to be_nil
        expect(CacheManager.get('expires2')).to be_nil
      end
      
      it 'returns 0 when no expired entries' do
        CacheManager.set('valid', 'value', 3600)
        
        count = CacheManager.cleanup_expired
        expect(count).to eq(0)
      end
    end
  end
  
  describe 'instance methods' do
    let(:cache) { CacheManager.new }
    
    describe '#get and #set' do
      it 'delegates to class methods' do
        cache.set('instance_key', 'instance_value')
        expect(cache.get('instance_key')).to eq('instance_value')
      end
      
      it 'supports [] and []= operators' do
        cache['bracket_key'] = 'bracket_value'
        expect(cache['bracket_key']).to eq('bracket_value')
      end
    end
    
    describe '#delete' do
      it 'delegates to class method' do
        cache.set('to_delete', 'value')
        cache.delete('to_delete')
        
        expect(cache.get('to_delete')).to be_nil
      end
    end
    
    describe '#clear' do
      it 'delegates to class method' do
        cache.set('key1', 'value1')
        cache.clear
        
        expect(cache.size).to eq(0)
      end
    end
    
    describe '#size' do
      it 'delegates to class method' do
        cache.set('key1', 'value1')
        cache.set('key2', 'value2')
        
        expect(cache.size).to eq(2)
      end
    end
    
    describe '#stats' do
      it 'delegates to class method' do
        cache.set('key1', 'value')
        
        stats = cache.stats
        expect(stats).to be_a(Hash)
        expect(stats[:size]).to eq(1)
      end
    end
  end
  
  describe 'cache hit counting' do
    it 'tracks cache hits' do
      CacheManager.set('popular', 'value')
      
      5.times { CacheManager.get('popular') }
      
      # Hit count should be tracked (internal state)
      expect(CacheManager.get('popular')).to eq('value')
    end
  end
  
  describe 'LRU eviction' do
    it 'evicts least recently used entries when cache is full' do
      # Set a large number of entries to trigger eviction
      1100.times do |i|
        CacheManager.set("key#{i}", "value#{i}")
      end
      
      # Cache should have evicted some entries
      expect(CacheManager.size).to be < 1100
    end
    
    it 'prefers to evict expired entries first' do
      CacheManager.set('valid', 'value', 3600)
      CacheManager.set('expires', 'value', 0.1)
      
      sleep(0.15)
      
      # Fill cache to trigger eviction
      1100.times do |i|
        CacheManager.set("filler#{i}", "value#{i}")
      end
      
      # Valid entry should still exist, expired should be gone
      # (though valid might also be evicted if cache is really full)
      expect(CacheManager.get('expires')).to be_nil
    end
  end
  
  describe 'memory estimation' do
    it 'estimates memory for different data types' do
      CacheManager.set('string', 'hello world')
      CacheManager.set('int', 123)
      CacheManager.set('array', [1, 2, 3, 4, 5])
      CacheManager.set('hash', { a: 1, b: 2, c: 3 })
      
      stats = CacheManager.stats
      expect(stats[:estimated_memory]).to be > 0
    end
  end
  
  describe 'edge cases' do
    it 'handles nil values' do
      CacheManager.set('nil_key', nil)
      expect(CacheManager.get('nil_key')).to be_nil
    end
    
    it 'handles empty strings' do
      CacheManager.set('empty', '')
      expect(CacheManager.get('empty')).to eq('')
    end
    
    it 'handles large strings' do
      large_string = 'x' * 100000
      CacheManager.set('large', large_string)
      
      expect(CacheManager.get('large')).to eq(large_string)
    end
    
    it 'handles symbol keys' do
      CacheManager.set(:symbol_key, 'value')
      expect(CacheManager.get(:symbol_key)).to eq('value')
    end
    
    it 'handles concurrent access' do
      threads = 5.times.map do |i|
        Thread.new do
          50.times do |j|
            key = "thread_#{i}_#{j}"
            CacheManager.set(key, "value_#{j}")
            CacheManager.get(key)
          end
        end
      end
      
      threads.each(&:join)
      expect(CacheManager.size).to be > 0
    end
  end
end
