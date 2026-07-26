# frozen_string_literal: true

# Authorization Middleware
# Date: July 26, 2026
# Purpose: Centralized route-level authorization enforcement

class AuthorizationMiddleware
  def initialize(app)
    @app = app
  end
  
  def call(env)
    request = Rack::Request.new(env)
    path = env['PATH_INFO']
    session = env['rack.session']
    
    # Check admin routes
    if requires_admin?(path)
      unless session[:user_id] && session[:role] == 'admin'
        return unauthorized_response(request, 'Admin access required')
      end
    end
    
    # Check moderator routes
    if requires_moderator?(path)
      unless session[:user_id] && ['admin', 'moderator'].include?(session[:role])
        return unauthorized_response(request, 'Moderator access required')
      end
    end
    
    # Check authenticated routes
    if requires_login?(path)
      unless session[:user_id]
        return unauthenticated_response(request)
      end
    end
    
    # Continue to next middleware/app
    @app.call(env)
  end
  
  private
  
  # Admin-only routes
  ADMIN_ROUTES = [
    %r{^/admin},
    %r{^/users/.*/role},
    %r{^/permissions}
  ].freeze
  
  # Moderator routes
  MODERATOR_ROUTES = [
    %r{^/moderate}
  ].freeze
  
  # Login required routes
  LOGIN_REQUIRED_ROUTES = [
    %r{^/profile},
    %r{^/saved},
    %r{^/collections},
    %r{^/premium}
  ].freeze
  
  # Public routes that don't need auth
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
    %r{^/guides},
    %r{^/public/},
    %r{^/health}
  ].freeze
  
  def requires_admin?(path)
    ADMIN_ROUTES.any? { |pattern| path =~ pattern }
  end
  
  def requires_moderator?(path)
    MODERATOR_ROUTES.any? { |pattern| path =~ pattern }
  end
  
  def requires_login?(path)
    return false if PUBLIC_ROUTES.any? { |pattern| path =~ pattern }
    LOGIN_REQUIRED_ROUTES.any? { |pattern| path =~ pattern }
  end
  
  def unauthorized_response(request, message)
    if request.xhr? || request.content_type == 'application/json'
      # JSON response for API requests
      [403, 
       {'Content-Type' => 'application/json'},
       [{error: message, status: 403}.to_json]]
    else
      # HTML response for browser requests
      [403, 
       {'Content-Type' => 'text/html'},
       ["<h1>403 Forbidden</h1><p>#{message}</p><a href='/'>Go Home</a>"]]
    end
  end
  
  def unauthenticated_response(request)
    if request.xhr? || request.content_type == 'application/json'
      [401, 
       {'Content-Type' => 'application/json'},
       [{error: 'Login required', status: 401}.to_json]]
    else
      # Redirect to login
      [302, 
       {'Location' => "/login?redirect=#{CGI.escape(request.path)}"},
       []]
    end
  end
end
