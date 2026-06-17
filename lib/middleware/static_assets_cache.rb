# frozen_string_literal: true

# Static Assets Caching Middleware
# Based on: REFACTORING_ROADMAP Phase 4, Task 6.1
# Sets aggressive cache headers for static assets

class StaticAssetsCache
  # Cache durations by file type (in seconds)
  CACHE_DURATION = {
    'css'  => 31_536_000,  # 1 year
    'js'   => 31_536_000,  # 1 year
    'jpg'  => 2_592_000,   # 30 days
    'jpeg' => 2_592_000,   # 30 days
    'png'  => 2_592_000,   # 30 days
    'gif'  => 2_592_000,   # 30 days
    'svg'  => 31_536_000,  # 1 year
    'woff' => 31_536_000,  # 1 year
    'woff2' => 31_536_000, # 1 year
    'ttf'  => 31_536_000,  # 1 year
    'eot'  => 31_536_000,  # 1 year
    'ico'  => 2_592_000    # 30 days
  }.freeze

  def initialize(app)
    @app = app
  end

  def call(env)
    status, headers, response = @app.call(env)

    # Apply cache headers to static assets
    if static_asset?(env['PATH_INFO'])
      ext = File.extname(env['PATH_INFO'])[1..-1]&.downcase
      duration = CACHE_DURATION[ext] || 86_400 # Default: 1 day

      headers['Cache-Control'] = "public, max-age=#{duration}, immutable"
      headers['Expires'] = (Time.now + duration).httpdate
      
      # Add ETag for conditional requests
      headers['ETag'] = generate_etag(response) unless headers['ETag']
      
      # Enable compression hint
      headers['Vary'] = 'Accept-Encoding'
    else
      # HTML pages: short cache with revalidation
      if html_page?(env['PATH_INFO'])
        headers['Cache-Control'] = 'public, max-age=300, must-revalidate'
      end
    end

    [status, headers, response]
  end

  private

  def static_asset?(path)
    # Match common static asset patterns
    path =~ /\.(css|js|jpg|jpeg|png|gif|svg|woff|woff2|ttf|eot|ico)$/i ||
    path.start_with?('/images/', '/css/', '/js/', '/fonts/')
  end

  def html_page?(path)
    path.end_with?('.html') || 
    (!path.include?('.') && !path.end_with?('/'))
  end

  def generate_etag(response)
    content = response.respond_to?(:body) ? response.body : response.join
    Digest::MD5.hexdigest(content)
  rescue
    nil
  end
end
