# frozen_string_literal: true

# CDN Configuration for Static Assets
# Based on: REFACTORING_ROADMAP Phase 4, Task 6.1

# CDN domain (Cloudflare, CloudFront, etc.)
CDN_DOMAIN = ENV['CDN_DOMAIN'] || ENV['RENDER_EXTERNAL_URL']&.gsub('https://', 'cdn.') || nil

# CDN enabled in production only
CDN_ENABLED = ENV['RACK_ENV'] == 'production' && !CDN_DOMAIN.nil?

# Asset versioning for cache busting
ASSET_VERSION = ENV['ASSET_VERSION'] || Time.now.to_i.to_s

module CDNConfig
  class << self
    def enabled?
      CDN_ENABLED
    end

    def domain
      CDN_DOMAIN
    end

    def asset_url(path)
      return path unless enabled?
      return path if path.start_with?('http')

      # Add version query string for cache busting
      separator = path.include?('?') ? '&' : '?'
      versioned_path = "#{path}#{separator}v=#{ASSET_VERSION}"

      if CDN_DOMAIN.start_with?('http')
        "#{CDN_DOMAIN}#{versioned_path}"
      else
        "https://#{CDN_DOMAIN}#{versioned_path}"
      end
    end

    def image_url(path)
      return path unless enabled?
      return path if path.start_with?('http')

      # Images don't need version strings
      if CDN_DOMAIN.start_with?('http')
        "#{CDN_DOMAIN}#{path}"
      else
        "https://#{CDN_DOMAIN}#{path}"
      end
    end
  end
end

# Log CDN configuration on boot
if defined?(AppLogger)
  if CDN_ENABLED
    AppLogger.info("CDN Enabled", domain: CDN_DOMAIN, version: ASSET_VERSION)
  else
    AppLogger.info("CDN Disabled", environment: ENV['RACK_ENV'])
  end
end
