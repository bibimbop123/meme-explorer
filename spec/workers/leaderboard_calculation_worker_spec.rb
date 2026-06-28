# frozen_string_literal: true
require_relative '../spec_helper'
require_relative '../../app/workers/leaderboard_calculation_worker'

RSpec.describe LeaderboardCalculationWorker do
  let(:worker) { described_class.new }

  describe '#perform' do
    it 'executes without raising' do
      expect { worker.perform }.not_to raise_error
    end

    it 'handles empty user set without error' do
      allow(DB).to receive(:execute).with(/ user_levels/, any_args).and_return([])
      allow(DB).to receive(:execute).and_call_original
      expect { worker.perform }.not_to raise_error
    end

    it 'handles database errors gracefully' do
      allow(DB).to receive(:execute).and_raise(PG::Error, 'connection lost')
      expect { worker.perform }.not_to raise_error
    end
  end

  describe 'Sidekiq configuration' do
    it 'uses the critical queue' do
      expect(described_class.sidekiq_options_hash['queue'].to_s).to eq('critical')
    end
    it 'is configured with retries' do
      expect(described_class.sidekiq_options_hash['retry']).to be > 0
    end
  end
end
