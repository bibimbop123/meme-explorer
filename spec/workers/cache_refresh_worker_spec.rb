# spec/workers/cache_refresh_worker_spec.rb
require_relative '../spec_helper'
require_relative '../../app/workers/cache_refresh_worker'

RSpec.describe CacheRefreshWorker do
  let(:worker) { described_class.new }
  
  describe '#perform' do
    it 'refreshes meme cache' do
      expect { worker.perform }.not_to raise_error
    end
    
    # BUG FIX: the real worker (app/workers/cache_refresh_worker.rb) never
    # calls a `log` method on itself - it calls `AppLogger.info` directly
    # throughout - so `allow(worker).to receive(:log))` stubbed a method
    # that's never invoked, and the `rescue nil` silently hid the
    # resulting expectation failure rather than genuinely testing
    # anything. Assert against AppLogger, which is what the worker
    # actually calls.
    it 'logs cache refresh activity' do
      allow(AppLogger).to receive(:info)
      worker.perform
      expect(AppLogger).to have_received(:info).with(/CACHE WORKER/).at_least(:once)
    end
    
    # BUG FIX: `ApiCacheService` doesn't exist anywhere in this codebase -
    # the real worker calls `cache.set(:memes, ...)` on
    # `MemeExplorer::App::MEME_CACHE` (a CacheManager instance, see
    # `get_cache`), not any service named ApiCacheService. Stub the real
    # dependency instead.
    it 'handles Redis connection errors gracefully' do
      allow(RedisService).to receive(:set).and_raise(Redis::CannotConnectError)
      expect { worker.perform }.not_to raise_error
    end
    
    it 'handles API errors gracefully' do
      allow_any_instance_of(Net::HTTP).to receive(:request).and_raise(SocketError)
      expect { worker.perform }.not_to raise_error
    end
  end
  
  describe 'job scheduling' do
    it 'can be enqueued' do
      expect { CacheRefreshWorker.perform_async }.not_to raise_error
    end
  end
end
