# Phase 2: Achievement System Service
# Manages user achievements and milestone tracking

class AchievementSystem
  ACHIEVEMENTS = {
    streak_master: {
      name: 'Streak Master',
      icon: '🔥',
      description: 'Maintain a 7-day streak',
      threshold: 7,
      type: :streak,
      rarity: :rare
    },
    liker: {
      name: 'Liker',
      icon: '❤️',
      description: 'Reach 100 total likes',
      threshold: 100,
      type: :lifetime,
      rarity: :common
    },
    comedy_fan: {
      name: 'Comedy Fan',
      icon: '😂',
      description: 'Like 50 funny memes',
      threshold: 50,
      type: :genre,
      genre: 'funny',
      rarity: :common
    },
    dank_connoisseur: {
      name: 'Dank Connoisseur',
      icon: '🔥',
      description: 'Like 50 dank memes',
      threshold: 50,
      type: :genre,
      genre: 'dank',
      rarity: :common
    },
    wholesome_heart: {
      name: 'Wholesome Heart',
      icon: '💚',
      description: 'Like 50 wholesome memes',
      threshold: 50,
      type: :genre,
      genre: 'wholesome',
      rarity: :common
    },
    selfcare_journey: {
      name: 'Self Care Journey',
      icon: '🧘',
      description: 'Like 50 self-care memes',
      threshold: 50,
      type: :genre,
      genre: 'selfcare',
      rarity: :common
    },
    speedrunner: {
      name: 'Speedrunner',
      icon: '🚀',
      description: 'Like 10 memes in one session',
      threshold: 10,
      type: :session,
      rarity: :uncommon
    },
    meme_master: {
      name: 'Meme Master',
      icon: '👑',
      description: 'Reach 500 total likes',
      threshold: 500,
      type: :lifetime,
      rarity: :epic
    }
  }

  STORAGE_KEY = 'achievements_data'

  def initialize
    @data = load_from_storage
    @unlocked = @data['unlocked'] || []
  end

  # Check and unlock new achievements
  def check_milestones(user_stats)
    newly_unlocked = []

    ACHIEVEMENTS.each do |key, achievement|
      next if achievement_unlocked?(key)

      if meets_criteria?(achievement, user_stats)
        unlock_achievement(key)
        newly_unlocked << key
      end
    end

    newly_unlocked
  end

  # Unlock an achievement
  def unlock_achievement(achievement_key)
    return if @unlocked.include?(achievement_key)

    @unlocked << achievement_key
    @data['unlocked'] = @unlocked
    @data["unlocked_at_#{achievement_key}"] = Time.now.to_i
    save_to_storage
  end

  # Check if achievement is already unlocked
  def achievement_unlocked?(achievement_key)
    @unlocked.include?(achievement_key)
  end

  # Get all achievements with unlock status
  def get_all_achievements
    ACHIEVEMENTS.map do |key, achievement|
      {
        key: key,
        **achievement,
        unlocked: achievement_unlocked?(key),
        unlocked_at: @data["unlocked_at_#{key}"]
      }
    end
  end

  # Get unlocked achievements only
  def get_unlocked_achievements
    @unlocked.map do |key|
      achievement = ACHIEVEMENTS[key]
      {
        key: key,
        **achievement,
        unlocked_at: @data["unlocked_at_#{key}"]
      }
    end
  end

  # Get unlock progress for incomplete achievements
  def get_achievement_progress(user_stats)
    progress = {}

    ACHIEVEMENTS.each do |key, achievement|
      next if achievement_unlocked?(key)

      current = case achievement[:type]
                when :lifetime
                  user_stats[:total_likes] || 0
                when :genre
                  user_stats[:genre_likes]&.[](achievement[:genre]) || 0
                when :streak
                  user_stats[:current_streak] || 0
                when :session
                  user_stats[:session_likes] || 0
                end

      progress[key] = {
        current: current,
        threshold: achievement[:threshold],
        percentage: ((current.to_f / achievement[:threshold]) * 100).round(0),
        remaining: achievement[:threshold] - current
      }
    end

    progress
  end

  # Export achievement data for profile/analytics
  def export_analytics
    {
      total_achievements: ACHIEVEMENTS.count,
      unlocked_count: @unlocked.count,
      completion_percentage: ((@unlocked.count.to_f / ACHIEVEMENTS.count) * 100).round(1),
      unlocked_achievements: get_unlocked_achievements,
      rarity_breakdown: calculate_rarity_breakdown
    }
  end

  private

  def load_from_storage
    JSON.parse(localStorage_get(STORAGE_KEY) || '{}')
  rescue
    { 'unlocked' => [] }
  end

  def save_to_storage
    localStorage_set(STORAGE_KEY, @data.to_json)
  end

  def meets_criteria?(achievement, user_stats)
    case achievement[:type]
    when :lifetime
      (user_stats[:total_likes] || 0) >= achievement[:threshold]
    when :genre
      (user_stats[:genre_likes]&.[](achievement[:genre]) || 0) >= achievement[:threshold]
    when :streak
      (user_stats[:current_streak] || 0) >= achievement[:threshold]
    when :session
      (user_stats[:session_likes] || 0) >= achievement[:threshold]
    else
      false
    end
  end

  def calculate_rarity_breakdown
    rarity_counts = ACHIEVEMENTS.group_by { |_, data| data[:rarity] }
      .transform_values { |items| items.count }

    rarity_counts.transform_values do |count|
      {
        total: count,
        unlocked: @unlocked.select { |key| ACHIEVEMENTS[key][:rarity] == rarity_counts.key(count) }.count
      }
    end
  end

  def localStorage_get(key)
    # TODO: Replace with actual storage implementation
    nil
  end

  def localStorage_set(key, value)
    # TODO: Replace with actual storage implementation
  end
end
