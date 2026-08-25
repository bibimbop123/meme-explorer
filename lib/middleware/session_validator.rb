# frozen_string_literal: true

# SessionValidator Middleware
# Date: August 24, 2026
# Purpose: Enterprise-grade session validation and security
# - Session timeout enforcement
# - IP address validation
# - Role synchronization with database
# - Suspicious activity detection

class SessionValidator
  # Session timeout: 24 hours of inactivity
  SESSION_TIMEOUT = 86_400
  
  # Maximum session lifetime: 30 days (even with activity)
  MAX_SESSION_LIFETIME = 2_592_000
  
  # Public routes that don't require session validation
  PUBLIC_ROUTES = [
    %r{^/$},
    %r{^/random},
    %r{^/trending},
    %r{^/login},
    %r{^/signup},
    %r{^/auth/},
    %r{^/about},
    %r{^/contact},
    %r{^/privacy},
    %r{^/terms},
    %r{^/dmca},
    %r{^/guides},
    %r{^/meme/},
    %r{^/public/},
    %r{^/health},
    %r{^/sitemap},
    %r{^/robots\.txt},
    %r{^/ads\.txt},
    %r{^/manifest\.json},
    %r{^/service-worker\.js},
    %r{^/sw\.js}
  ].freeze
  
  def initialize(app)
    @app = app
  end
  
  def call(env)
    request = Rack::Request.new(env)
    session = env['rack.session']
    
    # Skip validation for public routes
    return @app.call(env) if public_route?(request.path)
    
    # Validate session if user is logged in
    if session[:user_id]
      validation_result = validate_session(session, request)
      
      unless validation_result[:valid]
        # Clear invalid session
        session.clear
        env['rack.session'].options[:drop] = true if env['rack.session'].options
        
        AppLogger.warn('[SessionValidator] Session invalidated',
          reason: validation_result[:reason],
          user_id: session[:user_id],
          ip: request.ip
        )
        
        # Return unauthorized response
        return unauthorized_response(request, validation_result[:reason])
      end
      
      # ✅ SECURITY: Sync role from database on each request
      # This ensures session role matches database (prevents privilege escalation)
      sync_role_from_database(session) if session[:user_id]
      
      # Update last activity timestamp
      session[:last_activity] = Time.now.to_i
    end
    
    @app.call(env)
  end
  
  private
  
  def public_route?(path)
    PUBLIC_ROUTES.any? { |pattern| path =~ pattern }
  end
  
  def validate_session(session, request)
    user_id = session[:user_id]
    
    # Check session timeout (inactivity)
    if session[:last_activity]
      last_activity = session[:last_activity].to_i
      if Time.now.to_i - last_activity > SESSION_TIMEOUT
        return { valid: false, reason: 'Session expired due to inactivity' }
      end
    else
      # Set last_activity if not present (for existing sessions)
      session[:last_activity] = Time.now.to_i
    end
    
    # Check maximum session lifetime
    if session[:login_timestamp]
      login_time = session[:login_timestamp].to_i
      if Time.now.to_i - login_time > MAX_SESSION_LIFETIME
        return { valid: false, reason: 'Session expired - maximum lifetime exceeded' }
      end
    end
    
    # ✅ SECURITY: Validate IP address hasn't changed (prevents session hijacking)
    # Allow some flexibility for mobile users (optional - can be made strict)
    if session[:login_ip] && ENV['STRICT_IP_VALIDATION'] == 'true'
      if session[:login_ip] != request.ip
        AppLogger.warn('[SessionValidator] IP address mismatch',
          user_id: user_id,
          login_ip: session[:login_ip],
          current_ip: request.ip
        )
        return { valid: false, reason: 'Session invalid - IP address changed' }
      end
    end
    
    # Verify user still exists in database
    begin
      user = DB.execute("SELECT id, role FROM users WHERE id = ?", [user_id]).first
      unless user
        return { valid: false, reason: 'User no longer exists' }
      end
    rescue => e
      AppLogger.error('[SessionValidator] Database error during validation',
        error: e.message,
        user_id: user_id
      )
      # Fail open to avoid locking everyone out if DB is temporarily down
      return { valid: true }
    end
    
    { valid: true }
  end
  
  def sync_role_from_database(session)
    return unless session[:user_id]
    
    begin
      user = DB.execute("SELECT role FROM users WHERE id = ?", [session[:user_id]]).first
      if user
        db_role = user['role'] || 'user'
        
        # Only update if changed (avoid unnecessary session writes)
        if session[:role] != db_role
          AppLogger.info('[SessionValidator] Role synchronized from database',
            user_id: session[:user_id],
            old_role: session[:role],
            new_role: db_role
          )
          session[:role] = db_role
        end
      end
    rescue => e
      AppLogger.error('[SessionValidator] Failed to sync role from database',
        error: e.message,
        user_id: session[:user_id]
      )
    end
  end
  
  def unauthorized_response(request, reason)
    if request.xhr? || request.content_type == 'application/json'
      [401, 
       {'Content-Type' => 'application/json'},
       [{error: reason, status: 401}.to_json]]
    else
      [302, 
       {'Location' => "/login?expired=1&redirect=#{CGI.escape(request.path)}"},
       []]
    end
  end
end
