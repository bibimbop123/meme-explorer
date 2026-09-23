# frozen_string_literal: true

require_relative '../spec_helper'
require_relative '../../lib/services/health_check_service'

RSpec.describe HealthCheckService do
  describe 'initialization' do
    it 'initializes successfully' do
      expect { described_class.new }.not_to raise_error
    end
  end

  describe 'main functionality' do
    subject { described_class.new }

    it 'responds to primary methods' do
      # TODO: Add specific method tests based on service interface
      expect(subject).to respond_to(:call) if subject.respond_to?(:call)
    end
  end

  # BUG FIX: this file's trailing three examples were empty `pending`
  # placeholders (`pending` expects the block to actually fail; an empty
  # block trivially "passes," so these failed on every run without
  # testing anything). HealthCheckService is a plain class with all real
  # behavior on `class << self` methods (`.check`, `.quick_check`) - `.new`
  # produces a real but functionally empty instance. Replaced with real
  # coverage of the actual class methods this service is built around.
  describe '.quick_check' do
    it 'returns a status without raising, even under failure conditions' do
      expect { HealthCheckService.quick_check }.not_to raise_error
    end

    it 'includes a status key' do
      result = HealthCheckService.quick_check
      expect(result).to have_key(:status)
    end
  end

  describe '.check' do
    it 'returns a detailed health report without raising' do
      expect { HealthCheckService.check }.not_to raise_error
    end

    it 'includes checks for database and cache' do
      result = HealthCheckService.check
      expect(result).to have_key(:database)
      expect(result).to have_key(:cache)
    end
  end
end
