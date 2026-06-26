# frozen_string_literal: true

# Enhanced Session Security
# Provides advanced session management and security features
module EnhancedSessionSecurity
  def self.included(base)
    base.extend(ClassMethods)
  end

  module ClassMethods
    # Session configuration
    SESSION_TIMEOUT = 30.minutes
    ABSOLUTE_TIMEOUT = 12.hours
    MAX_SESSIONS_PER_USER = 5
    SESSION_ROTATION_INTERVAL = 15.minutes

    # Initialize session security
    def secure_session(session, user_id, request)
      session[:user_id] = user_id
      session[:created_at] = Time.now.to_i
      session[:last_activity] = Time.now.to_i
      session[:ip_address] = request.ip
      session[:user_agent] = request.user_agent
      session[:rotation_token] = SecureRandom.hex(32)
      
      # Store in database for multi-server support
      store_session_in_db(session[:session_id], user_id, request)
    end

    # Validate session security
    def validate_session(session, request)
      return false unless session[:user_id]
      
      # Check session timeout
      if session_expired?(session)
        return false
      end
      
      # Check IP address consistency (optional - can be disabled for mobile)
      if ENV['STRICT_IP_CHECKING'] == 'true' && session[:ip_address] != request.ip
        log_security_warning('ip_address_mismatch', session, request)
        return false
      end
      
      # Check user agent consistency
      if session[:user_agent] != request.user_agent
        log_security_warning('user_agent_mismatch', session, request)
        return false
      end
      
      # Update last activity
      session[:last_activity] = Time.now.to_i
      
      # Rotate session ID periodically
      rotate_session_if_needed(session)
      
      true
    end

    # Check if session is expired
    def session_expired?(session)
      now = Time.now.to_i
      
      # Absolute timeout
      created_at = session[:created_at] || 0
      return true if (now - created_at) > ABSOLUTE_TIMEOUT
      
      # Inactivity timeout
      last_activity = session[:last_activity] || 0
      return true if (now - last_activity) > SESSION_TIMEOUT
      
      false
    end

    # Rotate session ID
    def rotate_session_if_needed(session)
      return unless session[:last_rotation]
      
      last_rotation = session[:last_rotation] || session[:created_at]
      if (Time.now.to_i - last_rotation) > SESSION_ROTATION_INTERVAL
        old_id = session[:session_id]
        new_id = SecureRandom.hex(32)
        
        # Update session ID
        session[:session_id] = new_id
        session[:last_rotation] = Time.now.to_i
        session[:rotation_token] = SecureRandom.hex(32)
        
        # Update in database
        update_session_id_in_db(old_id, new_id)
      end
    end

    # Destroy all sessions for a user
    def destroy_all_user_sessions(user_id)
      db = get_db_connection
      db.execute('DELETE FROM active_sessions WHERE user_id = ?', [user_id])
    end

    # Get active session count for user
    def active_session_count(user_id)
      db = get_db_connection
      result = db.execute(
        'SELECT COUNT(*) as count FROM active_sessions 
         WHERE user_id = ? AND last_activity > ?',
        [user_id, Time.now.to_i - SESSION_TIMEOUT]
      ).first
      
      result['count']
    end

    # Enforce maximum sessions per user
    def enforce_session_limit(user_id)
      count = active_session_count(user_id)
      if count >= MAX_SESSIONS_PER_USER
        # Remove oldest session
        db = get_db_connection
        db.execute(
          'DELETE FROM active_sessions WHERE user_id = ? 
           ORDER BY last_activity ASC LIMIT 1',
          [user_id]
        )
      end
    end

    private

    def store_session_in_db(session_id, user_id, request)
      db = get_db_connection
      db.execute(
        'INSERT OR REPLACE INTO active_sessions 
         (session_id, user_id, ip_address, user_agent, created_at, last_activity) 
         VALUES (?, ?, ?, ?, ?, ?)',
        [session_id, user_id, request.ip, request.user_agent, 
         Time.now.to_i, Time.now.to_i]
      )
      
      enforce_session_limit(user_id)
    rescue => e
      warn "Failed to store session: #{e.message}"
    end

    def update_session_id_in_db(old_id, new_id)
      db = get_db_connection
      db.execute(
        'UPDATE active_sessions SET session_id = ? WHERE session_id = ?',
        [new_id, old_id]
      )
    rescue => e
      warn "Failed to update session ID: #{e.message}"
    end

    def log_security_warning(type, session, request)
      warn "Security Warning: #{type} for user #{session[:user_id]} from #{request.ip}"
      
      db = get_db_connection
      db.execute(
        'INSERT INTO security_audit_log 
         (user_id, event_type, ip_address, user_agent, details, created_at) 
         VALUES (?, ?, ?, ?, ?, ?)',
        [session[:user_id], type, request.ip, request.user_agent, 
         { old_ip: session[:ip_address], new_ip: request.ip }.to_json, 
         Time.now]
      )
    rescue => e
      warn "Failed to log security warning: #{e.message}"
    end

    def get_db_connection
      require_relative '../db_helpers'
      get_db_connection
    end
  end
end
