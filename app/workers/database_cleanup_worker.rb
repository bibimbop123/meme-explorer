class DatabaseCleanupWorker
  include Sidekiq::Worker
  
  sidekiq_options queue: :low, retry: 3
  
  def perform
    puts "🧹 [CLEANUP WORKER] Starting database cleanup at #{Time.now}"
    
    cleanup_stats = {
      broken_images: 0,
      old_meme_stats: 0,
      expired_experiments: 0
    }
    
    # Remove old broken images (failure_count >= 5 and > 1 day old)
    cleanup_stats[:broken_images] = DB.execute(
      "DELETE FROM broken_images 
       WHERE failure_count >= 5 
       AND datetime(first_failed_at) < datetime('now', '-1 day')"
    ).changes
    
    # Remove old meme stats (no engagement and > 7 days old)
    cleanup_stats[:old_meme_stats] = DB.execute(
      "DELETE FROM meme_stats 
       WHERE likes = 0 
       AND views = 0 
       AND datetime(updated_at) < datetime('now', '-7 days')"
    ).changes
    
    # Clean up old experiment assignments (> 30 days)
    cleanup_stats[:expired_experiments] = DB.execute(
      "DELETE FROM experiment_assignments 
       WHERE datetime(assigned_at) < datetime('now', '-30 days')"
    ).changes
    
    puts "✅ [CLEANUP WORKER] Cleaned up:"
    puts "   - #{cleanup_stats[:broken_images]} broken images"
    puts "   - #{cleanup_stats[:old_meme_stats]} old meme stats"
    puts "   - #{cleanup_stats[:expired_experiments]} expired experiments"
    
  rescue => e
    puts "❌ [CLEANUP WORKER] Error: #{e.message}"
    puts e.backtrace.first(5).join("\n")
    Sentry.capture_exception(e) if defined?(Sentry)
    # Don't raise - cleanup is not critical
  end
end
