# Sidekiq Worker: Database Cleanup
# Replaces the background thread from app.rb
# Cleans up old records hourly

class DatabaseCleanupJob
  include Sidekiq::Worker
  
  sidekiq_options queue: :low, retry: 3
  
  def perform
    logger.info "🧹 [DB CLEANUP] Starting cleanup..."
    start_time = Time.now
    
    begin
      # Cleanup 1: Remove old broken image records
      broken_deleted = cleanup_broken_images
      
      # Cleanup 2: Remove stale meme stats
      stats_deleted = cleanup_stale_stats
      
      # Cleanup 3: Remove expired sessions (if using DB sessions)
      sessions_deleted = cleanup_expired_sessions
      
      # Cleanup 4: Archive old leaderboard data
      archived = archive_old_leaderboards
      
      duration = ((Time.now - start_time) * 1000).round(0)
      logger.info "✅ [DB CLEANUP] Complete! Removed: #{broken_deleted} broken images, #{stats_deleted} stale stats, #{sessions_deleted} sessions, archived #{archived} leaderboards (#{duration}ms)"
      
    rescue => e
      logger.error "❌ [DB CLEANUP] Error: #{e.class}: #{e.message}"
      logger.error e.backtrace.first(5).join("\n")
      
      # Report to Sentry
      Sentry.capture_exception(e) if defined?(Sentry)
      
      # Re-raise to trigger Sidekiq retry
      raise e
    end
  end
  
  private
  
  def cleanup_broken_images
    # Remove broken images that have failed 5+ times and are >24 hours old
    result = DB.execute(<<-SQL)
      DELETE FROM broken_images 
      WHERE failure_count >= 5 
        AND datetime(first_failed_at) < datetime('now', '-1 day')
    SQL
    
    deleted = DB.changes
    logger.info "  Deleted #{deleted} old broken image records"
    deleted
  rescue => e
    logger.warn "Failed to cleanup broken_images: #{e.message}"
    0
  end
  
  def cleanup_stale_stats
    # Remove meme stats with no engagement and older than 7 days
    result = DB.execute(<<-SQL)
      DELETE FROM meme_stats 
      WHERE likes = 0 
        AND views = 0 
        AND datetime(updated_at) < datetime('now', '-7 days')
    SQL
    
    deleted = DB.changes
    logger.info "  Deleted #{deleted} stale meme stats"
    deleted
  rescue => e
    logger.warn "Failed to cleanup meme_stats: #{e.message}"
    0
  end
  
  def cleanup_expired_sessions
    # Only if using database-backed sessions
    return 0 unless table_exists?('sessions')
    
    result = DB.execute(<<-SQL)
      DELETE FROM sessions 
      WHERE datetime(updated_at) < datetime('now', '-30 days')
    SQL
    
    deleted = DB.changes
    logger.info "  Deleted #{deleted} expired sessions"
    deleted
  rescue => e
    logger.warn "Failed to cleanup sessions: #{e.message}"
    0
  end
  
  def archive_old_leaderboards
    # Archive leaderboard data older than 90 days
    return 0 unless table_exists?('leaderboard_weekly')
    
    # Move to archive table instead of deleting (if archive table exists)
    if table_exists?('leaderboard_archive')
      result = DB.execute(<<-SQL)
        INSERT INTO leaderboard_archive 
        SELECT * FROM leaderboard_weekly 
        WHERE datetime(week_start) < datetime('now', '-90 days')
      SQL
      
      archived = DB.changes
      
      # Now delete from main table
      DB.execute(<<-SQL)
        DELETE FROM leaderboard_weekly 
        WHERE datetime(week_start) < datetime('now', '-90 days')
      SQL
      
      logger.info "  Archived #{archived} old leaderboard records"
      archived
    else
      # Just delete if no archive table
      result = DB.execute(<<-SQL)
        DELETE FROM leaderboard_weekly 
        WHERE datetime(week_start) < datetime('now', '-90 days')
      SQL
      
      deleted = DB.changes
      logger.info "  Deleted #{deleted} old leaderboard records"
      deleted
    end
  rescue => e
    logger.warn "Failed to archive leaderboards: #{e.message}"
    0
  end
  
  def table_exists?(table_name)
    result = DB.execute(<<-SQL, [table_name])
      SELECT name FROM sqlite_master 
      WHERE type='table' AND name=?
    SQL
    result.any?
  rescue => e
    # PostgreSQL version
    result = DB.execute(<<-SQL, [table_name])
      SELECT tablename FROM pg_tables 
      WHERE tablename = $1
    SQL
    result.any?
  rescue
    false
  end
end
