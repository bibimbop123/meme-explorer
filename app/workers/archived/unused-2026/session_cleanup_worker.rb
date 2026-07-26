# Session Cleanup Worker
# Periodically cleans up expired and zombie sessions
# Runs every 5 minutes to keep session data accurate

class SessionCleanupWorker
  include Sidekiq::Worker
  
  sidekiq_options queue: :default, retry: 3
  
  def perform
    start_time = Time.now
    
    begin
      require_relative '../../lib/services/session_tracker_service'
    AppLogger.info("🧹 [SESSION CLEANUP WORKER] Starting cleanup...")
      
      # Cleanup expired and zombie sessions
      cleaned_count = SessionTrackerService.cleanup_expired_sessions!
      
      # Get current stats
      stats = SessionTrackerService.session_stats
      
      duration = (Time.now - start_time).round(2)
    AppLogger.info("✅ [SESSION CLEANUP WORKER] Completed in #{duration}s")
    AppLogger.info("   - Cleaned: #{cleaned_count} sessions")
    AppLogger.info("   - Active: #{stats[:active_sessions]} sessions")
    AppLogger.info("   - Engaged: #{stats[:engaged_sessions]} sessions")
    AppLogger.info("   - Idle: #{stats[:idle_sessions]} sessions")
      
      # Return stats for monitoring
      {
        cleaned: cleaned_count,
        active: stats[:active_sessions],
        engaged: stats[:engaged_sessions],
        duration: duration
      }
      
    rescue => e
    AppLogger.info("❌ [SESSION CLEANUP WORKER] Error: #{e.message}")
    AppLogger.info(e.backtrace.first(5).join("\n"))
      raise e # Re-raise to trigger Sidekiq retry
    end
  end
end
