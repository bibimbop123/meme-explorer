# frozen_string_literal: true

# Image Optimization Utilities
# Lazy loading and responsive images
# Created: July 22, 2026

module ImageOptimizer
  class << self
    # Generate responsive image srcset
    def responsive_srcset(image_url, sizes = [320, 640, 1024, 1920])
      sizes.map { |size|
        "#{image_url}?w=#{size} #{size}w"
      }.join(', ')
    end

    # Generate lazy loading image tag
    def lazy_image_tag(src, alt, options = {})
      <<~HTML
        <img 
          data-src="#{src}"
          alt="#{alt}"
          class="lazy-load #{options[:class]}"
          loading="lazy"
          decoding="async"
        />
      HTML
    end

    # Optimize image URLs with CDN
    def cdn_image_url(path, transformations = {})
      base_url = ENV['CDN_URL'] || ''
      params = []
      
      params << "w=#{transformations[:width]}" if transformations[:width]
      params << "h=#{transformations[:height]}" if transformations[:height]
      params << "q=#{transformations[:quality] || 80}"
      params << "fm=#{transformations[:format] || 'webp'}"
      
      "#{base_url}#{path}?#{params.join('&')}"
    end

    # Check if image should be optimized
    def should_optimize?(path)
      ['.jpg', '.jpeg', '.png', '.webp'].any? { |ext| path.end_with?(ext) }
    end
  end
end
