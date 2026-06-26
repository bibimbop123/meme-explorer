# lib/services/leaderboard_service.rb
# P2 OPTIMIZATION: Complex calculations in SQL, not Ruby

module LeaderboardService
  extend self
  
  # Calculate leaderboard with SQL aggregation
  def get_leaderboard(limit: 100, min_level: 1)
    query = <<~SQL
      WITH user_stats AS (
        SELECT 
          u.id,
          u.username,
          u.level,
          u.xp,
          u.streak_days,
          u.total_likes_given,
          u.total_memes_saved,
          -- Calculate engagement score in SQL
          (u.total_likes_given * 1.0 + u.total_memes_saved * 2.0 + u.streak_days * 5.0) AS engagement_score,
          -- Rank users by level and XP
          RANK() OVER (ORDER BY u.level DESC, u.xp DESC) AS rank
        FROM users u
        WHERE u.role != 'admin'
          AND u.level >= $1
      )
      SELECT * FROM user_stats
      ORDER BY rank ASC
      LIMIT $2
    SQL
    
    DB_POOL.with do |conn|
      conn.exec_params(query, [min_level, limit])
        .map { |row| row.transform_keys(&:to_sym) }
    end
  rescue => e
    AppLogger.error("Leaderboard query failed", error: e.message)
    []
  end
  
  # Get user rank efficiently with single query
  def get_user_rank(user_id)
    query = <<~SQL
      WITH ranked_users AS (
        SELECT 
          id,
          RANK() OVER (ORDER BY level DESC, xp DESC) AS rank
        FROM users
        WHERE role != 'admin'
      )
      SELECT rank FROM ranked_users WHERE id = $1
    SQL
    
    DB_POOL.with do |conn|
      result = conn.exec_params(query, [user_id])
      result[0]['rank'].to_i if result.ntuples > 0
    end
  rescue => e
    AppLogger.warn("User rank query failed", user_id: user_id, error: e.message)
    nil
  end
  
  # Periodic leaderboard cache refresh
  def refresh_leaderboard_cache
    leaderboard = get_leaderboard(limit: 100)
    RedisService.setex('leaderboard:top100', 600, leaderboard.to_json) # 10 min TTL
    leaderboard
  rescue => e
    AppLogger.error("Leaderboard cache refresh failed", error: e.message)
    []
  end
end
