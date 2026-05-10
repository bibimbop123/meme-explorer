# LeaderboardService
# Comprehensive service for managing all leaderboard functionality
# Created: May 10, 2026

class LeaderboardService
  class << self
    # ============================================
    # CORE LEADERBOARD QUERIES
    # ============================================
    
    # Get leaderboard for a specific period and type
    # @param type [Symbol] :weekly, :monthly, :all_time, :streak, :category
    # @param period [String] Period identifier (e.g., "202621" for week 21 of 2026)
    # @param limit [Integer] Number of results to return
    # @param offset [Integer] Offset for pagination
    # @return [Array<Hash>] Leaderboard entries
    def get_leaderboard(type: :weekly, period: nil, limit: 25, offset: 0, category: nil)
      period ||= current_period(type)
      cache_key = "leaderboard:#{type}:#{period}:#{limit}:#{offset}:#{category}"
      
      # Try cache first
      cached = get_from_cache(cache_key)
      return cached if cached
      
      results = case type
      when :weekly
        get_weekly_leaderboard(period, limit, offset)
      when :monthly
        get_monthly_leaderboard(period, limit, offset)
      when :all_time
        get_all_time_leaderboard(limit, offset)
      when :streak
        get_streak_leaderboard(limit, offset)
      when :category
        get_category_leaderboard(category, period, limit, offset)
      else
        []
      end
      
      # Cache for 5 minutes
      set_in_cache(cache_key, results, 300)
      results
    rescue => e
      puts "❌ [LeaderboardService] Error fetching leaderboard: #{e.message}"
      puts e.backtrace.first(5)
      []
    end
    
    # Get user's rank and stats for a specific leaderboard type
    # @param user_id [Integer] User ID
    # @param type [Symbol] Leaderboard type
    # @param period [String] Period identifier
    # @return [Hash, nil] User's rank data
    def get_user_rank(user_id, type: :weekly, period: nil)
      return nil unless user_id
      
      period ||= current_period(type)
      
      case type
      when :weekly
        get_user_weekly_rank(user_id, period)
      when :monthly
        get_user_monthly_rank(user_id, period)
      when :all_time
        get_user_all_time_rank(user_id)
      when :streak
        get_user_streak_rank(user_id)
      else
        nil
      end
    rescue => e
      puts "❌ [LeaderboardService] Error fetching user rank: #{e.message}"
      nil
    end
    
    # Get nearby competitors for a user
    # @param user_id [Integer] User ID
    # @param type [Symbol] Leaderboard type
    # @param range [Integer] Number of ranks above/below to show
    # @return [Array<Hash>] Nearby competitors
    def get_nearby_ranks(user_id, type: :weekly, range: 5, period: nil)
      user_rank = get_user_rank(user_id, type: type, period: period)
      return [] unless user_rank && user_rank['rank']
      
      rank = user_rank['rank'].to_i
      start_rank = [rank - range, 1].max
      end_rank = rank + range
      
      period ||= current_period(type)
      
      # Get users in rank range
      case type
      when :weekly
        get_weekly_range(period, start_rank, end_rank)
      when :monthly
        get_monthly_range(period, start_rank, end_rank)
      when :all_time
        get_all_time_range(start_rank, end_rank)
      when :streak
        get_streak_range(start_rank, end_rank)
      else
        []
      end
    rescue => e
      puts "❌ [LeaderboardService] Error fetching nearby ranks: #{e.message}"
      []
    end
    
    # ============================================
    # WEEKLY LEADERBOARD
    # ============================================
    
    def get_weekly_leaderboard(week_num, limit, offset)
      DB.execute(
        "SELECT 
          wl.rank,
          wl.user_id,
          wl.metric_value as score,
          u.reddit_username,
          u.email,
          ul.level,
          ul.title,
          ul.total_xp,
          us.current_streak
         FROM weekly_leaderboard wl
         JOIN users u ON wl.user_id = u.id
         LEFT JOIN user_levels ul ON wl.user_id = ul.user_id
         LEFT JOIN user_streaks us ON wl.user_id = us.user_id
         WHERE wl.week_number = ?
         ORDER BY wl.rank ASC
         LIMIT ? OFFSET ?",
        [week_num, limit, offset]
      ).map { |row| row.transform_keys(&:to_s) }
    end
    
    def get_user_weekly_rank(user_id, week_num)
      DB.execute(
        "SELECT 
          wl.rank,
          wl.metric_value as score,
          ul.level,
          ul.total_xp,
          us.current_streak
         FROM weekly_leaderboard wl
         LEFT JOIN user_levels ul ON wl.user_id = ul.user_id
         LEFT JOIN user_streaks us ON wl.user_id = us.user_id
         WHERE wl.week_number = ? AND wl.user_id = ?",
        [week_num, user_id]
      ).first&.transform_keys(&:to_s)
    end
    
    def get_weekly_range(week_num, start_rank, end_rank)
      DB.execute(
        "SELECT 
          wl.rank,
          wl.user_id,
          wl.metric_value as score,
          u.reddit_username,
          u.email,
          ul.level,
          ul.total_xp
         FROM weekly_leaderboard wl
         JOIN users u ON wl.user_id = u.id
         LEFT JOIN user_levels ul ON wl.user_id = ul.user_id
         WHERE wl.week_number = ? AND wl.rank BETWEEN ? AND ?
         ORDER BY wl.rank ASC",
        [week_num, start_rank, end_rank]
      ).map { |row| row.transform_keys(&:to_s) }
    end
    
    # ============================================
    # MONTHLY LEADERBOARD
    # ============================================
    
    def get_monthly_leaderboard(month_num, limit, offset)
      DB.execute(
        "SELECT 
          ml.rank,
          ml.user_id,
          ml.total_xp as score,
          u.reddit_username,
          u.email,
          ul.level,
          ul.title,
          ul.total_xp,
          us.longest_streak
         FROM monthly_leaderboard ml
         JOIN users u ON ml.user_id = u.id
         LEFT JOIN user_levels ul ON ml.user_id = ul.user_id
         LEFT JOIN user_streaks us ON ml.user_id = us.user_id
         WHERE ml.month_number = ?
         ORDER BY ml.rank ASC
         LIMIT ? OFFSET ?",
        [month_num, limit, offset]
      ).map { |row| row.transform_keys(&:to_s) }
    rescue SQLite3::SQLException => e
      # Table doesn't exist yet, return empty
      []
    end
    
    def get_user_monthly_rank(user_id, month_num)
      DB.execute(
        "SELECT 
          ml.rank,
          ml.total_xp as score,
          ul.level
         FROM monthly_leaderboard ml
         LEFT JOIN user_levels ul ON ml.user_id = ul.user_id
         WHERE ml.month_number = ? AND ml.user_id = ?",
        [month_num, user_id]
      ).first&.transform_keys(&:to_s)
    rescue SQLite3::SQLException => e
      nil
    end
    
    def get_monthly_range(month_num, start_rank, end_rank)
      DB.execute(
        "SELECT 
          ml.rank,
          ml.user_id,
          ml.total_xp as score,
          u.reddit_username,
          u.email,
          ul.level
         FROM monthly_leaderboard ml
         JOIN users u ON ml.user_id = u.id
         LEFT JOIN user_levels ul ON ml.user_id = ul.user_id
         WHERE ml.month_number = ? AND ml.rank BETWEEN ? AND ?
         ORDER BY ml.rank ASC",
        [month_num, start_rank, end_rank]
      ).map { |row| row.transform_keys(&:to_s) }
    rescue SQLite3::SQLException => e
      []
    end
    
    # ============================================
    # ALL-TIME LEADERBOARD
    # ============================================
    
    def get_all_time_leaderboard(limit, offset)
      DB.execute(
        "SELECT 
          ROW_NUMBER() OVER (ORDER BY ul.total_xp DESC) as rank,
          ul.user_id,
          ul.total_xp as score,
          ul.level,
          ul.title,
          u.reddit_username,
          u.email,
          us.longest_streak,
          us.current_streak
         FROM user_levels ul
         JOIN users u ON ul.user_id = u.id
         LEFT JOIN user_streaks us ON ul.user_id = us.user_id
         ORDER BY ul.total_xp DESC
         LIMIT ? OFFSET ?",
        [limit, offset]
      ).map { |row| row.transform_keys(&:to_s) }
    end
    
    def get_user_all_time_rank(user_id)
      result = DB.execute(
        "SELECT 
          COUNT(*) + 1 as rank,
          ul.total_xp as score,
          ul.level
         FROM user_levels ul
         WHERE ul.total_xp > (SELECT total_xp FROM user_levels WHERE user_id = ?)
         GROUP BY ul.user_id
         HAVING ul.user_id = ?",
        [user_id, user_id]
      ).first
      
      # If no result, user might be #1 or doesn't exist
      if result.nil?
        user_level = DB.execute(
          "SELECT total_xp as score, level FROM user_levels WHERE user_id = ?",
          [user_id]
        ).first
        
        return nil unless user_level
        
        user_level.merge({ 'rank' => 1 }).transform_keys(&:to_s)
      else
        result.transform_keys(&:to_s)
      end
    end
    
    def get_all_time_range(start_rank, end_rank)
      DB.execute(
        "WITH ranked_users AS (
          SELECT 
            ROW_NUMBER() OVER (ORDER BY ul.total_xp DESC) as rank,
            ul.user_id,
            ul.total_xp as score,
            ul.level,
            u.reddit_username,
            u.email
          FROM user_levels ul
          JOIN users u ON ul.user_id = u.id
        )
        SELECT * FROM ranked_users
        WHERE rank BETWEEN ? AND ?
        ORDER BY rank ASC",
        [start_rank, end_rank]
      ).map { |row| row.transform_keys(&:to_s) }
    end
    
    # ============================================
    # STREAK LEADERBOARD
    # ============================================
    
    def get_streak_leaderboard(limit, offset)
      DB.execute(
        "SELECT 
          ROW_NUMBER() OVER (ORDER BY us.current_streak DESC) as rank,
          us.user_id,
          us.current_streak as score,
          us.longest_streak,
          u.reddit_username,
          u.email,
          ul.level,
          ul.title
         FROM user_streaks us
         JOIN users u ON us.user_id = u.id
         LEFT JOIN user_levels ul ON us.user_id = ul.user_id
         WHERE us.current_streak > 0
         ORDER BY us.current_streak DESC
         LIMIT ? OFFSET ?",
        [limit, offset]
      ).map { |row| row.transform_keys(&:to_s) }
    end
    
    def get_user_streak_rank(user_id)
      result = DB.execute(
        "SELECT 
          COUNT(*) + 1 as rank,
          us.current_streak as score,
          us.longest_streak
         FROM user_streaks us
         WHERE us.current_streak > (SELECT current_streak FROM user_streaks WHERE user_id = ?)
         GROUP BY us.user_id
         HAVING us.user_id = ?",
        [user_id, user_id]
      ).first
      
      if result.nil?
        streak = DB.execute(
          "SELECT current_streak as score, longest_streak FROM user_streaks WHERE user_id = ?",
          [user_id]
        ).first
        
        return nil unless streak
        
        streak.merge({ 'rank' => 1 }).transform_keys(&:to_s)
      else
        result.transform_keys(&:to_s)
      end
    end
    
    def get_streak_range(start_rank, end_rank)
      DB.execute(
        "WITH ranked_users AS (
          SELECT 
            ROW_NUMBER() OVER (ORDER BY us.current_streak DESC) as rank,
            us.user_id,
            us.current_streak as score,
            u.reddit_username,
            u.email,
            ul.level
          FROM user_streaks us
          JOIN users u ON us.user_id = u.id
          LEFT JOIN user_levels ul ON us.user_id = ul.user_id
        )
        SELECT * FROM ranked_users
        WHERE rank BETWEEN ? AND ?
        ORDER BY rank ASC",
        [start_rank, end_rank]
      ).map { |row| row.transform_keys(&:to_s) }
    end
    
    # ============================================
    # CATEGORY LEADERBOARD
    # ============================================
    
    def get_category_leaderboard(category, week_num, limit, offset)
      return [] unless category
      
      DB.execute(
        "SELECT 
          cl.rank,
          cl.user_id,
          cl.category_score as score,
          u.reddit_username,
          u.email,
          ul.level,
          ul.title
         FROM category_leaderboard cl
         JOIN users u ON cl.user_id = u.id
         LEFT JOIN user_levels ul ON cl.user_id = ul.user_id
         WHERE cl.category = ? AND cl.week_number = ?
         ORDER BY cl.rank ASC
         LIMIT ? OFFSET ?",
        [category, week_num, limit, offset]
      ).map { |row| row.transform_keys(&:to_s) }
    rescue SQLite3::SQLException => e
      []
    end
    
    # ============================================
    # PERIOD CALCULATIONS
    # ============================================
    
    def current_period(type)
      case type
      when :weekly
        Date.today.strftime("%Y%U").to_i
      when :monthly
        Date.today.strftime("%Y%m").to_i
      else
        nil
      end
    end
    
    def previous_period(type, current = nil)
      current ||= current_period(type)
      
      case type
      when :weekly
        date = Date.strptime(current.to_s + '1', '%Y%U%u')
        (date - 7).strftime("%Y%U").to_i
      when :monthly
        year = current.to_s[0..3].to_i
        month = current.to_s[4..5].to_i
        if month == 1
          "#{year - 1}12".to_i
        else
          "#{year}#{format('%02d', month - 1)}".to_i
        end
      else
        nil
      end
    end
    
    # ============================================
    # COMPARATIVE INSIGHTS
    # ============================================
    
    # Calculate what user needs to reach a target rank
    # @param user_id [Integer] User ID
    # @param target_rank [Integer] Desired rank
    # @param type [Symbol] Leaderboard type
    # @return [Hash] Insight data
    def rank_gap_analysis(user_id, target_rank, type: :weekly, period: nil)
      user_rank = get_user_rank(user_id, type: type, period: period)
      return nil unless user_rank
      
      current_rank = user_rank['rank'].to_i
      return nil if current_rank <= target_rank # Already at or above target
      
      # Get target rank user's score
      period ||= current_period(type)
      target_user = get_leaderboard(type: type, period: period, limit: 1, offset: target_rank - 1).first
      return nil unless target_user
      
      current_score = user_rank['score'].to_i
      target_score = target_user['score'].to_i
      gap = target_score - current_score
      
      {
        current_rank: current_rank,
        target_rank: target_rank,
        current_score: current_score,
        target_score: target_score,
        gap: gap,
        ranks_to_climb: current_rank - target_rank
      }
    end
    
    # Get rank change from previous period
    # @param user_id [Integer] User ID
    # @param type [Symbol] Leaderboard type
    # @return [Hash] Change data
    def rank_change(user_id, type: :weekly)
      current = get_user_rank(user_id, type: type)
      return nil unless current
      
      prev_period = previous_period(type)
      previous = get_user_rank(user_id, type: type, period: prev_period)
      
      if previous
        change = previous['rank'].to_i - current['rank'].to_i
        {
          current_rank: current['rank'].to_i,
          previous_rank: previous['rank'].to_i,
          change: change,
          direction: change > 0 ? 'up' : (change < 0 ? 'down' : 'same')
        }
      else
        {
          current_rank: current['rank'].to_i,
          previous_rank: nil,
          change: nil,
          direction: 'new'
        }
      end
    end
    
    # ============================================
    # REWARDS & ACHIEVEMENTS
    # ============================================
    
    # Distribute rewards for top performers
    # @param type [Symbol] Leaderboard type
    # @param period [String] Period to award
    def distribute_rewards(type: :weekly, period: nil)
      period ||= previous_period(type) # Award for completed period
      
      # Get top 10
      top_10 = get_leaderboard(type: type, period: period, limit: 10)
      
      rewards = {
        1 => { xp: 1000, title: "Champion", badge: "🏆" },
        2 => { xp: 750, title: "Runner-Up", badge: "🥈" },
        3 => { xp: 500, title: "Third Place", badge: "🥉" },
        4..10 => { xp: 250, title: "Top 10", badge: "⭐" }
      }
      
      top_10.each do |entry|
        rank = entry['rank'].to_i
        reward = rewards[rank] || rewards[4..10]
        
        # Award XP
        DB.execute(
          "UPDATE user_levels SET total_xp = total_xp + ?, current_xp = current_xp + ? WHERE user_id = ?",
          [reward[:xp], reward[:xp], entry['user_id']]
        )
        
        # Mark reward as claimed
        mark_reward_claimed(entry['user_id'], type, period)
        
        # Log achievement
        log_achievement(entry['user_id'], "#{type}_#{period}_rank_#{rank}", reward)
      end
      
      puts "✅ Distributed rewards for #{type} period #{period} to #{top_10.size} users"
    rescue => e
      puts "❌ Error distributing rewards: #{e.message}"
    end
    
    def mark_reward_claimed(user_id, type, period)
      table = type == :weekly ? 'weekly_leaderboard' : 'monthly_leaderboard'
      period_col = type == :weekly ? 'week_number' : 'month_number'
      
      DB.execute(
        "UPDATE #{table} SET reward_claimed = 1 WHERE user_id = ? AND #{period_col} = ?",
        [user_id, period]
      )
    rescue => e
      puts "⚠️ Error marking reward claimed: #{e.message}"
    end
    
    def log_achievement(user_id, achievement_type, reward_data)
      DB.execute(
        "INSERT INTO achievements_log (user_id, achievement_type, reward_xp, badge, created_at) 
         VALUES (?, ?, ?, ?, CURRENT_TIMESTAMP)",
        [user_id, achievement_type, reward_data[:xp], reward_data[:badge]]
      )
    rescue SQLite3::SQLException => e
      # Table might not exist yet
    end
    
    # ============================================
    # CACHE MANAGEMENT
    # ============================================
    
    def get_from_cache(key)
      MEME_CACHE.get(key)
    rescue => e
      nil
    end
    
    def set_in_cache(key, value, ttl = 300)
      MEME_CACHE.set(key, value, ttl)
    rescue => e
      nil
    end
    
    def invalidate_cache(type: nil, period: nil)
      # Clear all leaderboard caches
      pattern = if type && period
        "leaderboard:#{type}:#{period}:*"
      elsif type
        "leaderboard:#{type}:*"
      else
        "leaderboard:*"
      end
      
      # Note: This is a simple implementation
      # In production, use Redis SCAN with pattern matching
      puts "🔄 Invalidating cache: #{pattern}"
    end
  end
end
