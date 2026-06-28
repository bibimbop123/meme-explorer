# frozen_string_literal: true
require_relative '../spec_helper'
require_relative '../../app/workers/meme_pool_refresh_worker'

RSpec.describe MemePoolRefreshWorker do
  let(:worker) { described_class.new }

  describe '#perform' do
    it 'executes without raising' do
      expect { worker.perform }.not_to raise_error
    end

    it 'handles Reddit API failure gracefully' do
      allow(RedditFetcherService).to receive(:new).and_raise(RuntimeError, 'API down')
      expect { worker.perform }.not_to raise_error
    end
  end

  describe 'Sidekiq configuration' do
    it 'includes Sidekiq::Worker' do
      expect(described_class.ancestors).to include(Sidekiq::Worker)
    end
  end
end
