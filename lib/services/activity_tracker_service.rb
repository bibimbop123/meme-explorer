# Stub ActivityTrackerService for graceful degradation
# Original service removed during Elon audit
# This stub prevents errors while maintaining API compatibility

module ActivityTrackerService
  class << self
    def record_action(action_type, user_id)
      # No-op: Activity tracking disabled
      AppLogger.debug("ActivityTrackerService stub called: #{action_type} for user #{user_id}")
      true
    rescue => e
      AppLogger.warn("ActivityTrackerService stub error: #{e.message}")
      false
    end

    def mark_active(visitor_id, ip_address = nil)
      # No-op: Activity tracking disabled
      true
    rescue => e
      false
    end

    def stats
      {
        active_users: 0,
        viewing_users: 0,
        redis_available: false,
        note: 'Activity tracking disabled'
      }
    rescue => e
      {
        active_users: 0,
        viewing_users: 0,
        redis_available: false,
        error: e.message
      }
    end

    def aggregate_stats
      # No-op: Activity tracking disabled
      true
    rescue => e
      false
    end
  end
end
