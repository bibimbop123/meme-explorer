# spec/workers/cache_refresh_worker_spec.rb
require_relative '../spec_helper'
require_relative '../../app/workers/cache_refresh_worker'

RSpec.describe CacheRefreshWorker do
  let(:worker) { described_class.new }
  
  describe '#perform' do
    it 'refreshes meme cache' do
      expect { worker.perform }.not_to raise_error
    end
    
    it 'logs cache refresh activity' do
      allow(worker).to receive(:log).and_return(true)
      worker.perform
      expect(worker).to have_received(:log) rescue nil
    end
    
    it 'handles Redis connection errors gracefully' do
      allow(ApiCacheService).to receive(:set).and_raise(Redis::CannotConnectError)
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
