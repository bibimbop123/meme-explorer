class DatabaseCleanupWorker
  include Sidekiq::Worker
  
  sidekiq_options queue: :low, retry: 3
  
  def perform
    AppLogger.info("🧹 [CLEANUP WORKER] Starting database cleanup at #{Time.now}")
    
    cleanup_stats = {
      broken_images: 0,
      old_meme_stats: 0,
      old_impressions: 0
    }
    
    # Remove old broken images (failure_count >= 5 and > 1 day old)
    result = DB.execute(
      "DELETE FROM broken_images 
       WHERE failure_count >= 5 
       AND #{DbHelpers.date_ago('first_failed_at', days: 1)} RETURNING url"
    )
    cleanup_stats[:broken_images] = result.size
    
    # Remove old meme stats (no engagement and > 7 days old)
    result = DB.execute(
      "DELETE FROM meme_stats 
       WHERE likes = 0 
       AND views = 0 
       AND #{DbHelpers.date_ago('updated_at', days: 7)} RETURNING url"
    )
    cleanup_stats[:old_meme_stats] = result.size
    
    # IDs expire after 30 minutes; seven-day retention preserves retry dedupe.
    # Bound each run to avoid an unbounded delete on a growing analytics table.
    result = DB.execute(
      "DELETE FROM meme_impressions WHERE id IN (
         SELECT id FROM meme_impressions
         WHERE created_at < NOW() - INTERVAL '7 days'
         ORDER BY created_at LIMIT 10000
       ) RETURNING id"
    )
    cleanup_stats[:old_impressions] = result.size

    # Bound meme_activity_log growth by pruning activity events older than 90 days
    # (rolling metrics reports use up to 30d and retention uses 14d).
    activity_schema = DB.get_first_value("SELECT EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = current_schema() AND table_name = 'meme_activity_log')")
    if activity_schema == true || activity_schema == 't'
      DB.execute(
        "DELETE FROM meme_activity_log WHERE id IN (
           SELECT id FROM meme_activity_log
           WHERE created_at < NOW() - INTERVAL '90 days'
           ORDER BY created_at LIMIT 10000
         )"
      )
    end
    # Retention cleanup must continue after collection is disabled. Older
    # deployments without this additive migration have nothing to clean yet.
    visitor_schema = DB.get_first_value("SELECT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = current_schema() AND table_name = 'browser_visitors' AND column_name = 'revoked_at')")
    if visitor_schema == true || visitor_schema == 't'
      DB.execute("DELETE FROM browser_visitors WHERE visitor_key IN (SELECT visitor_key FROM browser_visitors WHERE COALESCE(revoked_at, last_seen_at) < NOW() - INTERVAL '30 days' ORDER BY COALESCE(revoked_at, last_seen_at) LIMIT 10000)")
    end
    AppLogger.info("✅ [CLEANUP WORKER] Cleaned up:")
    AppLogger.info("   - #{cleanup_stats[:broken_images]} broken images")
    AppLogger.info("   - #{cleanup_stats[:old_meme_stats]} old meme stats")
    AppLogger.info("   - #{cleanup_stats[:old_impressions]} old impressions")
    
  rescue => e
    AppLogger.info("❌ [CLEANUP WORKER] Error: #{e.message}")
    AppLogger.info(e.backtrace.first(5).join("\n"))
    Sentry.capture_exception(e) if defined?(Sentry)
    # Don't raise - cleanup is not critical
  end
end
