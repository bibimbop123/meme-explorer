# HTTP Caching Concern
# Provides methods for setting HTTP cache headers in routes
# Created: June 2, 2026

module HTTPCaching
  # Set cache headers for a response
  # @param type [Symbol] Cache type (:public, :private, :no_cache)
  # @param max_age [Integer] Max age in seconds
  # @param s_maxage [Integer] Shared cache max age (CDN)
  # @param must_revalidate [Boolean] Whether to force revalidation
  def set_cache_headers(type: :public, max_age: 3600, s_maxage: nil, must_revalidate: false)
    directives = [type.to_s]
    directives << "max-age=#{max_age}"
    directives << "s-maxage=#{s_maxage}" if s_maxage
    directives << "must-revalidate" if must_revalidate
    
    headers['Cache-Control'] = directives.join(', ')
  end
  
  # Set ETag based on content
  # @param content [String, Object] Content to generate ETag from
  def set_etag(content)
    require 'digest/md5'
    etag_value = Digest::MD5.hexdigest(content.to_s)
    headers['ETag'] = %("#{etag_value}")
    
    # Check if client has matching ETag
    if request.env['HTTP_IF_NONE_MATCH'] == headers['ETag']
      halt 304 # Not Modified
    end
  end
  
  # Set Last-Modified header
  # @param time [Time, DateTime] Last modified time
  def set_last_modified(time)
    headers['Last-Modified'] = time.httpdate
    
    # Check if client has newer version
    if_modified_since = request.env['HTTP_IF_MODIFIED_SINCE']
    if if_modified_since
      client_time = begin
        Time.httpdate(if_modified_since)
      rescue ArgumentError => e
        AppLogger.warn("set_last_modified: invalid If-Modified-Since header", error: e.message, value: if_modified_since)
        nil
      end
      if client_time && client_time >= time
        halt 304 # Not Modified
      end
    end
  end
  
  # Cache a page for a specific duration
  # @param duration [Integer] Cache duration in seconds
  # @param type [Symbol] Cache type
  def cache_page(duration: 3600, type: :public)
    set_cache_headers(type: type, max_age: duration, s_maxage: duration * 2)
  end
  
  # Cache API response
  # @param duration [Integer] Cache duration in seconds
  def cache_api_response(duration: 300)
    set_cache_headers(type: :public, max_age: duration, s_maxage: duration)
    headers['Vary'] = 'Accept, Accept-Encoding'
  end
  
  # Don't cache this response
  def no_cache
    headers['Cache-Control'] = 'no-store, no-cache, must-revalidate, max-age=0'
    headers['Pragma'] = 'no-cache'
    headers['Expires'] = '0'
  end
  
  # Cache static assets for 1 year
  def cache_asset
    set_cache_headers(
      type: :public,
      max_age: 31536000, # 1 year
      s_maxage: 31536000,
      must_revalidate: false
    )
  end
  
  # Cache with conditional GET (ETag + Last-Modified)
  # @param content [String] Content for ETag
  # @param modified_at [Time] Last modified time
  def cache_conditional(content, modified_at)
    set_etag(content)
    set_last_modified(modified_at)
  end
  
  # Cache for authenticated users only
  # @param duration [Integer] Cache duration
  def cache_private(duration: 300)
    set_cache_headers(type: :private, max_age: duration)
  end
end
