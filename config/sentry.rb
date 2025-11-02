# Sentry error tracking configuration
require 'sentry-ruby'

Sentry.init do |config|
  # Use environment variable or fallback to provided DSN for testing
  config.dsn = ENV['SENTRY_DSN'] || 'https://2025f47967d9c2172b963c34e79c0b71@o4510297986498560.ingest.us.sentry.io/4510297991348224'
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
