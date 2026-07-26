# frozen_string_literal: true

# Responsive Image Helper
# Generates responsive image tags with lazy loading
# Part of Week 2: Performance Optimization

module ResponsiveImageHelper
  # Generate responsive image with srcset
  def responsive_image(src, alt, options = {})
    sizes = options[:sizes] || [320, 640, 1024, 1920]
    lazy = options.fetch(:lazy, true)
    
    srcset = sizes.map { |size| "#{src}?w=#{size} #{size}w" }.join(', ')
    
    img_attrs = {
      'src' => "#{src}?w=640",
      'srcset' => srcset,
      'alt' => alt,
      'loading' => lazy ? 'lazy' : 'eager',
      'decoding' => 'async',
      'sizes' => options[:css_sizes] || '(max-width: 768px) 100vw, 640px'
    }
    
    img_attrs['class'] = options[:class] if options[:class]
    img_attrs['width'] = options[:width] if options[:width]
    img_attrs['height'] = options[:height] if options[:height]
    
    attrs_string = img_attrs.map { |k, v| "#{k}=\"#{v}\"" }.join(' ')
    "<img #{attrs_string}>"
  end
  
  # Lazy load image with placeholder
  def lazy_image(src, alt, options = {})
    placeholder = options[:placeholder] || '/images/meme-placeholder.svg'
    
    %(<img 
      src="#{placeholder}"
      data-src="#{src}"
      alt="#{alt}"
      class="lazy-load #{options[:class]}"
      loading="lazy"
      decoding="async"
    >)
  end
  
  # Optimize meme image URL (for Reddit/Imgur)
  def optimize_meme_url(url, width = 640)
    return url unless url
    
    # Imgur optimization
    if url.include?('imgur.com')
      # Append size suffix: m = 320, l = 640, h = 1024
      size_suffix = width <= 320 ? 'm' : (width <= 640 ? 'l' : 'h')
      return url.sub(/(\.[a-z]+)$/i, "#{size_suffix}\\1")
    end
    
    # Reddit optimization
    if url.include?('redd.it') || url.include?('reddit.com')
      # Add width parameter
      separator = url.include?('?') ? '&' : '?'
      return "#{url}#{separator}width=#{width}"
    end
    
    url
  end
  
  # Generate WebP alternative if supported
  def webp_image(src, alt, options = {})
    webp_src = src.sub(/\.(jpg|jpeg|png)$/i, '.webp')
    
    %(<picture>
      <source srcset="#{webp_src}" type="image/webp">
      <img src="#{src}" alt="#{alt}" loading="lazy" decoding="async">
    </picture>)
  end
end
