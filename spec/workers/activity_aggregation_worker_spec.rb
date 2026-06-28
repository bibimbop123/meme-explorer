# frozen_string_literal: true
require_relative '../spec_helper'
require_relative '../../app/workers/activity_aggregation_worker'

RSpec.describe ActivityAggregationWorker do
  let(:worker) { described_class.new }

  describe '#perform' do
    it 'executes without raising' do
      expect { worker.perform }.not_to raise_error
    end

    it 'handles Redis errors gracefully' do
      allow(ActivityTrackerService).to receive(:aggregate_stats)
        .and_raise(Redis::CannotConnectError)
      expect { worker.perform }.not_to raise_error
    end
  end
end
