# Session Tracker Service
# Comprehensive session tracking with inactivity detection, timeout, and cleanup
# Fixes zombie session issues where sessions stay active with no user engagement

class SessionTrackerService
  # Session tracking constants
  SESSION_TIMEOUT = 1800 # 30 minutes of inactivity before session expires
  ACTIVE_SESSION_WINDOW = 300 # 5 minutes - consider session active if pinged recently
  MIN_MEMES_FOR_VALID_SESSION = 1 # Minimum memes viewed to count as valid session
  INACTIVITY_WARNING_THRESHOLD = 600 # 10 minutes - warn about inactivity
  
  # Heartbeat tracking
  MAX_HEARTBEAT_AGE = 60 # 60 seconds - if no heartbeat, user is likely idle
  
  class << self
    
    # Track session start
    # @param session_id [String] Unique session identifier
    # @param user_id [Integer, nil] User ID if logged in
    # @return [Hash] Session metadata
    def start_session(session_id, user_id: nil)
      return unless redis_available?
      
      timestamp = Time.now.to_i
      
      session_data = {
        session_id: session_id,
        user_id: user_id,
        started_at: timestamp,
        last_activity: timestamp,
        last_heartbeat: timestamp,
        memes_viewed: 0,
        interactions: 0,
        is_active: true,
        total_duration: 0
      }
      
      # Store in Redis with expiry
      REDIS.setex(
        session_key(session_id),
        SESSION_TIMEOUT,
        session_data.to_json
      )
      
      # Add to active sessions set
      REDIS.zadd('active_sessions', timestamp, session_id)
      
      AppLogger.info("🚀 [SESSION] Started: #{session_id[0..7]} (user: #{user_id || 'guest'})")
      
      session_data
    rescue => e
      AppLogger.error("⚠️  [SESSION] Error starting session: #{e.message}")
      nil
    end
    
    # Update session with heartbeat (indicates user is still on page)
    # @param session_id [String] Session identifier
    # @return [Boolean] Success status
    def heartbeat(session_id)
      return false unless redis_available?
      
      session_data = get_session(session_id)
      return false unless session_data
      
      timestamp = Time.now.to_i
      session_data[:last_heartbeat] = timestamp
      session_data[:last_activity] = timestamp
      
      # Update Redis
      REDIS.setex(
        session_key(session_id),
        SESSION_TIMEOUT,
        session_data.to_json
      )
      
      # Update active sessions score
      REDIS.zadd('active_sessions', timestamp, session_id)
      
      true
    rescue => e
      AppLogger.error("⚠️  [SESSION] Heartbeat error: #{e.message}")
      false
    end
    
    # Track session activity (meme view, interaction, etc.)
    # @param session_id [String] Session identifier
    # @param activity_type [String] Type of activity ('view', 'like', 'skip', etc.)
    # @param metadata [Hash] Additional activity metadata
    # @return [Boolean] Success status
    def track_activity(session_id, activity_type, metadata = {})
      return false unless redis_available?
      
      session_data = get_session(session_id)
      return false unless session_data
      
      timestamp = Time.now.to_i
      
      # Update activity counters
      session_data[:last_activity] = timestamp
      session_data[:last_heartbeat] = timestamp
      
      case activity_type
      when 'view'
        session_data[:memes_viewed] = (session_data[:memes_viewed] || 0) + 1
      when 'like', 'skip', 'share', 'save'
        session_data[:interactions] = (session_data[:interactions] || 0) + 1
      end
      
      # Calculate duration
      session_data[:total_duration] = timestamp - session_data[:started_at].to_i
      
      # Save updated session
      REDIS.setex(
        session_key(session_id),
        SESSION_TIMEOUT,
        session_data.to_json
      )
      
      # Update active sessions
      REDIS.zadd('active_sessions', timestamp, session_id)
      
      true
    rescue => e
      AppLogger.error("⚠️  [SESSION] Activity tracking error: #{e.message}")
      false
    end
    
    # Update session metrics (called periodically from client)
    # @param session_id [String] Session identifier
    # @param metrics [Hash] Session metrics (duration, memes_viewed, etc.)
    # @return [Hash] Updated session data
    def update_metrics(session_id, metrics = {})
      return nil unless redis_available?
      
      session_data = get_session(session_id)
      
      # If no session exists, create one
      unless session_data
        session_data = start_session(session_id)
        return session_data unless session_data
      end
      
      timestamp = Time.now.to_i
      
      # Check for inactivity
      last_activity = session_data[:last_activity].to_i
      time_since_activity = timestamp - last_activity
      
      # If too long since last activity and no memes viewed, mark as idle
      if time_since_activity > INACTIVITY_WARNING_THRESHOLD && 
         session_data[:memes_viewed].to_i == 0
        session_data[:is_active] = false
        session_data[:idle_reason] = 'no_engagement'
        
        AppLogger.warn("⚠️  [SESSION] Marking #{session_id[0..7]} as idle (#{time_since_activity}s, 0 memes)")
      end
      
      # Update metrics if provided
      if metrics[:memes_viewed]
        session_data[:memes_viewed] = metrics[:memes_viewed].to_i
        session_data[:last_activity] = timestamp # Memes viewed = activity
        session_data[:is_active] = true # Re-activate if now viewing memes
      end
      
      session_data[:total_duration] = metrics[:duration].to_i if metrics[:duration]
      
      # Calculate average time per meme
      if session_data[:memes_viewed].to_i > 0
        session_data[:avg_time_per_meme] = session_data[:total_duration].to_f / session_data[:memes_viewed].to_i
      end
      
      # Save updated session
      REDIS.setex(
        session_key(session_id),
        SESSION_TIMEOUT,
        session_data.to_json
      )
      
      session_data
    rescue => e
      AppLogger.error("⚠️  [SESSION] Metrics update error: #{e.message}")
      nil
    end
    
    # End session explicitly
    # @param session_id [String] Session identifier
    # @param final_metrics [Hash] Final session metrics
    # @return [Hash] Final session data
    def end_session(session_id, final_metrics = {})
      return nil unless redis_available?
      
      session_data = get_session(session_id)
      return nil unless session_data
      
      # Update with final metrics
      session_data[:ended_at] = Time.now.to_i
      session_data[:is_active] = false
      session_data[:total_duration] = final_metrics[:duration].to_i if final_metrics[:duration]
      session_data[:memes_viewed] = final_metrics[:memes_viewed].to_i if final_metrics[:memes_viewed]
      
      # Calculate final stats
      if session_data[:memes_viewed].to_i > 0
        session_data[:avg_time_per_meme] = session_data[:total_duration].to_f / session_data[:memes_viewed].to_i
        session_data[:engagement_quality] = calculate_engagement_quality(session_data)
      else
        session_data[:engagement_quality] = 'none'
      end
      
      AppLogger.info("🏁 [SESSION] Ended: #{session_id[0..7]} - #{session_data[:memes_viewed]} memes, #{session_data[:total_duration]}s, quality: #{session_data[:engagement_quality]}")
      
      # Remove from active sessions
      REDIS.zrem('active_sessions', session_id)
      
      # Store final session data with shorter TTL
      REDIS.setex(
        "session_final:#{session_id}",
        3600, # Keep final data for 1 hour
        session_data.to_json
      )
      
      # Remove active session key
      REDIS.del(session_key(session_id))
      
      session_data
    rescue => e
      AppLogger.error("⚠️  [SESSION] End session error: #{e.message}")
      nil
    end
    
    # Get session data
    # @param session_id [String] Session identifier
    # @return [Hash, nil] Session data or nil if not found
    def get_session(session_id)
      return nil unless redis_available?
      
      data = REDIS.get(session_key(session_id))
      return nil unless data
      
      JSON.parse(data, symbolize_names: true)
    rescue => e
      nil
    end
    
    # Check if session is active
    # @param session_id [String] Session identifier
    # @return [Boolean] True if session is active
    def active?(session_id)
      session_data = get_session(session_id)
      return false unless session_data
      
      # Check if marked as active
      return false unless session_data[:is_active]
      
      # Check if heartbeat is recent
      last_heartbeat = session_data[:last_heartbeat].to_i
      time_since_heartbeat = Time.now.to_i - last_heartbeat
      
      time_since_heartbeat < MAX_HEARTBEAT_AGE
    end
    
    # Get count of truly active sessions (recent heartbeat + activity)
    # @return [Integer] Number of active sessions
    def active_sessions_count
      return 0 unless redis_available?
      
      cutoff = Time.now.to_i - ACTIVE_SESSION_WINDOW
      
      # Clean up expired sessions
      REDIS.zremrangebyscore('active_sessions', 0, cutoff)
      
      # Count sessions with recent activity
      recent_sessions = REDIS.zrange('active_sessions', cutoff, '+inf', by_score: true)
      
      # Filter to only truly active (have viewed memes or recent heartbeat)
      active_count = 0
      recent_sessions.each do |session_id|
        session_data = get_session(session_id)
        if session_data && session_data[:is_active]
          active_count += 1
        end
      end
      
      active_count
    rescue => e
      AppLogger.error("⚠️  [SESSION] Error counting active sessions: #{e.message}")
      0
    end
    
    # Get detailed session statistics
    # @return [Hash] Session statistics
    def session_stats
      return { active_sessions: 0, redis_available: false } unless redis_available?
      
      cutoff = Time.now.to_i - ACTIVE_SESSION_WINDOW
      REDIS.zremrangebyscore('active_sessions', 0, cutoff)
      
      all_sessions = REDIS.zrange('active_sessions', 0, -1)
      
      active_count = 0
      idle_count = 0
      total_memes = 0
      engaged_sessions = 0
      
      all_sessions.each do |session_id|
        session_data = get_session(session_id)
        next unless session_data
        
        if session_data[:is_active]
          active_count += 1
          if session_data[:memes_viewed].to_i > 0
            engaged_sessions += 1
            total_memes += session_data[:memes_viewed].to_i
          end
        else
          idle_count += 1
        end
      end
      
      {
        active_sessions: active_count,
        idle_sessions: idle_count,
        engaged_sessions: engaged_sessions,
        total_memes_viewed: total_memes,
        avg_memes_per_session: engaged_sessions > 0 ? (total_memes.to_f / engaged_sessions).round(1) : 0,
        timestamp: Time.now.to_i
      }
    rescue => e
      AppLogger.error("⚠️  [SESSION] Stats error: #{e.message}")
      { active_sessions: 0, error: e.message }
    end
    
    # Cleanup expired and zombie sessions
    # @return [Integer] Number of sessions cleaned up
    def cleanup_expired_sessions!
      return 0 unless redis_available?
      
      cutoff = Time.now.to_i - SESSION_TIMEOUT
      
      # Get all sessions older than timeout
      expired_sessions = REDIS.zrangebyscore('active_sessions', 0, cutoff)
      
      cleaned = 0
      expired_sessions.each do |session_id|
        session_data = get_session(session_id)
        
        # End the session if it exists
        if session_data
          end_session(session_id, {
            duration: session_data[:total_duration],
            memes_viewed: session_data[:memes_viewed]
          })
          cleaned += 1
        else
          # Just remove from active set if no data
          REDIS.zrem('active_sessions', session_id)
        end
      end
      
      # Also cleanup zombie sessions (long duration, no engagement)
      zombie_count = cleanup_zombie_sessions!
      
      total_cleaned = cleaned + zombie_count
      AppLogger.info("🧹 [SESSION CLEANUP] Removed #{total_cleaned} sessions (#{cleaned} expired, #{zombie_count} zombies)")
      
      total_cleaned
    rescue => e
      AppLogger.error("⚠️  [SESSION CLEANUP] Error: #{e.message}")
      0
    end
    
    # Cleanup zombie sessions (long running with no engagement)
    # @return [Integer] Number of zombie sessions cleaned
    def cleanup_zombie_sessions!
      return 0 unless redis_available?
      
      all_sessions = REDIS.zrange('active_sessions', 0, -1)
      cleaned = 0
      
      all_sessions.each do |session_id|
        session_data = get_session(session_id)
        next unless session_data
        
        duration = Time.now.to_i - session_data[:started_at].to_i
        memes_viewed = session_data[:memes_viewed].to_i
        
        # Zombie detection: Long duration (>10 min) with no memes viewed
        if duration > 600 && memes_viewed == 0
          AppLogger.info("🧟 [SESSION] Zombie detected: #{session_id[0..7]} (#{duration}s, 0 memes)")
          end_session(session_id, { duration: duration, memes_viewed: 0 })
          cleaned += 1
        end
      end
      
      cleaned
    rescue => e
      AppLogger.error("⚠️  [SESSION] Zombie cleanup error: #{e.message}")
      0
    end
    
    private
    
    def session_key(session_id)
      "session:#{session_id}"
    end
    
    def redis_available?
      defined?(REDIS) && REDIS
    end
    
    def calculate_engagement_quality(session_data)
      memes = session_data[:memes_viewed].to_i
      duration = session_data[:total_duration].to_i
      interactions = session_data[:interactions].to_i
      
      return 'none' if memes == 0
      return 'poor' if memes < 3 && duration > 300
      return 'good' if memes >= 5 || interactions >= 3
      
      avg_time = duration.to_f / memes
      return 'excellent' if avg_time > 10 && interactions >= 2
      
      'fair'
    end
  end
end
