# Sentry error tracking configuration
require 'sentry-ruby'

Sentry.init do |config|
  config.dsn = ENV['SENTRY_DSN']
  config.environment = ENV['RACK_ENV'] || 'development'
  config.enabled_environments = %w[production staging]
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
  
  # Sensitive data - don't send
  config.sanitize_fields = %w[
    password
    password_confirmation
    authorization
    token
    access_token
    refresh_token
    api_key
  ]
end
