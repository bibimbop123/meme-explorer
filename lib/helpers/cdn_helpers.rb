# CDN Helper Module
# Provides utility methods for CDN integration
# Created: June 2, 2026

module CDNHelpers
  # Get CDN URL for an asset
  # Falls back to local path if CDN not configured
  # @param path [String] Asset path (e.g., '/css/style.css')
  # @return [String] Full CDN URL or local path
  def cdn_asset_url(path)
    cdn_url = ENV['CDN_URL']
    
    if cdn_url && !cdn_url.empty?
      # Remove trailing slash from CDN_URL if present
      cdn_url = cdn_url.chomp('/')
      # Ensure path starts with /
      path = "/#{path}" unless path.start_with?('/')
      "#{cdn_url}#{path}"
    else
      path # Fallback to local
    end
  end
  
  # Get versioned asset URL for cache busting
  # Uses GIT_SHA or timestamp as version
  # @param path [String] Asset path
  # @return [String] Versioned URL
  def versioned_asset_url(path)
    version = ENV.fetch('GIT_SHA', Time.now.to_i.to_s)
    url = cdn_asset_url(path)
    
    # Add version as query parameter
    separator = url.include?('?') ? '&' : '?'
    "#{url}#{separator}v=#{version}"
  end
  
  # Get CDN URL for image with responsive sizes
  # @param path [String] Image path
  # @param size [Symbol] Size variant (:thumb, :medium, :large, :original)
  # @return [String] CDN URL
  def cdn_image_url(path, size: :original)
    # Future: Add image transformation params for CDN
    # e.g., CloudFlare Images, Imgix, etc.
    case size
    when :thumb
      cdn_asset_url("#{path}?width=150&height=150&fit=crop")
    when :medium
      cdn_asset_url("#{path}?width=600&height=600&fit=crop")
    when :large
      cdn_asset_url("#{path}?width=1200&height=1200&fit=inside")
    else
      cdn_asset_url(path)
    end
  end
  
  # Generate srcset for responsive images
  # @param path [String] Image path
  # @return [String] srcset attribute value
  def cdn_srcset(path)
    sizes = {
      '1x' => :medium,
      '2x' => :large
    }
    
    sizes.map do |multiplier, size|
      "#{cdn_image_url(path, size: size)} #{multiplier}"
    end.join(', ')
  end
  
  # Check if CDN is configured
  # @return [Boolean]
  def cdn_enabled?
    ENV['CDN_URL'] && !ENV['CDN_URL'].empty?
  end
  
  # Get asset with automatic CDN fallback
  # @param path [String] Asset path
  # @param versioned [Boolean] Whether to add version parameter
  # @return [String] Final asset URL
  def asset_url(path, versioned: true)
    if versioned
      versioned_asset_url(path)
    else
      cdn_asset_url(path)
    end
  end
end
