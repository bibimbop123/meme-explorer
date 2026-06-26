require 'spec_helper'
require_relative '../../lib/concerns/transaction_wrapper'

RSpec.describe TransactionWrapper do
  let(:test_class) do
    Class.new do
      include TransactionWrapper
      
      def perform_transaction
        with_transaction do
          # Simulate database operations
          true
        end
      end
    end
  end

  let(:instance) { test_class.new }

  describe '#with_transaction' do
    it 'wraps block in transaction' do
      expect(instance.perform_transaction).to be true
    end

    it 'logs transaction start and completion' do
      expect(AppLogger).to receive(:info).with(/transaction_started/, anything)
      expect(AppLogger).to receive(:info).with(/transaction_committed/, anything)
      instance.perform_transaction
    end
  end
end
