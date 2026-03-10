# Smart Media Renderer Service
# Handles intelligent media rendering with proper fallback chain
# Prevents excessive generic fallback images

class SmartMediaRendererService
  class << self
    # Render media with intelligent fallback chain
    # @param meme_data [Hash] Meme data from Reddit API or local DB
    # @param options [Hash] Rendering options
    # @return [Hash] Rendering configuration
    def prepare_media_render(meme_data, options = {})
      media_sources = extract_media_sources(meme_data)
      
      {
        primary_url: media_sources[:primary],
        fallback_urls: media_sources[:fallbacks],
        media_type: detect_media_type(media_sources[:primary]),
        show_generic_fallback: options[:show_generic_fallback] || false,
        hide_on_failure: options[:hide_on_failure] || false,
        placeholder_message: options[:placeholder_message] || "Media unavailable"
      }
    end

    # Extract all possible media sources from Reddit post data
    # @param meme_data [Hash] Meme data
    # @return [Hash] Primary and fallback URLs
    def extract_media_sources(meme_data)
      sources = {
        primary: nil,
        fallbacks: []
      }

      # Primary source
      sources[:primary] = meme_data['url'] || meme_data['file']

      # Try to get preview images from Reddit post
      if meme_data['preview']
        preview_images = extract_preview_images(meme_data['preview'])
        sources[:fallbacks].concat(preview_images)
      end

      # Try thumbnail
      if meme_data['thumbnail'] && valid_thumbnail?(meme_data['thumbnail'])
        sources[:fallbacks] << meme_data['thumbnail']
      end

      # Reddit video fallback
      if meme_data['secure_media'] && meme_data['secure_media']['reddit_video']
        sources[:fallbacks] << meme_data['secure_media']['reddit_video']['fallback_url']
      end

      # Remove duplicates and nil values
      sources[:fallbacks] = sources[:fallbacks].compact.uniq.reject { |url| url == sources[:primary] }

      sources
    end

    # Extract preview images from Reddit preview data
    # @param preview_data [Hash] Reddit preview data
    # @return [Array] Preview image URLs
    def extract_preview_images(preview_data)
      return [] unless preview_data.is_a?(Hash)
      
      images = []
      
      # Check for images array
      if preview_data['images'].is_a?(Array)
        preview_data['images'].each do |img_data|
          # Get resolutions
          if img_data['resolutions'].is_a?(Array)
            img_data['resolutions'].each do |res|
              images << unescape_url(res['url']) if res['url']
            end
          end
          
          # Get source
          if img_data['source'] && img_data['source']['url']
            images << unescape_url(img_data['source']['url'])
          end
        end
      end

      images.compact.uniq
    end

    # Check if thumbnail is valid (not default Reddit placeholders)
    # @param thumbnail [String] Thumbnail URL
    # @return [Boolean]
    def valid_thumbnail?(thumbnail)
      return false if thumbnail.nil? || thumbnail.empty?
      return false if %w[self default nsfw].include?(thumbnail)
      return false unless thumbnail.start_with?('http')
      true
    end

    # Detect media type from URL
    # @param url [String] Media URL
    # @return [String] Media type (image, video, gif)
    def detect_media_type(url)
      return 'unknown' unless url
      
      url_lower = url.downcase
      
      return 'video' if url_lower =~ /\.(mp4|webm|mov)(\?|$)/
      return 'gif' if url_lower =~ /\.(gif)(\?|$)/
      return 'image' if url_lower =~ /\.(jpg|jpeg|png|webp)(\?|$)/
      
      # Check if it's a Reddit video domain
      return 'video' if url.include?('v.redd.it')
      
      # Default to image
      'image'
    end

    # Unescape HTML entities in URLs
    # @param url [String] URL with potential HTML entities
    # @return [String] Unescaped URL
    def unescape_url(url)
      return url unless url
      
      CGI.unescapeHTML(url)
    rescue StandardError
      url
    end

    # Generate JavaScript for intelligent fallback handling
    # @param element_id [String] DOM element ID
    # @param fallback_urls [Array] Array of fallback URLs
    # @param options [Hash] Options
    # @return [String] JavaScript code
    def generate_fallback_script(element_id, fallback_urls, options = {})
      hide_on_failure = options[:hide_on_failure] || false
      show_placeholder = options[:show_placeholder] || true
      placeholder_message = options[:placeholder_message] || "Media unavailable"

      <<~JAVASCRIPT
        (function() {
          const elem = document.getElementById('#{element_id}');
          if (!elem) return;

          const fallbacks = #{fallback_urls.to_json};
          let currentFallbackIndex = 0;
          
          function tryNextFallback() {
            if (currentFallbackIndex < fallbacks.length) {
              const nextUrl = fallbacks[currentFallbackIndex];
              currentFallbackIndex++;
              
              console.log('Trying fallback ' + currentFallbackIndex + '/' + fallbacks.length + ':', nextUrl);
              elem.src = nextUrl;
            } else {
              // All fallbacks exhausted
              handleCompleteFailure();
            }
          }

          function handleCompleteFailure() {
            console.warn('All media sources failed for #{element_id}');
            
            #{if hide_on_failure
              "elem.style.display = 'none';"
            elsif show_placeholder
              <<~JS
                const container = elem.parentElement;
                if (container) {
                  // Use Tattoo Annie as fallback placeholder
                  const placeholder = document.createElement('div');
                  placeholder.className = 'media-unavailable-placeholder';
                  placeholder.innerHTML = `
                    <img src="/images/tattoo-annie-placeholder.jpg" 
                         alt="Tattoo Annie - Content Unavailable" 
                         class="placeholder-fallback-image"
                         style="max-width: 300px; border-radius: 8px; margin-bottom: 16px;" />
                    <div class="placeholder-message">#{placeholder_message}</div>
                    <div class="placeholder-hint">This content is no longer available</div>
                  `;
                  container.replaceChild(placeholder, elem);
                }
              JS
            else
              "// No action on failure"
            end}
          }

          elem.addEventListener('error', function(e) {
            console.warn('Media load error:', elem.src);
            tryNextFallback();
          });
        })();
      JAVASCRIPT
    end

    # Generate CSS for media unavailable placeholder
    # @return [String] CSS styles
    def placeholder_styles
      <<~CSS
        .media-unavailable-placeholder {
          display: flex;
          flex-direction: column;
          align-items: center;
          justify-content: center;
          min-height: 300px;
          background: linear-gradient(135deg, #f5f7fa 0%, #c3cfe2 100%);
          border-radius: 12px;
          padding: 40px 20px;
          text-align: center;
          box-shadow: 0 4px 12px rgba(0,0,0,0.1);
        }

        .placeholder-icon {
          font-size: 64px;
          margin-bottom: 16px;
          opacity: 0.7;
          animation: placeholder-pulse 2s ease-in-out infinite;
        }

        .placeholder-message {
          font-size: 18px;
          font-weight: 600;
          color: #2c3e50;
          margin-bottom: 8px;
        }

        .placeholder-hint {
          font-size: 14px;
          color: #7f8c8d;
        }

        @keyframes placeholder-pulse {
          0%, 100% { opacity: 0.5; }
          50% { opacity: 0.8; }
        }

        @media (max-width: 768px) {
          .media-unavailable-placeholder {
            min-height: 200px;
            padding: 30px 15px;
          }
          
          .placeholder-icon {
            font-size: 48px;
          }
        }
      CSS
    end

    # Render media with smart fallback handling
    # @param meme_data [Hash] Meme data
    # @param options [Hash] Rendering options
    # @return [String] HTML with embedded JavaScript
    def render_with_smart_fallback(meme_data, options = {})
      element_id = options[:element_id] || 'meme-image'
      media_config = prepare_media_render(meme_data, options)
      
      # Generate HTML based on media type
      html = case media_config[:media_type]
             when 'video'
               render_video_element(media_config, element_id, options)
             when 'gif'
               render_gif_element(media_config, element_id, options)
             else
               render_image_element(media_config, element_id, options)
             end

      # Add fallback script
      if media_config[:fallback_urls].any?
        script = generate_fallback_script(
          element_id,
          media_config[:fallback_urls],
          {
            hide_on_failure: options[:hide_on_failure],
            show_placeholder: options[:show_placeholder] != false,
            placeholder_message: media_config[:placeholder_message]
          }
        )
        html += "<script>#{script}</script>"
      end

      html
    end

    private

    def render_image_element(config, element_id, options)
      alt_text = options[:alt] || 'Meme'
      classes = options[:class] || 'meme-image'
      
      <<~HTML
        <img 
          id="#{element_id}"
          src="#{config[:primary_url]}" 
          alt="#{alt_text}"
          class="#{classes}"
          loading="lazy"
          style="max-width: 100%; height: auto; border-radius: 12px;"
        />
      HTML
    end

    def render_gif_element(config, element_id, options)
      # GIFs are rendered as images
      render_image_element(config, element_id, options)
    end

    def render_video_element(config, element_id, options)
      alt_text = options[:alt] || 'Video'
      classes = options[:class] || 'meme-video'
      
      <<~HTML
        <video 
          id="#{element_id}"
          class="#{classes}"
          controls
          autoplay
          loop
          muted
          playsinline
          style="max-width: 100%; height: auto; border-radius: 12px;"
        >
          <source src="#{config[:primary_url]}" type="video/mp4">
          <p>#{alt_text}</p>
        </video>
      HTML
    end
  end
end
