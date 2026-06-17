# frozen_string_literal: true

# Session Store Configuration for Horizontal Scaling
# Based on: REFACTORING_ROADMAP Phase 4, Task 6.4
# Uses Redis to persist sessions across multiple app instances

require 'rack/session/redis'

# Session configuration
SESSION_CONFIG = {
  # Use Redis for session storage (required for multiple instances)
  redis_server: REDIS_POOL,
  
  # Session expiration
  expire_after: 30 * 24 * 60 * 60, # 30 days
  
  # Cookie configuration
  key: '_meme_explorer_session',
  secure: ENV['RACK_ENV'] == 'production',
  httponly: true,
  same_site: :lax,
  
  # Session ID configuration
  sid_length: 64,
  sid_secure: :random,
  
  # Cookie domain (for CDN compatibility)
  domain: ENV['SESSION_DOMAIN'] # e.g., '.meme-explorer.com'
}.freeze

# Configure Sinatra to use Redis sessions
# Add to app.rb:
#   use Rack::Session::Redis, SESSION_CONFIG

AppLogger.info("Session store configured", 
  storage: 'Redis',
  expire_after: '30 days',
  secure: SESSION_CONFIG[:secure]
)
