# frozen_string_literal: true

require_relative '../spec_helper'
require_relative '../../lib/services/activity_tracker_service'

# BUG FIX: this file was a generic, unfinished template - it called
# `described_class.new` on `ActivityTrackerService`, but the real service
# (lib/services/activity_tracker_service.rb) is a module with `class << self`
# class methods, not an instantiable class - it's an intentional no-op
# STUB, replacing a real tracking service "removed during Elon audit" per
# its own header comment, kept only so callers (app.rb's `after` filter,
# routes/admin_inline_routes.rb's `/api/activity-stats`) don't raise
# NoMethodError. The remaining three examples were empty `pending`
# placeholders that fail because `pending` expects the block to fail and
# an empty block trivially "passes." Rewritten to actually test the real,
# intentional stub behavior: every method is a safe no-op that never
# raises, regardless of input.
RSpec.describe ActivityTrackerService do
  describe '.record_action' do
    it 'is a safe no-op that returns true' do
      expect(ActivityTrackerService.record_action('like', 123)).to eq(true)
    end

    it 'handles nil user_id without raising' do
      expect { ActivityTrackerService.record_action('like', nil) }.not_to raise_error
    end

    it 'handles nil action_type without raising' do
      expect { ActivityTrackerService.record_action(nil, 123) }.not_to raise_error
    end
  end

  describe '.mark_active' do
    it 'is a safe no-op that returns true' do
      expect(ActivityTrackerService.mark_active('visitor-abc', '127.0.0.1')).to eq(true)
    end

    it 'handles nil visitor_id without raising' do
      expect { ActivityTrackerService.mark_active(nil) }.not_to raise_error
    end

    it 'handles a missing ip_address (optional arg)' do
      expect { ActivityTrackerService.mark_active('visitor-abc') }.not_to raise_error
    end
  end

  describe '.stats' do
    it 'reports tracking as disabled rather than faking live numbers' do
      result = ActivityTrackerService.stats
      expect(result[:active_users]).to eq(0)
      expect(result[:viewing_users]).to eq(0)
      expect(result[:redis_available]).to eq(false)
    end
  end

  describe '.aggregate_stats' do
    it 'is a safe no-op that returns true' do
      expect(ActivityTrackerService.aggregate_stats).to eq(true)
    end
  end
end
