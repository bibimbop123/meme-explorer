# Progressive disclosure of features based on user engagement
module ProgressiveDisclosureHelper
  # Determine what tier of features to show based on session count
  def show_gamification_tier(session_count = 0)
    count = session_count.to_i
    
    case count
    when 0..4
      :minimal  # Just like button - no distractions
    when 5..9
      :basic    # Like + streak badge (if they're returning)
    when 10..19
      :intermediate  # + Level badge
    else
      :full     # Full gamification experience
    end
  end
  
  # Check if a specific feature should be shown
  def show_feature?(feature_name, user_id = nil)
    # Feature must be enabled globally
    return false unless FeatureFlags.enabled?("gamification.features.#{feature_name}")
    
    # If no user, don't show progressive features
    return false unless user_id
    
    session_count = get_user_session_count(user_id)
    tier = show_gamification_tier(session_count)
    
    FEATURE_TIERS[feature_name.to_sym]&.include?(tier) || false
  end
  
  # Get session count for user
  def get_user_session_count(user_id)
    return 0 unless user_id
    
    # Try Redis first
    if defined?(RedisService) && RedisService.redis_available?
      count = RedisService.get("user:#{user_id}:session_count")
      return count.to_i if count
    end
    
    # Fallback to session
    session[:session_count].to_i
  end
  
  # Increment session count
  def increment_session_count(user_id = nil)
    user_id ||= session[:user_id]
    return unless user_id
    
    # Increment in Redis
    if defined?(RedisService) && RedisService.redis_available?
      RedisService.incr("user:#{user_id}:session_count")
    end
    
    # Also track in session
    session[:session_count] = (session[:session_count].to_i + 1)
  end
  
  # Feature tier mapping
  FEATURE_TIERS = {
    like_button: [:minimal, :basic, :intermediate, :full],
    streak_badge: [:basic, :intermediate, :full],
    level_badge: [:intermediate, :full],
    xp_notifications: [:full],
    leaderboard_link: [:full],
    sound_effects: [:full],
    particle_effects: [],  # Never show (disabled)
    push_notifications: [:full]
  }.freeze
end
