# EngagementService
# Comprehensive service for handling all engagement actions (likes, saves, shares)
# Integrates with gamification, leaderboards, metrics, and activity tracking
# Created: June 3, 2026

class EngagementService
  class << self
    # Track a like action with full integration
    # @param user_id [Integer] User performing the action
    # @param meme_url [String] URL of meme being liked
    # @param liked_now [Boolean] Whether this is a like (true) or unlike (false)
    # @param session [Hash] Session data
    # @param db [SQLite3::Database] Database connection
    # @return [Hash] Result with likes count and XP awarded
    def track_like(user_id:, meme_url:, liked_now:, session: {}, db: nil)
      db ||= defined?(DB) ? ::DB : nil
      return { error: 'Database not available', likes: 0 } unless db && meme_url
      
      result = {
        success: false,
        liked: liked_now,
        likes: 0,
        xp_awarded: 0,
        level_up: false
      }
      
      begin
        # 1. Update meme_stats table
        ensure_meme_stats_exists(meme_url, db)
        
        if liked_now
          db.execute("UPDATE meme_stats SET likes = likes + 1, updated_at = CURRENT_TIMESTAMP WHERE url = ?", [meme_url])
          puts "✅ [ENGAGEMENT] Like recorded for: #{meme_url[0..50]}..."
        else
          db.execute("UPDATE meme_stats SET likes = CASE WHEN likes > 0 THEN likes - 1 ELSE 0 END, updated_at = CURRENT_TIMESTAMP WHERE url = ?", [meme_url])
          puts "✅ [ENGAGEMENT] Unlike recorded for: #{meme_url[0..50]}..."
        end
        
        result[:likes] = get_likes_count(meme_url, db)
        
        # 2. Log activity for metrics (time-based tracking)
        log_activity(user_id, meme_url, liked_now ? 'like' : 'unlike', session, db)
        
        # 3. Update user_meme_stats (user-specific tracking)
        update_user_meme_stats(user_id, meme_url, liked_now, db) if user_id
        
        # 4. Award XP and update gamification (only for likes, not unlikes)
        if liked_now && user_id
          xp_result = award_xp(user_id, :like_meme, db)
          if xp_result
            result[:xp_awarded] = xp_result[:xp_gained] || 0
            result[:level_up] = xp_result[:leveled_up] || false
            result[:new_level] = xp_result[:level] if xp_result[:leveled_up]
          end
        end
        
        # 5. Update weekly leaderboard
        update_weekly_leaderboard(user_id, 'like', db) if user_id
        
        # 6. Record in ActivityTrackerService (Redis for real-time stats)
        ActivityTrackerService.record_action('like', user_id) if user_id && liked_now
        
        result[:success] = true
        result
      rescue => e
        puts "❌ [ENGAGEMENT] Error tracking like: #{e.message}"
        puts e.backtrace.first(3)
        result[:error] = e.message
        result
      end
    end
    
    # Track a save action with full integration
    # @param user_id [Integer] User performing the action
    # @param meme_url [String] URL of meme being saved
    # @param title [String] Meme title
    # @param subreddit [String] Meme subreddit
    # @param saved_now [Boolean] Whether this is a save (true) or unsave (false)
    # @param session [Hash] Session data
    # @param db [SQLite3::Database] Database connection
    # @return [Hash] Result with save status and XP awarded
    def track_save(user_id:, meme_url:, title: 'Unknown', subreddit: 'unknown', saved_now: true, session: {}, db: nil)
      db ||= defined?(DB) ? ::DB : nil
      return { error: 'Database not available', saved: false } unless db && meme_url && user_id
      
      result = {
        success: false,
        saved: saved_now,
        xp_awarded: 0,
        level_up: false
      }
      
      begin
        # 1. Update saved_memes table
        if saved_now
          # Check if already saved
          existing = db.execute(
            "SELECT id FROM saved_memes WHERE user_id = ? AND meme_url = ?",
            [user_id, meme_url]
          ).first
          
          unless existing
            db.execute(
              "INSERT INTO saved_memes (user_id, meme_url, meme_title, meme_subreddit, created_at) VALUES (?, ?, ?, ?, CURRENT_TIMESTAMP)",
              [user_id, meme_url, title, subreddit]
            )
            puts "✅ [ENGAGEMENT] Save recorded for user #{user_id}"
          end
        else
          # Unsave
          db.execute(
            "DELETE FROM saved_memes WHERE user_id = ? AND meme_url = ?",
            [user_id, meme_url]
          )
          puts "✅ [ENGAGEMENT] Unsave recorded for user #{user_id}"
        end
        
        # 2. Log activity for metrics
        log_activity(user_id, meme_url, saved_now ? 'save' : 'unsave', session, db)
        
        # 3. Award XP for saves (only for saves, not unsaves)
        if saved_now
          xp_result = award_xp(user_id, :save_meme, db)
          if xp_result
            result[:xp_awarded] = xp_result[:xp_gained] || 0
            result[:level_up] = xp_result[:leveled_up] || false
            result[:new_level] = xp_result[:level] if xp_result[:leveled_up]
          end
        end
        
        # 4. Update weekly leaderboard
        update_weekly_leaderboard(user_id, 'save', db) if saved_now
        
        # 5. Record in ActivityTrackerService (Redis)
        ActivityTrackerService.record_action('save', user_id) if saved_now
        
        # 6. Check collection progress (badges/achievements)
        check_collections(user_id, db) if saved_now
        
        result[:success] = true
        result
      rescue => e
        puts "❌ [ENGAGEMENT] Error tracking save: #{e.message}"
        puts e.backtrace.first(3)
        result[:error] = e.message
        result
      end
    end
    
    # Check if user has liked a meme
    # @param user_id [Integer] User ID
    # @param meme_url [String] Meme URL
    # @param db [SQLite3::Database] Database connection
    # @return [Boolean] Whether user has liked this meme
    def user_liked?(user_id:, meme_url:, db: nil)
      db ||= defined?(DB) ? ::DB : nil
      return false unless db && user_id && meme_url
      
      result = db.execute(
        "SELECT id FROM user_liked_memes WHERE user_id = ? AND meme_url = ?",
        [user_id, meme_url]
      ).first
      
      !result.nil?
    rescue => e
      false
    end
    
    # Check if user has saved a meme
    # @param user_id [Integer] User ID
    # @param meme_url [String] Meme URL
    # @param db [SQLite3::Database] Database connection
    # @return [Boolean] Whether user has saved this meme
    def user_saved?(user_id:, meme_url:, db: nil)
      db ||= defined?(DB) ? ::DB : nil
      return false unless db && user_id && meme_url
      
      result = db.execute(
        "SELECT id FROM saved_memes WHERE user_id = ? AND meme_url = ?",
        [user_id, meme_url]
      ).first
      
      !result.nil?
    rescue => e
      false
    end
    
    # Get comprehensive engagement stats for a user
    # @param user_id [Integer] User ID
    # @param db [SQLite3::Database] Database connection
    # @return [Hash] User engagement statistics
    def user_stats(user_id:, db: nil)
      db ||= defined?(DB) ? ::DB : nil
      return {} unless db && user_id
      
      {
        total_likes: count_user_likes(user_id, db),
        total_saves: count_user_saves(user_id, db),
        total_xp: get_user_xp(user_id, db),
        level: get_user_level(user_id, db),
        weekly_rank: get_weekly_rank(user_id, db),
        current_streak: get_current_streak(user_id, db)
      }
    rescue => e
      puts "❌ [ENGAGEMENT] Error getting user stats: #{e.message}"
      {}
    end
    
    private
    
    # Ensure meme_stats record exists (PostgreSQL compatible)
    def ensure_meme_stats_exists(meme_url, db)
      db.execute(
        "INSERT INTO meme_stats (url, title, subreddit, likes, views) 
         VALUES (?, ?, ?, 0, 0) 
         ON CONFLICT (url) DO NOTHING",
        [meme_url, 'Unknown', 'unknown']
      )
    end
    
    # Get current likes count
    def get_likes_count(meme_url, db)
      result = db.execute("SELECT likes FROM meme_stats WHERE url = ?", [meme_url]).first
      result ? result['likes'].to_i : 0
    end
    
    # Log activity to meme_activity_log
    def log_activity(user_id, meme_url, activity_type, session, db)
      session_id = session[:visitor_id] || session[:user_id] rescue nil
      
      db.execute(
        "INSERT INTO meme_activity_log (meme_url, activity_type, user_id, session_id, created_at) VALUES (?, ?, ?, ?, CURRENT_TIMESTAMP)",
        [meme_url, activity_type, user_id, session_id]
      )
    rescue SQLite3::SQLException => e
      # Table might not exist yet - fail gracefully
      puts "⚠️ [ENGAGEMENT] Activity log insert skipped: #{e.message}" unless e.message =~ /no such table/
    end
    
    # Update user_meme_stats table
    def update_user_meme_stats(user_id, meme_url, liked_now, db)
      if liked_now
        db.execute(
          "INSERT INTO user_meme_stats (user_id, meme_url, liked, liked_at, updated_at) 
           VALUES (?, ?, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
           ON CONFLICT(user_id, meme_url) DO UPDATE SET 
           liked = 1, liked_at = CURRENT_TIMESTAMP, updated_at = CURRENT_TIMESTAMP",
          [user_id, meme_url]
        )
      else
        db.execute(
          "UPDATE user_meme_stats SET liked = 0, unliked_at = CURRENT_TIMESTAMP, updated_at = CURRENT_TIMESTAMP 
           WHERE user_id = ? AND meme_url = ?",
          [user_id, meme_url]
        )
      end
    rescue SQLite3::SQLException => e
      # Table might not exist yet
      puts "⚠️ [ENGAGEMENT] user_meme_stats update skipped: #{e.message}" unless e.message =~ /no such table/
    end
    
    # Award XP using GamificationHelpers
    def award_xp(user_id, activity_type, db)
      return nil unless defined?(GamificationHelpers)
      
      # Use a helper object that includes GamificationHelpers
      helper = Object.new
      helper.extend(GamificationHelpers)
      
      # Temporarily set DB constant if not set
      original_db = defined?(::DB) ? ::DB : nil
      Object.const_set(:DB, db) unless defined?(::DB)
      
      result = helper.add_xp(user_id, activity_type)
      
      # Restore original DB constant
      Object.const_set(:DB, original_db) if original_db && !defined?(::DB)
      
      result
    rescue => e
      puts "⚠️ [ENGAGEMENT] XP award failed: #{e.message}"
      nil
    end
    
    # Update weekly leaderboard
    def update_weekly_leaderboard(user_id, action_type, db)
      week_num = Date.today.strftime("%Y%U").to_i
      
      # Increment metric value based on action type
      increment = case action_type
                  when 'like' then 1
                  when 'save' then 2  # Saves worth more
                  when 'share' then 3  # Shares worth most
                  else 1
                  end
      
      db.execute(
        "INSERT INTO weekly_leaderboard (week_number, user_id, metric_value, updated_at)
         VALUES (?, ?, ?, CURRENT_TIMESTAMP)
         ON CONFLICT (week_number, user_id)
         DO UPDATE SET metric_value = metric_value + ?, updated_at = CURRENT_TIMESTAMP",
        [week_num, user_id, increment, increment]
      )
      
      # Update ranks (could be done async in production)
      update_leaderboard_ranks(week_num, db)
    rescue SQLite3::SQLException => e
      puts "⚠️ [ENGAGEMENT] Leaderboard update skipped: #{e.message}" unless e.message =~ /no such table/
    end
    
    # Update leaderboard ranks
    def update_leaderboard_ranks(week_num, db)
      # Get all users sorted by metric_value
      users = db.execute(
        "SELECT id, metric_value FROM weekly_leaderboard 
         WHERE week_number = ? 
         ORDER BY metric_value DESC",
        [week_num]
      )
      
      # Update ranks
      users.each_with_index do |user, index|
        db.execute(
          "UPDATE weekly_leaderboard SET rank = ? WHERE id = ?",
          [index + 1, user['id']]
        )
      end
    rescue => e
      puts "⚠️ [ENGAGEMENT] Rank update failed: #{e.message}"
    end
    
    # Check collection progress after save
    def check_collections(user_id, db)
      return unless defined?(GamificationHelpers)
      
      helper = Object.new
      helper.extend(GamificationHelpers)
      
      # Temporarily set DB if needed
      original_db = defined?(::DB) ? ::DB : nil
      Object.const_set(:DB, db) unless defined?(::DB)
      
      helper.check_collection_progress(user_id)
      
      Object.const_set(:DB, original_db) if original_db && !defined?(::DB)
    rescue => e
      puts "⚠️ [ENGAGEMENT] Collection check failed: #{e.message}"
    end
    
    # Count user's total likes
    def count_user_likes(user_id, db)
      result = db.execute(
        "SELECT COUNT(*) as count FROM user_liked_memes WHERE user_id = ?",
        [user_id]
      ).first
      result ? result['count'].to_i : 0
    rescue => e
      0
    end
    
    # Count user's total saves
    def count_user_saves(user_id, db)
      result = db.execute(
        "SELECT COUNT(*) as count FROM saved_memes WHERE user_id = ?",
        [user_id]
      ).first
      result ? result['count'].to_i : 0
    rescue => e
      0
    end
    
    # Get user's total XP
    def get_user_xp(user_id, db)
      result = db.execute(
        "SELECT total_xp FROM user_levels WHERE user_id = ?",
        [user_id]
      ).first
      result ? result['total_xp'].to_i : 0
    rescue => e
      0
    end
    
    # Get user's level
    def get_user_level(user_id, db)
      result = db.execute(
        "SELECT level FROM user_levels WHERE user_id = ?",
        [user_id]
      ).first
      result ? result['level'].to_i : 1
    rescue => e
      1
    end
    
    # Get user's weekly rank
    def get_weekly_rank(user_id, db)
      week_num = Date.today.strftime("%Y%U").to_i
      result = db.execute(
        "SELECT rank FROM weekly_leaderboard WHERE week_number = ? AND user_id = ?",
        [week_num, user_id]
      ).first
      result ? result['rank'].to_i : nil
    rescue => e
      nil
    end
    
    # Get user's current streak
    def get_current_streak(user_id, db)
      result = db.execute(
        "SELECT current_streak FROM user_streaks WHERE user_id = ?",
        [user_id]
      ).first
      result ? result['current_streak'].to_i : 0
    rescue => e
      0
    end
  end
end
