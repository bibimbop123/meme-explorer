# Gamification Helpers Module
# Handles streaks, XP, levels, collections, and challenges
# Created: March 10, 2026

module GamificationHelpers
  # ============================================
  # STREAK SYSTEM
  # ============================================
  
  # XP reward table
  def xp_rewards
    {
      view_meme: 5,
      like_meme: 10,
      save_meme: 15,
      share_meme: 20,
      daily_streak: 25,
      milestone_streak_3: 50,
      milestone_streak_7: 100,
      milestone_streak_14: 200,
      milestone_streak_30: 500,
      milestone_streak_100: 2000,
      complete_collection: 200,
      first_login_of_day: 30
    }
  end
  
  # Update user's daily streak
  def update_streak(user_id)
    return nil unless user_id
    
    begin
      streak = DB.execute(
        "SELECT * FROM user_streaks WHERE user_id = ?", 
        [user_id]
      ).first
      
      today = Date.today.to_s
      
      # First time user - create streak record
      if streak.nil?
        DB.execute(
          "INSERT INTO user_streaks (user_id, current_streak, longest_streak, last_visit_date, total_memes_viewed) 
           VALUES (?, 1, 1, ?, 1)",
          [user_id, today]
        )
        
        # Award XP for first visit
        add_xp(user_id, :first_login_of_day)
        
        return { 
          new_streak: true, 
          days: 1, 
          milestone: false,
          xp_gained: xp_rewards[:first_login_of_day]
        }
      end
      
      last_visit = Date.parse(streak["last_visit_date"])
      today_date = Date.today
      days_diff = (today_date - last_visit).to_i
      
      # Same day - just increment view count
      if days_diff == 0
        DB.execute(
          "UPDATE user_streaks SET total_memes_viewed = total_memes_viewed + 1 WHERE user_id = ?",
          [user_id]
        )
        return { continuing: true, days: streak["current_streak"] }
      
      # Next day - increment streak!
      elsif days_diff == 1
        new_streak = streak["current_streak"] + 1
        new_longest = [new_streak, streak["longest_streak"]].max
        
        DB.execute(
          "UPDATE user_streaks 
           SET current_streak = ?, longest_streak = ?, last_visit_date = ?, 
               total_memes_viewed = total_memes_viewed + 1, updated_at = CURRENT_TIMESTAMP 
           WHERE user_id = ?",
          [new_streak, new_longest, today, user_id]
        )
        
        # Award daily streak XP
        xp_data = add_xp(user_id, :daily_streak)
        
        # Check for milestone
        milestone = false
        bonus_xp = 0
        
        if [3, 7, 14, 30, 100].include?(new_streak)
          milestone = true
          milestone_key = "milestone_streak_#{new_streak}".to_sym
          milestone_xp_data = add_xp(user_id, milestone_key)
          bonus_xp = milestone_xp_data[:xp_gained] if milestone_xp_data
        end
        
        return { 
          streak_increased: true, 
          days: new_streak, 
          milestone: milestone,
          xp_gained: xp_data[:xp_gained] + bonus_xp
        }
      
      # Streak broken (unless freeze available)
      else
        if streak["streak_freeze_count"] > 0
          # Use one freeze
          DB.execute(
            "UPDATE user_streaks 
             SET streak_freeze_count = streak_freeze_count - 1, 
                 last_visit_date = ?, 
                 total_memes_viewed = total_memes_viewed + 1 
             WHERE user_id = ?",
            [today, user_id]
          )
          return { 
            streak_frozen: true, 
            days: streak["current_streak"], 
            freezes_left: streak["streak_freeze_count"] - 1 
          }
        else
          # Streak broken - reset
          old_streak = streak["current_streak"]
          DB.execute(
            "UPDATE user_streaks 
             SET current_streak = 1, last_visit_date = ?, total_memes_viewed = total_memes_viewed + 1 
             WHERE user_id = ?",
            [today, user_id]
          )
          return { 
            streak_broken: true, 
            old_streak: old_streak, 
            new_streak: 1 
          }
        end
      end
    rescue => e
      puts "❌ Error updating streak: #{e.message}"
      nil
    end
  end
  
  # Get user's current streak info
  def get_streak_info(user_id)
    return nil unless user_id
    
    DB.execute(
      "SELECT * FROM user_streaks WHERE user_id = ?",
      [user_id]
    ).first
  end
  
  # ============================================
  # XP & LEVELING SYSTEM
  # ============================================
  
  # Calculate XP required for a given level (exponential growth)
  def xp_for_level(level)
    (100 * (level ** 1.5)).to_i
  end
  
  # Add XP to user and check for level ups
  def add_xp(user_id, activity)
    return nil unless user_id
    
    xp_amount = xp_rewards[activity] || 0
    return { xp_gained: 0, level: 1, leveled_up: false } if xp_amount == 0
    
    begin
      user_level = DB.execute(
        "SELECT * FROM user_levels WHERE user_id = ?",
        [user_id]
      ).first
      
      # Create new level record if doesn't exist
      if user_level.nil?
        DB.execute(
          "INSERT INTO user_levels (user_id, current_xp, total_xp) VALUES (?, ?, ?)",
          [user_id, xp_amount, xp_amount]
        )
        
        # Log activity
        log_xp_activity(user_id, activity, xp_amount)
        
        return { 
          xp_gained: xp_amount, 
          level: 1, 
          leveled_up: false,
          title: 'Meme Novice'
        }
      end
      
      new_xp = user_level["current_xp"] + xp_amount
      new_total_xp = user_level["total_xp"] + xp_amount
      current_level = user_level["level"]
      xp_needed = xp_for_level(current_level + 1)
      
      leveled_up = false
      new_level = current_level
      new_title = user_level["title"]
      
      # Check if leveled up (handle multiple level ups)
      while new_xp >= xp_needed
        leveled_up = true
        new_level += 1
        new_xp -= xp_needed
        xp_needed = xp_for_level(new_level + 1)
        
        # Update title based on level
        new_title = case new_level
        when 1..5 then "Meme Novice"
        when 6..10 then "Casual Browser"
        when 11..20 then "Meme Enthusiast"
        when 21..35 then "Dank Specialist"
        when 36..50 then "Meme Connoisseur"
        when 51..75 then "Viral Legend"
        else "Meme God"
        end
      end
      
      # Update database
      DB.execute(
        "UPDATE user_levels 
         SET current_xp = ?, total_xp = ?, level = ?, title = ?, updated_at = CURRENT_TIMESTAMP 
         WHERE user_id = ?",
        [new_xp, new_total_xp, new_level, new_title, user_id]
      )
      
      # Log activity
      log_xp_activity(user_id, activity, xp_amount)
      
      {
        xp_gained: xp_amount,
        level: new_level,
        leveled_up: leveled_up,
        title: new_title,
        xp_to_next_level: xp_for_level(new_level + 1) - new_xp,
        current_xp: new_xp,
        total_xp: new_total_xp
      }
    rescue => e
      puts "❌ Error adding XP: #{e.message}"
      nil
    end
  end
  
  # Get user's level info
  def get_user_level(user_id)
    return nil unless user_id
    
    level_data = DB.execute(
      "SELECT * FROM user_levels WHERE user_id = ?",
      [user_id]
    ).first
    
    return nil unless level_data
    
    # Calculate XP progress percentage
    next_level_xp = xp_for_level(level_data["level"] + 1)
    xp_progress = (level_data["current_xp"].to_f / next_level_xp * 100).round
    
    level_data.merge({
      "xp_progress" => xp_progress,
      "xp_to_next_level" => next_level_xp - level_data["current_xp"]
    })
  end
  
  # Log XP activity for analytics
  def log_xp_activity(user_id, activity_type, xp_gained)
    DB.execute(
      "INSERT INTO xp_activity_log (user_id, activity_type, xp_gained) VALUES (?, ?, ?)",
      [user_id, activity_type.to_s, xp_gained]
    ) rescue nil
  end
  
  # ============================================
  # COLLECTIONS & BADGES
  # ============================================
  
  # Check and update collection progress for user
  def check_collection_progress(user_id)
    return [] unless user_id
    
    begin
      # Get all collections
      collections = DB.execute("SELECT * FROM meme_collections")
      newly_completed = []
      
      collections.each do |collection|
        # Skip if already completed
        existing = DB.execute(
          "SELECT completed FROM user_collections WHERE user_id = ? AND collection_id = ?",
          [user_id, collection["id"]]
        ).first
        
        next if existing && existing["completed"] == 1
        
        requirements = JSON.parse(collection["required_memes"])
        current_progress = calculate_collection_progress(user_id, requirements)
        required_count = requirements["count"] || 1
        
        # Check if completed
        if current_progress >= required_count
          DB.execute(
            "INSERT OR REPLACE INTO user_collections (user_id, collection_id, progress, completed, completed_at)
             VALUES (?, ?, ?, 1, CURRENT_TIMESTAMP)",
            [user_id, collection["id"], required_count]
          )
          
          # Award XP for completion
          add_xp(user_id, :complete_collection)
          
          newly_completed << collection.merge({ "progress" => current_progress })
        else
          # Update progress
          DB.execute(
            "INSERT OR REPLACE INTO user_collections (user_id, collection_id, progress, completed)
             VALUES (?, ?, ?, 0)",
            [user_id, collection["id"], current_progress]
          )
        end
      end
      
      newly_completed
    rescue => e
      puts "❌ Error checking collections: #{e.message}"
      []
    end
  end
  
  # Calculate user's progress toward a collection
  def calculate_collection_progress(user_id, requirements)
    if requirements["subreddits"]
      # Count views from specific subreddits
      subreddit_list = requirements["subreddits"].join("','")
      count = DB.get_first_value(
        "SELECT COUNT(*) FROM user_meme_exposure ume
         JOIN meme_stats ms ON ume.meme_url = ms.url
         WHERE ume.user_id = ? AND ms.subreddit IN ('#{subreddit_list}')",
        [user_id]
      ).to_i
      return count
      
    elsif requirements["total_views"]
      # Count total unique meme views
      count = DB.get_first_value(
        "SELECT COUNT(*) FROM user_meme_exposure WHERE user_id = ?",
        [user_id]
      ).to_i
      return count
      
    elsif requirements["streak_days"]
      # Check longest streak
      streak = get_streak_info(user_id)
      return streak ? streak["longest_streak"] : 0
    end
    
    0
  end
  
  # Get user's completed collections
  def get_user_collections(user_id)
    return [] unless user_id
    
    DB.execute(
      "SELECT c.*, uc.progress, uc.completed, uc.completed_at
       FROM meme_collections c
       LEFT JOIN user_collections uc ON c.id = uc.collection_id AND uc.user_id = ?
       ORDER BY uc.completed DESC, c.id",
      [user_id]
    )
  end
  
  # ============================================
  # WEEKLY CHALLENGES & LEADERBOARDS
  # ============================================
  
  # Get or create current week's challenge
  def current_weekly_challenge
    week_num = Date.today.strftime("%Y%U").to_i
    
    challenge = DB.execute(
      "SELECT * FROM weekly_challenges WHERE week_number = ?",
      [week_num]
    ).first
    
    # Create challenge if doesn't exist
    if challenge.nil?
      start_of_week = Date.today - Date.today.wday
      end_of_week = start_of_week + 6
      
      challenge_types = [
        { type: "most_likes", desc: "Give the most likes this week!", reward: 500 },
        { type: "streak_keeper", desc: "Maintain a 7-day streak!", reward: 750 },
        { type: "explorer", desc: "View memes from 10 different subreddits!", reward: 600 },
        { type: "social_butterfly", desc: "Save 20 memes this week!", reward: 550 }
      ]
      
      selected = challenge_types.sample
      
      DB.execute(
        "INSERT INTO weekly_challenges (week_number, challenge_type, description, reward_xp, starts_at, ends_at)
         VALUES (?, ?, ?, ?, ?, ?)",
        [week_num, selected[:type], selected[:desc], selected[:reward], start_of_week, end_of_week]
      )
      
      challenge = DB.execute(
        "SELECT * FROM weekly_challenges WHERE week_number = ?",
        [week_num]
      ).first
    end
    
    challenge
  end
  
  # Update weekly leaderboard
  def update_weekly_leaderboard(user_id, metric_increment = 1)
    return unless user_id
    
    week_num = Date.today.strftime("%Y%U").to_i
    
    DB.execute(
      "INSERT INTO weekly_leaderboard (week_number, user_id, metric_value)
       VALUES (?, ?, ?)
       ON CONFLICT (week_number, user_id)
       DO UPDATE SET metric_value = metric_value + ?, updated_at = CURRENT_TIMESTAMP",
      [week_num, user_id, metric_increment, metric_increment]
    ) rescue nil
    
    # Update ranks
    update_leaderboard_ranks(week_num)
  end
  
  # Update ranks for leaderboard
  def update_leaderboard_ranks(week_num)
    # Get all users sorted by metric_value
    users = DB.execute(
      "SELECT id, metric_value FROM weekly_leaderboard 
       WHERE week_number = ? 
       ORDER BY metric_value DESC",
      [week_num]
    )
    
    # Update ranks
    users.each_with_index do |user, index|
      DB.execute(
        "UPDATE weekly_leaderboard SET rank = ? WHERE id = ?",
        [index + 1, user["id"]]
      ) rescue nil
    end
  end
  
  # Get top leaderboard
  def get_leaderboard(week_num = nil, limit = 10)
    week_num ||= Date.today.strftime("%Y%U").to_i
    
    DB.execute(
      "SELECT wl.*, u.reddit_username, u.email, ul.level, ul.title
       FROM weekly_leaderboard wl
       JOIN users u ON wl.user_id = u.id
       LEFT JOIN user_levels ul ON wl.user_id = ul.user_id
       WHERE wl.week_number = ?
       ORDER BY wl.rank ASC
       LIMIT ?",
      [week_num, limit]
    )
  end
  
  # Get user's rank
  def get_my_rank(user_id, week_num = nil)
    return nil unless user_id
    
    week_num ||= Date.today.strftime("%Y%U").to_i
    
    DB.execute(
      "SELECT * FROM weekly_leaderboard WHERE week_number = ? AND user_id = ?",
      [week_num, user_id]
    ).first
  end
end
