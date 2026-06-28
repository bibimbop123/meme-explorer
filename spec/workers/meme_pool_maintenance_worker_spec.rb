# frozen_string_literal: true
require_relative '../spec_helper'
require_relative '../../app/workers/meme_pool_maintenance_worker'

RSpec.describe MemePoolMaintenanceWorker do
  let(:worker) { described_class.new }

  describe '#perform' do
    it 'executes without raising' do
      expect { worker.perform }.not_to raise_error
    end

    it 'handles MemePoolManager errors without re-raising' do
      allow(MemePoolManager).to receive(:maintain_pool!).and_raise(RuntimeError, 'pool error')
      expect { worker.perform }.not_to raise_error
    end
  end
end
