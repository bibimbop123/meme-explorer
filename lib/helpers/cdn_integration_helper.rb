# frozen_string_literal: true

# CDN Integration Helper
# Optimizes asset delivery via CDN
# Created: July 22, 2026

module CDNIntegrationHelper
  class << self
    # Generate CDN URL for asset
    def cdn_url(path, options = {})
      return path unless cdn_enabled?
      
      base = ENV['CDN_BASE_URL'] || 'https://cdn.example.com'
      version = options[:version] || asset_version
      
      "#{base}/#{version}/#{path.sub(/^\//, '')}"
    end

    # Purge CDN cache for specific paths
    def purge_cache(paths)
      return unless cdn_enabled?
      
      # API call to CDN to purge cache
      # Implementation depends on CDN provider
      AppLogger.info("[CDN] Purging cache for: #{paths.join(', ')}")
    end

    # Pre-warm CDN with critical assets
    def prewarm_assets(paths = critical_assets)
      paths.each do |path|
        url = cdn_url(path)
        # Make HEAD request to warm cache
        begin
          Net::HTTP.get_response(URI(url))
        rescue => e
          AppLogger.warn("[CDN] Prewarm failed for #{path}: #{e.message}")
        end
      end
    end

    private

    def cdn_enabled?
      ENV['CDN_ENABLED'] == 'true'
    end

    def asset_version
      @asset_version ||= ENV['ASSET_VERSION'] || Time.now.to_i.to_s
    end

    def critical_assets
      [
        'css/meme_explorer.css',
        'js/modules/meme-app.js',
        'images/meme-placeholder.svg'
      ]
    end
  end
end
