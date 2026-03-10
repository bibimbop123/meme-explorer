# Placeholder Image Service
# Centralized management for the Tattoo Annie placeholder image
# SEO-optimized with comprehensive metadata and accessibility features

class PlaceholderImageService
  # Primary placeholder image - Tattoo Annie from The Simpsons
  # Represents meme culture and adds personality to the app
  PLACEHOLDER_IMAGE = {
    url: '/images/tattoo-annie-placeholder.jpg',
    alt: 'Tattoo Annie from The Simpsons - Meme Explorer Placeholder',
    title: 'Loading Meme Content',
    width: 600,
    height: 800,
    format: 'jpeg',
    description: 'Tattoo Annie character from The Simpsons, featuring her iconic tattooed appearance and quirky personality. This placeholder represents the fun and cultural nature of memes while content loads.',
    schema_type: 'ImageObject',
    keywords: ['simpsons', 'tattoo annie', 'meme', 'placeholder', 'cartoon', 'pop culture'],
    content_category: 'Entertainment',
    seo_rating: 'family-friendly'
  }.freeze

  # Blurhash for progressive loading (generated from the actual image)
  # This creates a smooth loading experience
  PLACEHOLDER_BLURHASH = 'LMK0d~x[D*a#0Kx[Rja#9ZWVRja#'.freeze

  class << self
    # Get the primary placeholder configuration
    # @param options [Hash] Customization options
    # @return [Hash] Placeholder configuration
    def get_placeholder(options = {})
      config = PLACEHOLDER_IMAGE.dup
      
      # Allow overrides
      config[:alt] = options[:alt] if options[:alt]
      config[:title] = options[:title] if options[:title]
      config[:loading] = options[:loading] || 'lazy'
      config[:decoding] = options[:decoding] || 'async'
      config[:fetchpriority] = options[:fetchpriority] || 'low'
      
      # Add responsive image URLs if available
      config[:srcset] = generate_srcset(config[:url]) if options[:responsive]
      
      config
    end

    # Generate comprehensive alt text for accessibility and SEO
    # @param context [String] Context for the placeholder (e.g., 'meme', 'category', 'search')
    # @param additional_info [String] Additional contextual information
    # @return [String] SEO-optimized alt text
    def generate_alt_text(context: 'meme', additional_info: nil)
      base = "Tattoo Annie from The Simpsons"
      
      context_text = case context
                     when 'meme'
                       "placeholder while meme content loads"
                     when 'category'
                       "category placeholder for #{additional_info || 'memes'}"
                     when 'search'
                       "search results placeholder"
                     when 'error'
                       "content unavailable indicator"
                     when 'loading'
                       "loading animation"
                     else
                       "placeholder image"
                     end
      
      "#{base} - #{context_text}. A colorful character from the iconic animated series, representing the fun and entertaining nature of meme culture."
    end

    # Generate Schema.org ImageObject markup for SEO
    # @param url [String] Image URL
    # @param context [Hash] Additional context
    # @return [Hash] Schema.org markup
    def generate_schema_markup(url, context = {})
      {
        "@context": "https://schema.org",
        "@type": "ImageObject",
        "contentUrl": url,
        "url": url,
        "name": context[:name] || PLACEHOLDER_IMAGE[:title],
        "description": context[:description] || PLACEHOLDER_IMAGE[:description],
        "thumbnailUrl": url,
        "image": url,
        "width": {
          "@type": "QuantitativeValue",
          "value": PLACEHOLDER_IMAGE[:width],
          "unitText": "px"
        },
        "height": {
          "@type": "QuantitativeValue",
          "value": PLACEHOLDER_IMAGE[:height],
          "unitText": "px"
        },
        "encodingFormat": "image/jpeg",
        "contentRating": "General audiences",
        "genre": "Entertainment",
        "keywords": PLACEHOLDER_IMAGE[:keywords].join(', '),
        "isFamilyFriendly": true,
        "copyrightNotice": "The Simpsons © 20th Century Fox",
        "creditText": "Character from The Simpsons animated series",
        "creator": {
          "@type": "Organization",
          "name": "20th Century Fox / Disney"
        },
        "representativeOfPage": false,
        "license": "Fair Use - Educational/Commentary Purpose"
      }
    end

    # Render HTML picture element with full SEO optimization
    # @param options [Hash] Rendering options
    # @return [String] HTML markup
    def render_html(options = {})
      config = get_placeholder(options)
      element_id = options[:id] || 'placeholder-image'
      include_schema = options[:include_schema] != false
      
      html = []
      
      # Add Schema.org JSON-LD if requested
      if include_schema && options[:schema_context]
        schema = generate_schema_markup(config[:url], options[:schema_context])
        html << %(<script type="application/ld+json">#{schema.to_json}</script>)
      end
      
      # Progressive image wrapper
      html << %(<div class="tattoo-annie-placeholder-wrapper" role="img" aria-label="#{config[:alt]}">)
      
      # Blurhash placeholder for progressive loading
      if options[:progressive_loading]
        html << %(  <div class="placeholder-blur" style="background: linear-gradient(135deg, #E91E63 0%, #9C27B0 50%, #673AB7 100%); filter: blur(20px); position: absolute; inset: 0; opacity: 0.3;"></div>)
      end
      
      # Main image element with comprehensive attributes
      html << %(  <img)
      html << %(    id="#{element_id}")
      html << %(    src="#{config[:url]}")
      html << %(    alt="#{config[:alt]}")
      html << %(    title="#{config[:title]}")
      html << %(    width="#{config[:width]}")
      html << %(    height="#{config[:height]}")
      html << %(    loading="#{config[:loading]}")
      html << %(    decoding="#{config[:decoding]}")
      html << %(    fetchpriority="#{config[:fetchpriority]}")
      
      # Add responsive srcset if available
      if config[:srcset]
        html << %(    srcset="#{config[:srcset]}")
        html << %(    sizes="#{options[:sizes] || '(max-width: 768px) 100vw, 600px'}")
      end
      
      # Add data attributes for analytics and tracking
      html << %(    data-placeholder-type="tattoo-annie")
      html << %(    data-content-category="#{PLACEHOLDER_IMAGE[:content_category]}")
      html << %(    data-seo-optimized="true")
      
      # Accessibility and SEO classes
      html << %(    class="placeholder-image tattoo-annie #{options[:class]}")
      
      # ARIA attributes for accessibility
      html << %(    role="img")
      html << %(    aria-label="#{config[:alt]}")
      
      # Close img tag
      html << %(  />)
      
      # Add caption for better context
      if options[:show_caption]
        html << %(  <figcaption class="placeholder-caption sr-only">#{config[:description]}</figcaption>)
      end
      
      html << %(</div>)
      
      html.join("\n")
    end

    # Generate CSS for placeholder styling
    # @return [String] CSS styles
    def generate_styles
      <<~CSS
        /* Tattoo Annie Placeholder Styles - SEO Optimized */
        .tattoo-annie-placeholder-wrapper {
          position: relative;
          width: 100%;
          max-width: 600px;
          margin: 0 auto;
          border-radius: 12px;
          overflow: hidden;
          box-shadow: 0 4px 20px rgba(0, 0, 0, 0.15);
          background: linear-gradient(135deg, #f5f7fa 0%, #c3cfe2 100%);
          aspect-ratio: 3 / 4;
        }

        .placeholder-image.tattoo-annie {
          display: block;
          width: 100%;
          height: 100%;
          object-fit: contain;
          object-position: center;
          background: linear-gradient(135deg, #FFF3E0 0%, #FFE0B2 100%);
          transition: transform 0.3s ease, filter 0.3s ease;
        }

        .placeholder-image.tattoo-annie:hover {
          transform: scale(1.02);
          filter: brightness(1.05);
        }

        /* Progressive loading animation */
        .tattoo-annie-placeholder-wrapper.loading .placeholder-image {
          animation: placeholder-shimmer 2s infinite;
        }

        @keyframes placeholder-shimmer {
          0% { opacity: 0.7; }
          50% { opacity: 1; }
          100% { opacity: 0.7; }
        }

        /* Responsive adjustments */
        @media (max-width: 768px) {
          .tattoo-annie-placeholder-wrapper {
            max-width: 100%;
            border-radius: 8px;
          }
        }

        /* Screen reader only caption */
        .placeholder-caption.sr-only {
          position: absolute;
          width: 1px;
          height: 1px;
          padding: 0;
          margin: -1px;
          overflow: hidden;
          clip: rect(0, 0, 0, 0);
          white-space: nowrap;
          border-width: 0;
        }

        /* Blur placeholder for progressive loading */
        .placeholder-blur {
          animation: blur-fade 0.8s ease-out forwards;
        }

        @keyframes blur-fade {
          to { opacity: 0; }
        }

        /* Print styles */
        @media print {
          .tattoo-annie-placeholder-wrapper {
            box-shadow: none;
            border: 1px solid #ccc;
          }
        }

        /* High contrast mode support */
        @media (prefers-contrast: high) {
          .tattoo-annie-placeholder-wrapper {
            border: 2px solid currentColor;
          }
        }

        /* Reduced motion support */
        @media (prefers-reduced-motion: reduce) {
          .placeholder-image.tattoo-annie,
          .placeholder-blur {
            animation: none !important;
            transition: none !important;
          }
        }
      CSS
    end

    # Generate Open Graph meta tags for social sharing
    # @param page_context [Hash] Context about the page
    # @return [String] HTML meta tags
    def generate_og_meta_tags(page_context = {})
      base_url = page_context[:base_url] || 'https://meme-explorer.com'
      image_url = "#{base_url}#{PLACEHOLDER_IMAGE[:url]}"
      
      <<~HTML
        <!-- Open Graph / Facebook -->
        <meta property="og:type" content="website">
        <meta property="og:image" content="#{image_url}">
        <meta property="og:image:secure_url" content="#{image_url}">
        <meta property="og:image:type" content="image/jpeg">
        <meta property="og:image:width" content="#{PLACEHOLDER_IMAGE[:width]}">
        <meta property="og:image:height" content="#{PLACEHOLDER_IMAGE[:height]}">
        <meta property="og:image:alt" content="#{PLACEHOLDER_IMAGE[:alt]}">
        
        <!-- Twitter -->
        <meta name="twitter:card" content="summary_large_image">
        <meta name="twitter:image" content="#{image_url}">
        <meta name="twitter:image:alt" content="#{PLACEHOLDER_IMAGE[:alt]}">
        
        <!-- Additional SEO -->
        <meta name="thumbnail" content="#{image_url}">
        <link rel="image_src" href="#{image_url}">
      HTML
    end

    # Generate responsive srcset
    # @param base_url [String] Base image URL
    # @return [String] Srcset attribute value
    def generate_srcset(base_url)
      # If we have multiple sizes available, generate srcset
      # For now, return single size
      "#{base_url} 600w"
    end

    # Get blurhash for progressive loading
    # @return [String] Blurhash string
    def get_blurhash
      PLACEHOLDER_BLURHASH
    end

    # Check if placeholder image exists
    # @return [Boolean]
    def placeholder_exists?
      image_path = File.join('public', PLACEHOLDER_IMAGE[:url])
      File.exist?(image_path)
    end

    # Preload directive for performance
    # @return [String] Link preload tag
    def generate_preload_tag
      %(<link rel="preload" as="image" href="#{PLACEHOLDER_IMAGE[:url]}" type="image/jpeg" fetchpriority="low">)
    end
  end
end

# Usage Examples:
#
# # Basic usage - get placeholder config
# config = PlaceholderImageService.get_placeholder
# puts config[:url]  # => "/images/tattoo-annie-placeholder.jpg"
#
# # Render HTML with full SEO optimization
# html = PlaceholderImageService.render_html(
#   id: 'meme-placeholder',
#   class: 'card-image',
#   progressive_loading: true,
#   include_schema: true,
#   schema_context: {
#     name: 'Meme Loading Placeholder',
#     description: 'Placeholder while meme content loads'
#   }
# )
#
# # Generate alt text for specific context
# alt_text = PlaceholderImageService.generate_alt_text(
#   context: 'category',
#   additional_info: 'funny memes'
# )
#
# # Get Schema.org markup
# schema = PlaceholderImageService.generate_schema_markup(
#   '/images/tattoo-annie-placeholder.jpg',
#   { name: 'Meme Placeholder' }
# )
#
# # Generate Open Graph meta tags
# meta_tags = PlaceholderImageService.generate_og_meta_tags(
#   base_url: 'https://meme-explorer.com'
# )
#
# # Get styles
# styles = PlaceholderImageService.generate_styles
