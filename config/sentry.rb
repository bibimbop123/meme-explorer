# Sentry error tracking configuration
require 'sentry-ruby'

Sentry.init do |config|
  # FIX: Remove hardcoded DSN fallback - fail gracefully if not configured
  config.dsn = ENV['SENTRY_DSN']
  
  # Disable Sentry if DSN not configured
  if config.dsn.nil? || config.dsn.empty?
    puts "⚠️  Sentry DSN not configured - error tracking disabled"
    config.enabled_environments = []
    return
  end
  
  config.environment = ENV['RACK_ENV'] || 'development'
  config.enabled_environments = %w[production staging development]
  config.release = "meme-explorer@#{File.read('VERSION').strip rescue 'unknown'}"
  
  # Performance monitoring
  config.traces_sample_rate = ENV['SENTRY_TRACES_SAMPLE_RATE']&.to_f || 0.1
  
  # Breadcrumbs
  config.breadcrumbs_logger = [:sentry_logger, :http_logger]
  
  # Error filtering - ignore known safe errors
  config.excluded_exceptions += [
    'Sinatra::NotFound',
    'ActionController::RoutingError'
  ]
  
  # Collect personally identifiable information
  config.send_default_pii = true
  
  # Filter sensitive data before sending to Sentry
  config.before_send = lambda do |event, hint|
    # Remove sensitive fields from request data
    if event.request
      event.request.cookies.clear if event.request.cookies
      if event.request.env
        event.request.env.delete('HTTP_AUTHORIZATION')
        event.request.env.delete('HTTP_X_API_KEY')
      end
    end
    event
  end
end
