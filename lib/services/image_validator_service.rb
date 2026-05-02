# Image Validator Service
# Pre-validates images before serving to users to eliminate broken image issues
# Uses HEAD requests with caching to minimize overhead

require 'net/http'
require 'uri'
require 'timeout'

class ImageValidatorService
  VALIDATION_CACHE_TTL = 300 # 5 minutes
  REQUEST_TIMEOUT = 3 # seconds
  
  class << self
    # Validate if an image URL is accessible
    # @param url [String] Image URL to validate
    # @return [Boolean] true if image is valid and accessible
    def valid?(url)
      return false if url.nil? || url.empty?
      
      # Local files - check existence
      if url.start_with?('/', 'images/', 'videos/')
        return validate_local_file(url)
      end
      
      # Remote URLs - check cache first
      cache_key = "image_valid:#{Digest::MD5.hexdigest(url)}"
      
      # Check Redis cache
      if defined?(REDIS) && REDIS
        cached = REDIS.get(cache_key)
        return cached == 'true' if cached
      end
      
      # Validate remote URL
      is_valid = validate_remote_url(url)
      
      # Cache result
      if defined?(REDIS) && REDIS
        REDIS.setex(cache_key, VALIDATION_CACHE_TTL, is_valid.to_s)
      end
      
      is_valid
    rescue => e
      puts "⚠️ [IMAGE VALIDATOR] Error validating #{url}: #{e.message}"
      false
    end
    
    # Batch validate multiple URLs (parallel for performance)
    # @param urls [Array<String>] Array of image URLs
    # @return [Hash] Hash of url => boolean validity
    def batch_validate(urls)
      results = {}
      
      urls.each do |url|
        results[url] = valid?(url)
      end
      
      results
    end
    
    # Get validation statistics
    # @return [Hash] Stats about validation cache
    def stats
      return { cache_enabled: false } unless defined?(REDIS) && REDIS
      
      total_keys = REDIS.keys('image_valid:*').length
      {
        cache_enabled: true,
        cached_validations: total_keys,
        cache_ttl: VALIDATION_CACHE_TTL
      }
    end
    
    # Clear validation cache (useful after bulk content updates)
    def clear_cache!
      return unless defined?(REDIS) && REDIS
      
      keys = REDIS.keys('image_valid:*')
      REDIS.del(*keys) if keys.any?
      
      puts "✅ [IMAGE VALIDATOR] Cleared #{keys.length} cached validations"
    end
    
    private
    
    # Validate local file exists
    def validate_local_file(path)
      # Remove leading slash if present
      clean_path = path.start_with?('/') ? path[1..-1] : path
      full_path = File.join('public', clean_path)
      
      File.exist?(full_path) && File.readable?(full_path)
    end
    
    # Validate remote URL with HEAD request
    def validate_remote_url(url)
      return false unless url.match?(/^https?:\/\//)
      
      uri = URI.parse(url)
      
      # Quick domain checks
      return false if blocked_domain?(uri.host)
      
      # Perform HEAD request with timeout
      Timeout.timeout(REQUEST_TIMEOUT) do
        response = Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == 'https',
                                   read_timeout: REQUEST_TIMEOUT, 
                                   open_timeout: REQUEST_TIMEOUT) do |http|
          request = Net::HTTP::Head.new(uri.request_uri)
          request['User-Agent'] = 'MemeExplorer/1.0 ImageValidator'
          http.request(request)
        end
        
        # Check response
        case response.code.to_i
        when 200..299
          # Check content type if available
          content_type = response['content-type']
          return true if content_type.nil? # Assume valid if no content-type
          
          # Valid image/video types
          content_type.match?(/^(image|video)\//) || content_type.include?('octet-stream')
        when 301, 302, 307, 308
          # Follow redirect (one level only to avoid loops)
          redirect_url = response['location']
          return false if redirect_url.nil?
          
          # Prevent redirect loops
          return false if redirect_url == url
          
          # Validate redirect target
          validate_remote_url(redirect_url)
        else
          false
        end
      end
    rescue Timeout::Error, Net::OpenTimeout, Net::ReadTimeout
      puts "⏱️ [IMAGE VALIDATOR] Timeout validating: #{url[0..50]}..."
      false
    rescue => e
      puts "⚠️ [IMAGE VALIDATOR] Error: #{e.class} - #{url[0..50]}..."
      false
    end
    
    # Check if domain is blocked/known to be problematic
    def blocked_domain?(host)
      return false if host.nil?
      
      blocked = [
        'localhost',
        '127.0.0.1',
        '0.0.0.0'
      ]
      
      blocked.include?(host.downcase)
    end
  end
end
