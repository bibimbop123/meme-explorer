# frozen_string_literal: true

# HTTP Caching Middleware
# Adds proper caching headers
# Created: July 22, 2026

class HttpCache
  def initialize(app)
    @app = app
  end

  def call(env)
    status, headers, response = @app.call(env)
    
    # Add caching headers based on content type
    cache_headers = determine_cache_headers(env['PATH_INFO'], headers)
    headers.merge!(cache_headers)
    
    [status, headers, response]
  end

  private

  def determine_cache_headers(path, headers)
    content_type = headers['Content-Type'] || ''
    
    # Static assets - cache for 1 year
    if static_asset?(path)
      {
        'Cache-Control' => 'public, max-age=31536000, immutable',
        'Expires' => (Time.now + 365 * 24 * 60 * 60).httpdate
      }
    # HTML pages - cache for 5 minutes with revalidation
    elsif html_content?(content_type)
      {
        'Cache-Control' => 'public, max-age=300, must-revalidate',
        'Vary' => 'Accept-Encoding'
      }
    # API responses - cache for 1 minute
    elsif api_endpoint?(path)
      {
        'Cache-Control' => 'public, max-age=60',
        'Vary' => 'Accept'
      }
    # Default - no cache
    else
      {
        'Cache-Control' => 'no-cache, no-store, must-revalidate',
        'Pragma' => 'no-cache',
        'Expires' => '0'
      }
    end
  end

  def static_asset?(path)
    path.match?(/\.(css|js|jpg|jpeg|png|gif|svg|woff|woff2|ttf|ico)$/)
  end

  def html_content?(content_type)
    content_type.include?('text/html')
  end

  def api_endpoint?(path)
    path.start_with?('/api/')
  end
end
