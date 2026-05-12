# Image Validation Service
# Fast, cached validation to skip broken images before serving to users
# Eliminates client-side fallback chains and improves UX

require 'net/http'
require 'uri'
require 'timeout'

class ImageValidationService
  # Cache validation results for 24 hours
  CACHE_TTL = 86400 # 24 hours in seconds
  VALIDATION_TIMEOUT = 2 # 2 second timeout for checks
  
  class << self
    # Validate a single image URL
    # @param url [String] Image URL to validate
    # @param use_cache [Boolean] Whether to use cached results
    # @return [Boolean] true if valid, false if broken
    def validate(url, use_cache: true)
      return false if url.nil? || url.empty?
      
      # PREVENTION: Check blacklist first (fastest check)
      if defined?(ImageHealthService) && ImageHealthService.blacklisted?(url)
        AppLogger.debug("⚡ [VALIDATION] Skipping blacklisted URL: #{url[0..50]}...")
        return false
      end
      
      # Check cache first
      if use_cache && cached_result = get_cached_result(url)
        return cached_result
      end
      
      # Perform validation
      start_time = Time.now
      is_valid = perform_validation(url)
      duration_ms = ((Time.now - start_time) * 1000).to_i
      
      # Record result in health service
      if defined?(ImageHealthService)
        if is_valid
          ImageHealthService.record_success(url)
        else
          ImageHealthService.record_failure(url, reason: "Validation failed", duration_ms: duration_ms)
        end
      end
      
      # Cache the result
      cache_result(url, is_valid)
      
      is_valid
    rescue => e
      AppLogger.warn("Image validation error for #{url}: #{e.message}")
      # Record failure in health service
      if defined?(ImageHealthService)
        ImageHealthService.record_failure(url, reason: e.message, duration_ms: 0)
      end
      false # Assume invalid on error
    end
    
    # Validate multiple URLs and return first valid one
    # @param urls [Array<String>] Array of URLs to validate
    # @return [String, nil] First valid URL or nil
    def find_first_valid(urls)
      return nil if urls.nil? || urls.empty?
      
      urls.each do |url|
        return url if validate(url)
      end
      
      nil
    end
    
    # Validate and filter an array of URLs
    # @param urls [Array<String>] Array of URLs to validate
    # @return [Array<String>] Array of valid URLs
    def filter_valid(urls)
      return [] if urls.nil? || urls.empty?
      
      urls.select { |url| validate(url) }
    end
    
    # Clear validation cache (useful for testing)
    def clear_cache!
      CacheManager.delete_pattern('image_validation:*') if defined?(CacheManager)
    end
    
    private
    
    # Perform actual HTTP validation
    def perform_validation(url)
      # Local file check
      if url.start_with?('/') || url.start_with?('.')
        return validate_local_file(url)
      end
      
      # Remote URL check
      validate_remote_url(url)
    end
    
    # Validate local file existence
    def validate_local_file(path)
      # Remove leading slash for file system check
      file_path = path.start_with?('/') ? File.join('public', path) : path
      File.exist?(file_path)
    end
    
    # Validate remote URL via HTTP HEAD request
    def validate_remote_url(url)
      uri = URI.parse(url)
      
      # Only validate HTTP/HTTPS URLs
      return false unless %w[http https].include?(uri.scheme)
      
      Timeout.timeout(VALIDATION_TIMEOUT) do
        Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == 'https',
                       open_timeout: VALIDATION_TIMEOUT,
                       read_timeout: VALIDATION_TIMEOUT) do |http|
          
          # Use HEAD request for efficiency
          request = Net::HTTP::Head.new(uri.request_uri)
          request['User-Agent'] = 'MemeExplorer/2.0 (Image Validator)'
          
          response = http.request(request)
          
          # Consider 200-299 as valid, plus 304 (Not Modified)
          (200..299).include?(response.code.to_i) || response.code.to_i == 304
        end
      end
    rescue Timeout::Error, Net::HTTPError, SocketError, Errno::ECONNREFUSED => e
      AppLogger.debug("URL validation failed for #{url}: #{e.class} - #{e.message}")
      false
    end
    
    # Get cached validation result
    def get_cached_result(url)
      cache_key = cache_key_for(url)
      
      if defined?(CacheManager)
        cached = CacheManager.get(cache_key)
        return cached unless cached.nil?
      elsif defined?($redis)
        cached = $redis.get(cache_key)
        return cached == 'true' if cached
      end
      
      nil
    end
    
    # Cache validation result
    def cache_result(url, is_valid)
      cache_key = cache_key_for(url)
      
      if defined?(CacheManager)
        CacheManager.set(cache_key, is_valid, ttl: CACHE_TTL)
      elsif defined?($redis)
        $redis.setex(cache_key, CACHE_TTL, is_valid.to_s)
      end
    end
    
    # Generate cache key for URL
    def cache_key_for(url)
      "image_validation:#{Digest::MD5.hexdigest(url)}"
    end
  end
end

# Usage Examples:
#
# # Validate single URL
# ImageValidationService.validate('https://i.redd.it/abc123.jpg')  # => true/false
#
# # Find first valid URL from array
# urls = ['broken.jpg', 'https://i.redd.it/valid.jpg', 'another.jpg']
# ImageValidationService.find_first_valid(urls)  # => 'https://i.redd.it/valid.jpg'
#
# # Filter valid URLs
# ImageValidationService.filter_valid(urls)  # => ['https://i.redd.it/valid.jpg']
#
# # Clear cache for testing
# ImageValidationService.clear_cache!
