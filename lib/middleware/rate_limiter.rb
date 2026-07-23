# frozen_string_literal: true

# Rate Limiting Middleware
# Prevents abuse and DDoS attacks
# Created: July 22, 2026

class RateLimiter
  def initialize(app, options = {})
    @app = app
    @limit = options[:limit] || 100  # requests per window
    @window = options[:window] || 60  # seconds
    @storage = {}
    @cleanup_interval = 300  # 5 minutes
    @last_cleanup = Time.now
  end

  def call(env)
    cleanup_old_entries if should_cleanup?
    
    identifier = get_identifier(env)
    
    if rate_limited?(identifier)
      return rate_limit_response
    end
    
    track_request(identifier)
    @app.call(env)
  end

  private

  def get_identifier(env)
    # Use IP address + user agent for identification
    ip = env['HTTP_X_FORWARDED_FOR']&.split(',')&.first || env['REMOTE_ADDR']
    user_agent = env['HTTP_USER_AGENT']
    "#{ip}:#{user_agent&.hash}"
  end

  def rate_limited?(identifier)
    return false unless @storage[identifier]
    
    window_start = Time.now - @window
    requests = @storage[identifier].select { |time| time > window_start }
    
    requests.size >= @limit
  end

  def track_request(identifier)
    @storage[identifier] ||= []
    @storage[identifier] << Time.now
    
    # Keep only requests within the window
    window_start = Time.now - @window
    @storage[identifier].select! { |time| time > window_start }
  end

  def should_cleanup?
    Time.now - @last_cleanup > @cleanup_interval
  end

  def cleanup_old_entries
    window_start = Time.now - @window
    @storage.each do |identifier, times|
      times.select! { |time| time > window_start }
      @storage.delete(identifier) if times.empty?
    end
    @last_cleanup = Time.now
  end

  def rate_limit_response
    [
      429,
      {
        'Content-Type' => 'application/json',
        'Retry-After' => @window.to_s
      },
      [{ error: 'Rate limit exceeded', retry_after: @window }.to_json]
    ]
  end
end
