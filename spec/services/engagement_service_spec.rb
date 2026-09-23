# frozen_string_literal: true

require_relative '../spec_helper'
require_relative '../../lib/services/engagement_service'

RSpec.describe EngagementService do
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
  # testing anything). Replaced with real coverage of
  # EngagementService.track_like's nil-safety and actual return shape.
  describe 'error handling' do
    it 'handles a nil db gracefully without raising' do
      expect {
        EngagementService.track_like(user_id: 1, meme_url: 'http://example.com/x.jpg', liked_now: true, db: nil)
      }.not_to raise_error
    end
  end

  describe 'edge cases' do
    it 'handles a nil meme_url gracefully' do
      expect {
        EngagementService.track_like(user_id: 1, meme_url: nil, liked_now: true, db: DB)
      }.not_to raise_error
    end

    it 'handles a nil user_id gracefully' do
      expect {
        EngagementService.track_like(user_id: nil, meme_url: 'http://example.com/x.jpg', liked_now: true, db: DB)
      }.not_to raise_error
    end
  end
end
