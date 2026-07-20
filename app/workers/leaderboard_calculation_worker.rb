class LeaderboardCalculationWorker
  include Sidekiq::Worker
  
  sidekiq_options queue: :critical, retry: 5, backtrace: true
  
  def perform
    AppLogger.info("🏆 [LEADERBOARD WORKER] Calculating leaderboard scores at #{Time.now}")
    
    # Get current week and month periods
    current_week = Time.now.strftime('%Y%U').to_i
    current_month = Time.now.strftime('%Y%m').to_i
    
    # Get all users with activity
    users_with_activity = DB.execute("
      SELECT DISTINCT user_id 
      FROM user_levels
      WHERE total_xp > 0
    ")
    
    updated_count = 0
    users_with_activity.each do |row|
      user_id = row['user_id']
      calculate_weekly_score(user_id, current_week)
      calculate_monthly_score(user_id, current_month)
      updated_count += 1
    end
    
    # Recalculate ranks after all scores are updated
    recalculate_weekly_ranks(current_week)
    recalculate_monthly_ranks(current_month)
    AppLogger.info("✅ [LEADERBOARD WORKER] Updated #{updated_count} users and recalculated ranks")
    
    # Invalidate leaderboard cache
    invalidate_leaderboard_cache
    
  rescue => e
    AppLogger.info("❌ [LEADERBOARD WORKER] Error: #{e.message}")
    AppLogger.info(e.backtrace.first(5).join("\n"))
    Sentry.capture_exception(e) if defined?(Sentry)
    raise  # Re-raise for Sidekiq retry
  end
  
  private
  
  def calculate_weekly_score(user_id, week_number)
    # Calculate engagement metrics for this week
    # Get total XP from user_levels as the metric value
    total_xp = DB.get_first_value(
      "SELECT total_xp FROM user_levels WHERE user_id = ?",
      [user_id]
    ).to_i
    
    # Update or insert weekly leaderboard entry
    DB.execute(
      "INSERT INTO weekly_leaderboard (user_id, week_number, metric_value, updated_at) 
       VALUES (?, ?, ?, CURRENT_TIMESTAMP)
       ON CONFLICT(user_id, week_number) 
       DO UPDATE SET 
         metric_value = excluded.metric_value,
         updated_at = CURRENT_TIMESTAMP",
      [user_id, week_number, total_xp]
    )
  rescue => e
    AppLogger.info("⚠️  Error calculating weekly score for user #{user_id}: #{e.message}")
  end
  
  def calculate_monthly_score(user_id, month_number)
    # Get total XP from user_levels
    total_xp = DB.get_first_value(
      "SELECT total_xp FROM user_levels WHERE user_id = ?",
      [user_id]
    ).to_i
    
    # Update or insert monthly leaderboard entry
    DB.execute(
      "INSERT INTO monthly_leaderboard (user_id, month_number, total_xp, updated_at) 
       VALUES (?, ?, ?, CURRENT_TIMESTAMP)
       ON CONFLICT(user_id, month_number) 
       DO UPDATE SET 
         total_xp = excluded.total_xp,
         updated_at = CURRENT_TIMESTAMP",
      [user_id, month_number, total_xp]
    )
  rescue => e
    AppLogger.info("⚠️  Error calculating monthly score for user #{user_id}: #{e.message}")
  end
  
  def recalculate_weekly_ranks(week_number)
    # Recalculate ranks based on metric_value
    DB.execute("
      UPDATE weekly_leaderboard
      SET rank = (
        SELECT COUNT(*) + 1
        FROM weekly_leaderboard w2
        WHERE w2.week_number = weekly_leaderboard.week_number
        AND w2.metric_value > weekly_leaderboard.metric_value
      )
      WHERE week_number = ?
    ", [week_number])
    AppLogger.info("✅ Recalculated weekly ranks for week #{week_number}")
  rescue => e
    AppLogger.info("⚠️  Error recalculating weekly ranks: #{e.message}")
  end
  
  def recalculate_monthly_ranks(month_number)
    # Recalculate ranks based on total_xp
    DB.execute("
      UPDATE monthly_leaderboard
      SET rank = (
        SELECT COUNT(*) + 1
        FROM monthly_leaderboard m2
        WHERE m2.month_number = monthly_leaderboard.month_number
        AND m2.total_xp > monthly_leaderboard.total_xp
      )
      WHERE month_number = ?
    ", [month_number])
    AppLogger.info("✅ Recalculated monthly ranks for month #{month_number}")
  rescue => e
    AppLogger.info("⚠️  Error recalculating monthly ranks: #{e.message}")
  end
  
  def invalidate_leaderboard_cache
    # Clear Redis cache for leaderboards
    if defined?(MEME_CACHE)
      MEME_CACHE.delete_matched('leaderboard:*')
    AppLogger.info("🔄 Invalidated leaderboard cache")
    end
  rescue => e
    AppLogger.info("⚠️  Error invalidating cache: #{e.message}")
  end
end
