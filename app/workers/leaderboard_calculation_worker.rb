class LeaderboardCalculationWorker
  include Sidekiq::Worker
  
  sidekiq_options queue: :critical, retry: 5, backtrace: true
  
  def perform
    puts "🏆 [LEADERBOARD WORKER] Calculating leaderboard scores at #{Time.now}"
    
    # Get current week period
    current_week = Time.now.strftime('%Y%U')
    
    # Get all users with activity
    users_with_activity = DB.execute("
      SELECT DISTINCT user_id 
      FROM user_meme_stats 
      WHERE liked = 1 OR saved = 1
      UNION
      SELECT DISTINCT user_id 
      FROM saved_memes
    ")
    
    updated_count = 0
    users_with_activity.each do |row|
      user_id = row['user_id']
      calculate_user_score(user_id, current_week)
      updated_count += 1
    end
    
    puts "✅ [LEADERBOARD WORKER] Updated #{updated_count} users"
    
  rescue => e
    puts "❌ [LEADERBOARD WORKER] Error: #{e.message}"
    puts e.backtrace.first(5).join("\n")
    Sentry.capture_exception(e) if defined?(Sentry)
    raise  # Re-raise for Sidekiq retry
  end
  
  private
  
  def calculate_user_score(user_id, period)
    # Calculate engagement metrics
    likes = DB.get_first_value(
      "SELECT COUNT(*) FROM user_meme_stats WHERE user_id = ? AND liked = 1",
      [user_id]
    ).to_i
    
    saved = DB.get_first_value(
      "SELECT COUNT(*) FROM saved_memes WHERE user_id = ?",
      [user_id]
    ).to_i
    
    battles_won = DB.get_first_value(
      "SELECT COUNT(*) FROM meme_battles WHERE winner_id = ?",
      [user_id]
    ).to_i || 0
    
    # Calculate total score: likes * 10 + saved * 20 + battles_won * 50
    score = (likes * 10) + (saved * 20) + (battles_won * 50)
    
    # Update or insert leaderboard entry
    DB.execute(
      "INSERT INTO leaderboard_entries (user_id, period, period_type, score, likes_count, saved_count, battles_won) 
       VALUES (?, ?, 'weekly', ?, ?, ?, ?)
       ON CONFLICT(user_id, period, period_type) 
       DO UPDATE SET 
         score = excluded.score,
         likes_count = excluded.likes_count,
         saved_count = excluded.saved_count,
         battles_won = excluded.battles_won,
         updated_at = CURRENT_TIMESTAMP",
      [user_id, period, score, likes, saved, battles_won]
    )
  rescue => e
    puts "⚠️  Error calculating score for user #{user_id}: #{e.message}"
  end
end
