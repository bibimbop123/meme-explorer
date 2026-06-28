# Surprise Rewards Service
# Created: May 11, 2026
# Part of: Priority 2 Entertainment Enhancements
#
# Randomly triggers bonus XP and rewards to create delight moments
# Implements variable reward schedules (most addictive game mechanic)

class SurpriseRewardsService
  # Reward types and their probabilities
  REWARD_TYPES = {
    bonus_xp: { probability: 0.15, min: 50, max: 200 },      # 15% chance
    double_xp: { probability: 0.08, duration: 300 },         # 8% chance, 5 min
    streak_freeze: { probability: 0.05, duration: 86400 },   # 5% chance, 24h
    mystery_box: { probability: 0.03 },                      # 3% chance
    lucky_meme: { probability: 0.10 }                        # 10% chance (extra funny)
  }.freeze
  
  # Check if user should receive a surprise reward
  def self.check_for_reward(user_id, action_type = :view_meme)
    return nil unless user_id
    
    # Don't spam rewards - limit to once per 10 minutes per user
    last_reward_key = "user:#{user_id}:last_surprise_reward"
    last_reward_time = REDIS&.get(last_reward_key)
    
    if last_reward_time
      time_since_last = Time.now.to_i - last_reward_time.to_i
      return nil if time_since_last < 600  # 10 minutes cooldown
    end
    
    # Roll for reward
    reward = roll_for_reward
    return nil unless reward
    
    # Grant the reward
    result = grant_reward(user_id, reward)
    
    # Set cooldown
    REDIS&.setex(last_reward_key, 600, Time.now.to_i) if result
    
    result
  rescue => e
    AppLogger.error("❌ Surprise reward error: #{e.message}")
    nil
  end
  
  private
  
  # Roll for a random reward based on probabilities
  def self.roll_for_reward
    roll = rand
    cumulative = 0.0
    
    REWARD_TYPES.each do |type, config|
      cumulative += config[:probability]
      return { type: type, config: config } if roll < cumulative
    end
    
    nil  # No reward this time
  end
  
  # Grant the rolled reward to the user
  def self.grant_reward(user_id, reward)
    case reward[:type]
    when :bonus_xp
      grant_bonus_xp(user_id, reward[:config])
    when :double_xp
      grant_double_xp(user_id, reward[:config])
    when :streak_freeze
      grant_streak_freeze(user_id, reward[:config])
    when :mystery_box
      grant_mystery_box(user_id)
    when :lucky_meme
      grant_lucky_meme(user_id)
    end
  end
  
  # Grant random bonus XP
  def self.grant_bonus_xp(user_id, config)
    amount = rand(config[:min]..config[:max])
    
    # Add XP to user
    DB.execute(
      "UPDATE user_stats SET total_xp = total_xp + ?, updated_at = CURRENT_TIMESTAMP WHERE user_id = ?",
      [amount, user_id]
    )
    
    {
      type: :bonus_xp,
      title: "🎁 Surprise Bonus!",
      message: "You found a surprise gift! +#{amount} XP",
      xp_amount: amount,
      icon: "🎁",
      celebration: "confetti"
    }
  end
  
  # Grant 5-minute double XP boost
  def self.grant_double_xp(user_id, config)
    expires_at = Time.now.to_i + config[:duration]
    
    # Store boost in Redis
    REDIS&.setex("user:#{user_id}:double_xp", config[:duration], expires_at)
    
    {
      type: :double_xp,
      title: "⚡ DOUBLE XP!",
      message: "All XP is doubled for 5 minutes! Go wild!",
      duration: config[:duration],
      icon: "⚡",
      celebration: "fireworks"
    }
  end
  
  # Grant 24-hour streak freeze (protects streak)
  def self.grant_streak_freeze(user_id, config)
    expires_at = Time.now.to_i + config[:duration]
    
    # Store freeze in Redis
    REDIS&.setex("user:#{user_id}:streak_freeze", config[:duration], expires_at)
    
    {
      type: :streak_freeze,
      title: "🛡️ Streak Protection!",
      message: "Your streak is protected for 24 hours! Take a break if you need.",
      duration: config[:duration],
      icon: "🛡️",
      celebration: "shield"
    }
  end
  
  # Grant mystery box (random goodie)
  def self.grant_mystery_box(user_id)
    # Random reward from mystery box
    rewards = [
      { xp: 500, message: "Jackpot! +500 XP" },
      { xp: 300, message: "Nice! +300 XP" },
      { xp: 150, message: "Cool! +150 XP" },
      { xp: 100, message: "Sweet! +100 XP" }
    ]
    
    reward = rewards.sample
    
    DB.execute(
      "UPDATE user_stats SET total_xp = total_xp + ?, updated_at = CURRENT_TIMESTAMP WHERE user_id = ?",
      [reward[:xp], user_id]
    )
    
    {
      type: :mystery_box,
      title: "📦 Mystery Box!",
      message: reward[:message],
      xp_amount: reward[:xp],
      icon: "📦",
      celebration: "explosion"
    }
  end
  
  # Grant lucky meme (next meme will be extra funny)
  def self.grant_lucky_meme(user_id)
    # Flag user's next meme view for bonus
    REDIS&.setex("user:#{user_id}:lucky_meme", 300, "1")  # 5 min expiry
    
    {
      type: :lucky_meme,
      title: "🍀 Lucky Meme!",
      message: "Your next meme will be extra special!",
      icon: "🍀",
      celebration: "sparkle"
    }
  end
  
  # Check if user has active double XP boost
  def self.has_double_xp?(user_id)
    REDIS&.exists("user:#{user_id}:double_xp") || false
  end
  
  # Check if user has active streak freeze
  def self.has_streak_freeze?(user_id)
    REDIS&.exists("user:#{user_id}:streak_freeze") || false
  end
  
  # Check if user has lucky meme active
  def self.has_lucky_meme?(user_id)
    REDIS&.exists("user:#{user_id}:lucky_meme") || false
  end
  
  # Get all active boosts for user
  def self.active_boosts(user_id)
    boosts = []
    
    if has_double_xp?(user_id)
      ttl = REDIS&.ttl("user:#{user_id}:double_xp") || 0
      boosts << { type: :double_xp, icon: "⚡", expires_in: ttl }
    end
    
    if has_streak_freeze?(user_id)
      ttl = REDIS&.ttl("user:#{user_id}:streak_freeze") || 0
      boosts << { type: :streak_freeze, icon: "🛡️", expires_in: ttl }
    end
    
    if has_lucky_meme?(user_id)
      boosts << { type: :lucky_meme, icon: "🍀", expires_in: 300 }
    end
    
    boosts
  end
end
