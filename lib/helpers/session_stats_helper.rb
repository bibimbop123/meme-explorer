# frozen_string_literal: true

# Session Statistics Helper
# Shows user their session progress and engagement
# Created: June 28, 2026

module SessionStatsHelper
  # Get count of memes viewed in this session
  def session_meme_count(session_id)
    return 0 unless session_id && defined?(REDIS) && REDIS
    
    begin
      REDIS.llen("session:#{session_id}:recent").to_i
    rescue => e
      AppLogger.warn("[SessionStats] Error getting meme count: #{e.message}")
      0
    end
  end
  
  # Get session duration in minutes
  def session_duration_minutes(session_id)
    return 0 unless session_id && defined?(REDIS) && REDIS
    
    begin
      start_time_str = REDIS.get("session:#{session_id}:start_time")
      return 0 unless start_time_str
      
      start_time = Time.parse(start_time_str)
      ((Time.now - start_time) / 60).round
    rescue => e
      AppLogger.warn("[SessionStats] Error getting duration: #{e.message}")
      0
    end
  end
  
  # Initialize session start time if not exists
  def track_session_start(session_id)
    return unless session_id && defined?(REDIS) && REDIS
    
    begin
      key = "session:#{session_id}:start_time"
      unless REDIS.exists(key)
        REDIS.setex(key, 7200, Time.now.to_s) # 2 hour TTL
      end
    rescue => e
      AppLogger.warn("[SessionStats] Error tracking session start: #{e.message}")
    end
  end
  
  # Render session stats badge HTML
  def render_session_stats(session_id)
    return '' unless session_id
    
    track_session_start(session_id)
    count = session_meme_count(session_id)
    duration = session_duration_minutes(session_id)
    
    return '' if count.zero?
    
    # Build stats string
    stats = "#{count} meme#{count == 1 ? '' : 's'}"
    stats += " • #{duration}m" if duration > 0
    
    <<~HTML
      <div class="session-stats-badge" title="Session progress">
        <svg class="stats-icon" width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor">
          <circle cx="12" cy="12" r="10"/>
          <polyline points="12 6 12 12 16 14"/>
        </svg>
        <span class="stats-text">#{stats}</span>
      </div>
    HTML
  end
end
