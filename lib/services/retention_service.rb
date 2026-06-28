# Retention Service
# Phase 6: Get users to come back tomorrow

module MemeExplorer
  class RetentionService
    class << self
      # Track daily streak
      def track_daily_streak(user_id)
        return unless user_id && defined?(DB) && DB
        
        begin
          last_visit = get_last_visit_date(user_id)
          current_streak = get_current_streak(user_id)
          today = Date.today
          
          if last_visit.nil?
            # First visit
            current_streak = 1
          elsif last_visit == today - 1
            # Continued streak
            current_streak += 1
            
            # Streak rewards
            if current_streak == 7
              reward_user(user_id, type: 'weekly_streak', bonus: '+2x XP for today')
            elsif current_streak == 30
              reward_user(user_id, type: 'monthly_legend', bonus: 'Exclusive badge')
            elsif current_streak == 100
              reward_user(user_id, type: 'legendary_streak', bonus: 'Legendary status')
            end
          elsif last_visit < today - 1
            # Streak broken
            if current_streak >= 3
              send_streak_broken_notification(user_id, current_streak)
            end
            current_streak = 1
          elsif last_visit == today
            # Already visited today, no change
            return current_streak
          end
          
          update_streak(user_id, current_streak, today)
          current_streak
        rescue => e
          puts "Streak tracking error: #{e.message}"
          1
        end
      end
      
      # Generate personalized hook for tomorrow
      def generate_tomorrow_hook(user_id)
        return nil unless user_id
        
        preferences = analyze_user_preferences(user_id)
        return nil if preferences.empty?
        
        top_category = preferences.max_by { |k, v| v }[0]
        new_count = count_new_memes_in_category(top_category)
        
        {
          message: "🔥 We found #{new_count} new #{top_category} memes you'll love!",
          preview_count: new_count,
          category: top_category,
          hook_type: 'personal_collection',
          urgency: 'limited_time'
        }
      end
      
      # Show social proof
      def get_social_proof
        active_users = get_active_users_count
        
        return nil if active_users < 5
        
        messages = [
          {
            type: 'active_users',
            icon: '👀',
            message: "#{active_users} people are viewing memes right now"
          },
          {
            type: 'trending',
            icon: '🔥',
            message: "This meme has been liked #{get_recent_likes_count} times today"
          }
        ]
        
        # Add percentile message if user is logged in
        if defined?(session) && session[:user_id]
          percentile = calculate_percentile(session[:user_id])
          if percentile && percentile <= 25
            messages << {
              type: 'percentile',
              icon: '⭐',
              message: "You're in the top #{percentile}% of active memers today!"
            }
          end
        end
        
        messages.sample
      end
      
      # Get streak status for display
      def get_streak_status(user_id)
        return nil unless user_id
        
        current_streak = get_current_streak(user_id)
        next_reward = get_next_reward_at(current_streak)
        
        {
          current_streak: current_streak,
          next_reward_at: next_reward,
          days_until_reward: next_reward ? next_reward - current_streak : nil
        }
      end
      
      private
      
      def get_last_visit_date(user_id)
        return nil unless defined?(DB) && DB
        
        result = DB.execute(
          "SELECT last_visit_date FROM user_streaks WHERE user_id = ? LIMIT 1",
          [user_id]
        ).first
        
        result ? Date.parse(result['last_visit_date']) : nil
      rescue
        nil
      end
      
      def get_current_streak(user_id)
        return 0 unless defined?(DB) && DB
        
        result = DB.execute(
          "SELECT current_streak FROM user_streaks WHERE user_id = ? LIMIT 1",
          [user_id]
        ).first
        
        result ? result['current_streak'].to_i : 0
      rescue
        0
      end
      
      def update_streak(user_id, streak, date)
        return unless defined?(DB) && DB
        
        DB.execute(
          "INSERT INTO user_streaks (user_id, current_streak, last_visit_date, updated_at)
           VALUES (?, ?, ?, ?)
           ON CONFLICT(user_id) DO UPDATE SET
             current_streak   = EXCLUDED.current_streak,
             last_visit_date  = EXCLUDED.last_visit_date,
             updated_at       = EXCLUDED.updated_at",
          [user_id, streak, date.to_s, Time.now]
        )
      rescue => e
        AppLogger.warn("Update streak error", error: e.message, user_id: user_id)
      end
      
      def reward_user(user_id, type:, bonus:)
        return unless user_id && defined?(DB) && DB
        
        begin
          DB.execute(
            "INSERT INTO user_rewards (user_id, reward_type, reward_data, earned_at) VALUES (?, ?, ?, ?)",
            [user_id, type, { bonus: bonus }.to_json, Time.now]
          )
          puts "✅ Streak reward: #{type} awarded to user #{user_id}"
        rescue => e
          puts "Reward error: #{e.message}"
        end
      end
      
      def send_streak_broken_notification(user_id, streak)
        # Log streak break (could send push notification in future)
        puts "🔔 Streak broken for user #{user_id}: #{streak} days"
        
        if defined?(REDIS) && REDIS
          begin
            key = "user:#{user_id}:streak_broken"
            data = { streak: streak, broken_at: Time.now.iso8601 }
            REDIS.setex(key, 86400, data.to_json)  # Store for 24h
          rescue
            # Silent fail
          end
        end
      end
      
      def analyze_user_preferences(user_id)
        # Analyze user's favorite categories based on likes
        return {} unless defined?(DB) && DB
        
        begin
          results = DB.execute(
            "SELECT meme_category, COUNT(*) as count FROM user_likes WHERE user_id = ? GROUP BY meme_category ORDER BY count DESC LIMIT 5",
            [user_id]
          )
          
          results.each_with_object({}) do |row, hash|
            hash[row['meme_category']] = row['count'].to_i
          end
        rescue
          {}
        end
      end
      
      def count_new_memes_in_category(category)
        # Count memes added in last 24 hours for category
        rand(15..35)  # Placeholder - implement based on your data model
      end
      
      def get_active_users_count
        return 0 unless defined?(REDIS) && REDIS
        
        begin
          # Count unique sessions in last 5 minutes
          key = "active_users:#{Time.now.to_i / 300}"  # 5 min buckets
          REDIS.scard(key) || 0
        rescue
          0
        end
      end
      
      def get_recent_likes_count
        return 0 unless defined?(REDIS) && REDIS
        
        begin
          key = "likes_today:#{Date.today}"
          REDIS.get(key).to_i
        rescue
          0
        end
      end
      
      def calculate_percentile(user_id)
        # Calculate user's activity percentile
        return nil unless defined?(DB) && DB
        
        begin
          # Simplified percentile calculation
          total_users = DB.execute("SELECT COUNT(*) as count FROM users").first['count'].to_i
          user_rank = DB.execute(
            "SELECT COUNT(*) as rank FROM users WHERE total_xp > (SELECT total_xp FROM users WHERE id = ?)",
            [user_id]
          ).first['rank'].to_i
          
          ((user_rank.to_f / total_users) * 100).round
        rescue
          nil
        end
      end
      
      def get_next_reward_at(current_streak)
        reward_milestones = [7, 30, 100, 365]
        reward_milestones.find { |m| m > current_streak }
      end
    end
  end
end
