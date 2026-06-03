# Error Handler Concern
# Improved error handling patterns for controllers
# Generated: May 19, 2026
# Updated: June 3, 2026 - Integrated with AppLogger (Week 1 Fix)

require_relative '../app_logger'

module ErrorHandler
  # Custom error classes
  class ValidationError < StandardError; end
  class NotFoundError < StandardError; end
  class UnauthorizedError < StandardError; end
  class RateLimitError < StandardError; end
  
  def self.included(base)
    base.extend(ClassMethods)
  end
  
  module ClassMethods
    # Register error handlers for Sinatra
    def register_error_handlers
      error ValidationError do
        handle_error(env['sinatra.error'], 400)
      end
      
      error NotFoundError do
        handle_error(env['sinatra.error'], 404)
      end
      
      error UnauthorizedError do
        handle_error(env['sinatra.error'], 401)
      end
      
      error RateLimitError do
        handle_error(env['sinatra.error'], 429)
      end
      
      error StandardError do
        handle_error(env['sinatra.error'], 500)
      end
    end
  end
  
  # Handle errors with proper logging and response
  def handle_error(error, status_code)
    log_error(error, status_code)
    
    content_type :json
    status status_code
    
    response_body = {
      error: error.message,
      status: status_code
    }
    
    # Add stack trace in development
    if ENV['RACK_ENV'] == 'development'
      response_body[:backtrace] = error.backtrace&.first(10)
    end
    
    response_body.to_json
  end
  
  # Log error with appropriate level and context
  def log_error(error, status_code)
    level = error_level(status_code).downcase.to_sym
    
    context = {
      error_class: error.class.name,
      status_code: status_code,
      path: defined?(request) ? request.path : nil,
      user_id: defined?(session) && session[:user_id] ? session[:user_id] : nil,
      backtrace: error.backtrace&.first(5)
    }.compact
    
    AppLogger.send(level, error.message, **context)
    
    # Send to Sentry for 500 errors
    if defined?(Sentry) && status_code >= 500
      Sentry.capture_exception(error, extra: {
        path: request&.path,
        user_id: session&.[](:user_id),
        params: params,
        request_id: Thread.current[:request_id]
      })
    end
  end
  
  # Determine error level based on status code
  def error_level(status_code)
    case status_code
    when 400..499 then 'WARN'
    when 500..599 then 'ERROR'
    else 'INFO'
    end
  end
  
  # Get emoji for log level
  def level_emoji(level)
    case level
    when 'ERROR' then '❌'
    when 'WARN' then '⚠️'
    when 'INFO' then 'ℹ️'
    else '📝'
    end
  end
  
  # Safe execution with fallback
  def safe_execute(fallback_value = nil, log_context: nil, &block)
    yield
  rescue => e
    AppLogger.warn("Safe execution failed", 
      context: log_context || 'unknown context', 
      error: e.message,
      error_class: e.class.name,
      backtrace: e.backtrace&.first(3)
    )
    
    # Only send critical errors to Sentry
    if defined?(Sentry) && e.is_a?(StandardError) && !e.is_a?(ValidationError)
      Sentry.capture_exception(e, extra: { context: log_context })
    end
    
    fallback_value
  end
  
  # Validate required parameters
  def require_params!(*param_names)
    missing = param_names.select { |p| params[p].nil? || params[p].to_s.strip.empty? }
    
    if missing.any?
      raise ValidationError, "Missing required parameters: #{missing.join(', ')}"
    end
  end
  
  # Validate user authentication
  def require_auth!
    unless session[:user_id]
      raise UnauthorizedError, "Authentication required"
    end
  end
  
  # Validate admin role
  def require_admin!
    require_auth!
    
    user = DB.execute("SELECT role FROM users WHERE id = ?", [session[:user_id]]).first
    unless user && user["role"] == "admin"
      raise UnauthorizedError, "Admin access required"
    end
  end
end
