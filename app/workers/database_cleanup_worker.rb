class DatabaseCleanupWorker
  include Sidekiq::Worker
  
  sidekiq_options queue: :low, retry: 3
  
  def perform
    AppLogger.info("🧹 [CLEANUP WORKER] Starting database cleanup at #{Time.now}")
    
    cleanup_stats = {
      broken_images: 0,
      old_meme_stats: 0,
      expired_experiments: 0
    }
    
    # Remove old broken images (failure_count >= 5 and > 1 day old)
    result = DB.execute(
      "DELETE FROM broken_images 
       WHERE failure_count >= 5 
       AND #{DbHelpers.date_ago('first_failed_at', days: 1)}"
    )
    cleanup_stats[:broken_images] = result.respond_to?(:changes) ? result.changes : result.cmd_tuples
    
    # Remove old meme stats (no engagement and > 7 days old)
    result = DB.execute(
      "DELETE FROM meme_stats 
       WHERE likes = 0 
       AND views = 0 
       AND #{DbHelpers.date_ago('updated_at', days: 7)}"
    )
    cleanup_stats[:old_meme_stats] = result.respond_to?(:changes) ? result.changes : result.cmd_tuples
    
    # Clean up old experiment assignments (> 30 days)
    result = DB.execute(
      "DELETE FROM experiment_assignments 
       WHERE #{DbHelpers.date_ago('assigned_at', days: 30)}"
    )
    cleanup_stats[:expired_experiments] = result.respond_to?(:changes) ? result.changes : result.cmd_tuples
    AppLogger.info("✅ [CLEANUP WORKER] Cleaned up:")
    AppLogger.info("   - #{cleanup_stats[:broken_images]} broken images")
    AppLogger.info("   - #{cleanup_stats[:old_meme_stats]} old meme stats")
    AppLogger.info("   - #{cleanup_stats[:expired_experiments]} expired experiments")
    
  rescue => e
    AppLogger.info("❌ [CLEANUP WORKER] Error: #{e.message}")
    AppLogger.info(e.backtrace.first(5).join("\n"))
    Sentry.capture_exception(e) if defined?(Sentry)
    # Don't raise - cleanup is not critical
  end
end
