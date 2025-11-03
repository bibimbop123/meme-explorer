# Progressive Image Component
# Renders responsive images with blur-up loading effect (LQIP)
# Serves WebP to modern browsers, JPEG to older browsers

class ProgressiveImageComponent
  attr_reader :meme, :sizes

  def initialize(meme:, sizes: "100vw")
    @meme = meme
    @sizes = sizes
  end

  def render
    return default_image if missing_urls?

    # Extract image URLs from meme.image_urls
    urls = extract_urls
    blur_hash = meme.image_metadata&.dig('blur_hash')

    erb_template(urls, blur_hash)
  end

  private

  def missing_urls?
    meme.image_urls.blank? || meme.image_urls.empty?
  end

  def extract_urls
    {
      desktop_webp: meme.image_urls['desktop_webp_url'],
      desktop_jpeg: meme.image_urls['desktop_jpeg_url'],
      mobile_webp: meme.image_urls['mobile_webp_url'],
      mobile_jpeg: meme.image_urls['mobile_jpeg_url'],
      thumbnail_webp: meme.image_urls['thumbnail_webp_url'],
      thumbnail_jpeg: meme.image_urls['thumbnail_jpeg_url'],
      fallback: meme.image_url  # Original URL as fallback
    }
  end

  def erb_template(urls, blur_hash)
    <<~HTML
      <div class="progressive-image-wrapper">
        <!-- Blur-up placeholder (LQIP) -->
        #{blur_placeholder(blur_hash)}

        <!-- Responsive picture element -->
        <picture>
          <!-- WebP variants (modern browsers > 65% market share) -->
          <source
            srcset="#{urls[:mobile_webp]} 600w, #{urls[:desktop_webp]} 1200w"
            sizes="#{@sizes}"
            type="image/webp"
          />

          <!-- JPEG variants (fallback) -->
          <source
            srcset="#{urls[:mobile_jpeg]} 600w, #{urls[:desktop_jpeg]} 1200w"
            sizes="#{@sizes}"
            type="image/jpeg"
          />

          <!-- Ultimate fallback -->
          <img
            class="progressive-image"
            src="#{urls[:mobile_jpeg]}"
            srcset="#{urls[:desktop_jpeg]} 1200w"
            alt="#{meme.title}"
            loading="lazy"
            decoding="async"
            data-meme-id="#{meme.id}"
          />
        </picture>
      </div>

      <style>
        .progressive-image-wrapper {
          position: relative;
          width: 100%;
          aspect-ratio: 1;
          overflow: hidden;
          background: #f0f0f0;
        }

        .progressive-blur {
          position: absolute;
          top: 0;
          left: 0;
          width: 100%;
          height: 100%;
          filter: blur(20px);
          opacity: 1;
          transition: opacity 0.6s ease-out;
          z-index: 1;
        }

        .progressive-image {
          display: block;
          width: 100%;
          height: 100%;
          object-fit: cover;
          opacity: 0;
          transition: opacity 0.6s ease-out;
          z-index: 2;
        }

        /* Image loaded - fade in real image */
        .progressive-image.loaded {
          opacity: 1;
        }

        /* Image loaded - hide blur placeholder */
        .progressive-image.loaded ~ .progressive-blur {
          opacity: 0;
          pointer-events: none;
        }
      </style>

      <script>
        (function() {
          const img = document.querySelector('[data-meme-id="#{meme.id}"]');
          if (!img) return;

          img.addEventListener('load', function() {
            this.classList.add('loaded');
            // Track analytics
            if (window.analytics) {
              window.analytics.track('image_loaded', {
                meme_id: #{meme.id},
                src: this.currentSrc
              });
            }
          });

          img.addEventListener('error', function() {
            // Fallback to original URL on error
            this.src = '#{urls[:fallback]}';
          });
        })();
      </script>
    HTML
  end

  def blur_placeholder(blur_hash)
    if blur_hash.present?
      # Blurhash generates data URI SVG
      # For production: use blurhash gem to decode
      '<img class="progressive-blur" src="' +
        blur_hash_data_uri(blur_hash) +
        '" aria-hidden="true" />'
    else
      # Fallback: solid color placeholder
      '<div class="progressive-blur"></div>'
    end
  end

  def blur_hash_data_uri(hash)
    # Simplified - would use blurhash gem in production
    # Returns data URI of small blurred image
    "data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 280 280'%3E" +
    "%3Crect fill='%23e0e0e0' width='280' height='280'/%3E%3C/svg%3E"
  end

  def default_image
    '<img src="/images/dank1.jpeg" alt="' + meme.title.to_s + '" class="progressive-image loaded" />'
  end
end

# Usage in ERB views:
#
# <div class="meme-card">
#   <%= ProgressiveImageComponent.new(meme: @meme).render %>
#   <div class="meme-info">
#     <h3><%= @meme.title %></h3>
#   </div>
# </div>
