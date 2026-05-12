# Milestone Service
# Celebrates user achievements to drive continued engagement

module MemeExplorer
  class MilestoneService
    MILESTONES = {
      5 => {
        badge: 'getting_started',
        title: '🎉 First 5!',
        message: "You're getting the hang of this!",
        reward_type: 'encouragement'
      },
      10 => {
        badge: 'on_fire',
        title: '🔥 10 Memes!',
        message: "You're on fire! Keep going!",
        reward_type: 'streak_bonus'
      },
      25 => {
        badge: 'explorer',
        title: '🌟 Meme Explorer!',
        message: "25 memes! You're a true explorer!",
        reward_type: 'badge_unlock'
      },
      50 => {
        badge: 'legendary_unlock',
        title: '👑 LEGENDARY!',
        message: "50 memes! LEGENDARY content unlocked!",
        reward_type: 'content_unlock'
      },
      100 => {
        badge: 'century_club',
        title: '💯 Century Club!',
        message: "100 memes! You're in the Century Club!",
        reward_type: 'exclusive_badge'
      },
      250 => {
        badge: 'meme_master',
        title: '🏆 Meme Master!',
        message: "250 memes! You've mastered the art!",
        reward_type: 'master_badge'
      },
      500 => {
        badge: 'meme_legend',
        title: '⭐ MEME LEGEND!',
        message: "500 memes! You are LEGENDARY!",
        reward_type: 'legend_status'
      },
      1000 => {
        badge: 'meme_god',
        title: '👹 MEME GOD!',
        message: "1000 memes! You've ascended!",
        reward_type: 'god_status'
      }
    }
    
    class << self
      # Check if user just hit a milestone
      def check_milestone(view_count)
        MILESTONES[view_count]
      end
      
      # Get milestone progress (next milestone and % complete)
      def get_progress(view_count)
        next_milestone = MILESTONES.keys.sort.find { |m| m > view_count }
        
        if next_milestone
          previous_milestone = MILESTONES.keys.sort.reverse.find { |m| m <= view_count } || 0
          progress = ((view_count - previous_milestone).to_f / (next_milestone - previous_milestone) * 100).round
          
          {
            current_count: view_count,
            next_milestone: next_milestone,
            progress_percent: progress,
            memes_until_next: next_milestone - view_count
          }
        else
          # Past all milestones
          {
            current_count: view_count,
            next_milestone: nil,
            progress_percent: 100,
            status: 'legendary'
          }
        end
      end
      
      # Award milestone achievement
      def award_milestone(user_id, milestone_data)
        return unless user_id && defined?(DB) && DB
        
        begin
          # Store in user_achievements table
          DB.execute(
            "INSERT INTO user_achievements (user_id, achievement_type, achievement_data, earned_at) VALUES (?, ?, ?, ?)",
            [user_id, 'milestone', milestone_data.to_json, Time.now]
          )
          
          # Add XP reward
          xp_amount = calculate_xp_reward(milestone_data[:badge])
          add_xp(user_id, xp_amount, "Milestone: #{milestone_data[:title]}")
          
          # Track in Redis for real-time display
          if defined?(REDIS) && REDIS
            key = "user:#{user_id}:recent_milestones"
            REDIS.lpush(key, milestone_data.to_json)
            REDIS.ltrim(key, 0, 9)  # Keep last 10
            REDIS.expire(key, 30 * 86400)  # 30 days
          end
          
          puts "✅ Milestone awarded: #{milestone_data[:title]} to user #{user_id}"
          true
        rescue => e
          puts "❌ Milestone award error: #{e.message}"
          false
        end
      end
      
      # Get user's earned milestones
      def get_earned_milestones(user_id)
        return [] unless user_id && defined?(DB) && DB
        
        begin
          results = DB.execute(
            "SELECT achievement_data, earned_at FROM user_achievements WHERE user_id = ? AND achievement_type = 'milestone' ORDER BY earned_at DESC",
            [user_id]
          )
          
          results.map do |row|
            data = JSON.parse(row['achievement_data'])
            data['earned_at'] = row['earned_at']
            data
          end
        rescue => e
          puts "Get milestones error: #{e.message}"
          []
        end
      end
      
      # Calculate XP reward based on milestone tier
      def calculate_xp_reward(badge_type)
        rewards = {
          'getting_started' => 50,
          'on_fire' => 100,
          'explorer' => 250,
          'legendary_unlock' => 500,
          'century_club' => 1000,
          'meme_master' => 2500,
          'meme_legend' => 5000,
          'meme_god' => 10000
        }
        
        rewards[badge_type] || 100
      end
      
      private
      
      def add_xp(user_id, amount, reason)
        return unless defined?(DB) && DB
        
        begin
          DB.execute(
            "INSERT INTO user_xp_log (user_id, xp_amount, reason, created_at) VALUES (?, ?, ?, ?)",
            [user_id, amount, reason, Time.now]
          )
          
          # Update total XP
          DB.execute(
            "UPDATE users SET total_xp = COALESCE(total_xp, 0) + ? WHERE id = ?",
            [amount, user_id]
          )
        rescue => e
          puts "XP award error: #{e.message}"
        end
      end
    end
  end
end
