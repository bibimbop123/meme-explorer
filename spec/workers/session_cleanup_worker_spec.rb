# frozen_string_literal: true
require_relative '../spec_helper'
require_relative '../../app/workers/session_cleanup_worker'

RSpec.describe SessionCleanupWorker do
  let(:worker) { described_class.new }

  describe '#perform' do
    it 'executes without raising' do
      expect { worker.perform }.not_to raise_error
    end

    it 'returns a stats hash or nil' do
      result = worker.perform
      expect([Hash, NilClass]).to include(result.class)
    end

    it 'handles SessionTrackerService redis errors without re-raising' do
      allow(SessionTrackerService).to receive(:cleanup_expired_sessions!)
        .and_raise(Redis::CannotConnectError, 'Redis down')
      expect { worker.perform }.not_to raise_error
    end
  end

  describe 'Sidekiq configuration' do
    it 'uses the default queue' do
      expect(described_class.sidekiq_options_hash['queue'].to_s).to eq('default')
    end
  end
end
