# Sentry error tracking configuration
# MANDATORY for production - ensures all errors are tracked
require 'sentry-ruby'

# STRICT: Require Sentry DSN in production
if ENV['RACK_ENV'] == 'production' && ENV['SENTRY_DSN'].to_s.strip.empty?
  raise "FATAL ERROR: SENTRY_DSN environment variable is REQUIRED in production mode!"
end

Sentry.init do |config|
  sentry_dsn = ENV['SENTRY_DSN']
  
  # Gracefully disable in development if not configured
  if sentry_dsn.nil? || sentry_dsn.to_s.strip.empty?
    if ENV['RACK_ENV'] == 'production'
      raise "FATAL: Sentry DSN missing in production!"
    else
      puts "⚠️  Sentry DSN not configured - error tracking disabled (development mode)"
      config.enabled_environments = []
      return
    end
  end
  
  config.dsn = sentry_dsn
  
  # Environment configuration
  config.environment = ENV['RACK_ENV'] || 'development'
  config.enabled_environments = %w[production staging development]
  config.release = "meme-explorer@#{File.read('VERSION').strip rescue 'unknown'}"
  
  # Performance monitoring - adaptive sampling
  config.traces_sample_rate = case ENV['RACK_ENV']
                               when 'production'
                                 ENV['SENTRY_TRACES_SAMPLE_RATE']&.to_f || 0.2  # 20% in production
                               when 'staging'
                                 0.5  # 50% in staging
                               else
                                 1.0  # 100% in development
                               end
  
  # Enhanced breadcrumbs
  config.breadcrumbs_logger = [:sentry_logger, :http_logger]
  
  # Error filtering - ignore known safe errors
  config.excluded_exceptions += [
    'Sinatra::NotFound',
    'ActionController::RoutingError',
    'Rack::Attack::Throttle',
    'Rack::Timeout::RequestTimeoutException'
  ]
  
  # Privacy: DO NOT send PII
  config.send_default_pii = false
  
  # Sanitize sensitive fields
  config.sanitize_fields = [
    'password',
    'password_confirmation',
    'secret',
    'api_key',
    'access_token',
    'refresh_token',
    'session_secret',
    'reddit_client_secret'
  ]
  
  # Enhanced error context
  config.before_send = lambda do |event, hint|
    # Remove sensitive headers and cookies
    if event.request
      event.request.cookies.clear if event.request.cookies
      if event.request.env
        event.request.env.delete('HTTP_AUTHORIZATION')
        event.request.env.delete('HTTP_X_API_KEY')
        event.request.env.delete('HTTP_COOKIE')
      end
    end
    
    # Add helpful context
    event.extra[:server_time] = Time.now.iso8601
    event.extra[:ruby_version] = RUBY_VERSION
    event.extra[:rack_env] = ENV['RACK_ENV']
    
    event
  end
  
  puts "✅ Sentry error tracking initialized (Environment: #{config.environment}, Sample Rate: #{config.traces_sample_rate})"
end
