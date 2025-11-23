# Enhanced Media Handling Service for GIFs, Videos, and Images
# Provides unified interface for all media types with optimization strategies

class MediaHandlingService
  # Supported media types and their characteristics
  MEDIA_TYPES = {
    # Animated formats
    gif: { extensions: %w[.gif], mime: 'image/gif', category: 'animated_image', autoplay: false },
    webp: { extensions: %w[.webp], mime: 'image/webp', category: 'image', autoplay: false },
    apng: { extensions: %w[.apng], mime: 'image/apng', category: 'animated_image', autoplay: false },
    
    # Video formats
    mp4: { extensions: %w[.mp4], mime: 'video/mp4', category: 'video', autoplay: true },
    webm: { extensions: %w[.webm], mime: 'video/webm', category: 'video', autoplay: true },
    mov: { extensions: %w[.mov], mime: 'video/quicktime', category: 'video', autoplay: true },
    
    # Static images
    jpeg: { extensions: %w[.jpg .jpeg], mime: 'image/jpeg', category: 'image', autoplay: false },
    png: { extensions: %w[.png], mime: 'image/png', category: 'image', autoplay: false },
    svg: { extensions: %w[.svg], mime: 'image/svg+xml', category: 'image', autoplay: false }
  }.freeze

  OPTIMIZATION_CONFIG = {
    gif: {
      max_size_mb: 10,
      convert_to_webp: true,
      create_poster: true,
      description: 'Animated GIF - will be optimized for web'
    },
    video: {
      max_size_mb: 50,
      supported_codecs: %w[h264 vp8 vp9],
      formats: %w[mp4 webm],
      create_poster: true,
      description: 'Video - streaming optimized'
    },
    image: {
      max_size_mb: 5,
      progressive: true,
      formats: %w[webp jpg png],
      description: 'Static image - progressive loading'
    }
  }.freeze

  class << self
    # Detect media type from file path or URL
    def detect_media_type(file_path_or_url)
      extension = extract_extension(file_path_or_url).downcase
      
      MEDIA_TYPES.each do |type, config|
        return type if config[:extensions].include?(extension)
      end
      
      nil
    end

    # Get media category (image, video, animated_image)
    def get_media_category(file_path_or_url)
      media_type = detect_media_type(file_path_or_url)
      return nil unless media_type
      
      MEDIA_TYPES[media_type][:category]
    end

    # Get MIME type for file
    def get_mime_type(file_path_or_url)
      media_type = detect_media_type(file_path_or_url)
      return 'application/octet-stream' unless media_type
      
      MEDIA_TYPES[media_type][:mime]
    end

    # Check if media is video type
    def video?(file_path_or_url)
      get_media_category(file_path_or_url) == 'video'
    end

    # Check if media is animated (GIF, APNG)
    def animated?(file_path_or_url)
      get_media_category(file_path_or_url) == 'animated_image'
    end

    # Check if media is static image
    def static_image?(file_path_or_url)
      get_media_category(file_path_or_url) == 'image'
    end

    # Get optimization strategy for media type
    def get_optimization_strategy(file_path_or_url)
      if video?(file_path_or_url)
        return OPTIMIZATION_CONFIG[:video]
      elsif animated?(file_path_or_url)
        return OPTIMIZATION_CONFIG[:gif]
      else
        return OPTIMIZATION_CONFIG[:image]
      end
    end

    # Generate HTML for media rendering with optimal settings
    def render_media_html(file_path_or_url, options = {})
      media_type = detect_media_type(file_path_or_url)
      category = get_media_category(file_path_or_url)
      
      case category
      when 'video'
        render_video(file_path_or_url, options)
      when 'animated_image'
        render_animated_image(file_path_or_url, options)
      when 'image'
        render_static_image(file_path_or_url, options)
      else
        "<img src=\"#{sanitize_url(file_path_or_url)}\" alt=\"Media\" class=\"media-fallback\">"
      end
    end

    # Render video element with fallbacks
    def render_video(url, options = {})
      url = sanitize_url(url)
      poster = options[:poster] || generate_poster_url(url)
      alt_text = options[:alt] || 'Video'
      classes = options[:class] || 'media-video'
      autoplay = options[:autoplay].nil? ? true : options[:autoplay]
      loop = options[:loop].nil? ? false : options[:loop]
      muted = options[:muted].nil? ? true : options[:muted]
      controls = options[:controls].nil? ? true : options[:controls]

      autoplay_attr = autoplay ? 'autoplay' : ''
      loop_attr = loop ? 'loop' : ''
      muted_attr = muted ? 'muted' : ''
      controls_attr = controls ? 'controls' : ''

      # Generate source tags for multiple formats
      sources = generate_video_sources(url)

      %(
        <video
          class="#{classes}"
          poster="#{poster}"
          #{autoplay_attr}
          #{loop_attr}
          #{muted_attr}
          #{controls_attr}
          playsinline
          style="max-width: 100%; height: auto;"
        >
          #{sources}
          <p>#{alt_text}</p>
        </video>
      ).gsub(/\n\s+/, ' ').strip
    end

    # Render animated image (GIF) with fallback to video
    def render_animated_image(url, options = {})
      url = sanitize_url(url)
      alt_text = options[:alt] || 'Animated image'
      classes = options[:class] || 'media-gif'
      
      # Modern approach: use video for better performance
      if options[:use_video_fallback]
        webm_url = url.gsub(/\.gif$/i, '.webm')
        mp4_url = url.gsub(/\.gif$/i, '.mp4')
        
        render_video(mp4_url, {
          **options,
          poster: generate_poster_url(url),
          autoplay: true,
          loop: true,
          muted: true,
          controls: false,
          class: classes
        })
      else
        # Fallback to standard GIF image tag
        %(
          <img
            src="#{url}"
            alt="#{alt_text}"
            class="#{classes}"
            loading="lazy"
            style="max-width: 100%; height: auto;"
          />
        ).gsub(/\n\s+/, ' ').strip
      end
    end

    # Render static image with progressive loading
    def render_static_image(url, options = {})
      url = sanitize_url(url)
      alt_text = options[:alt] || 'Image'
      classes = options[:class] || 'media-image'
      lazy_load = options[:lazy_load].nil? ? true : options[:lazy_load]
      
      loading_attr = lazy_load ? 'lazy' : 'eager'

      %(
        <img
          src="#{url}"
          alt="#{alt_text}"
          class="#{classes}"
          loading="#{loading_attr}"
          style="max-width: 100%; height: auto;"
        />
      ).gsub(/\n\s+/, ' ').strip
    end

    # Check if file requires optimization
    def requires_optimization?(file_path_or_url, file_size_bytes = nil)
      media_type = detect_media_type(file_path_or_url)
      category = get_media_category(file_path_or_url)
      
      return false unless category
      
      # Always optimize videos and GIFs for web delivery
      return true if %w[video animated_image].include?(category)
      
      # Optimize large static images
      if file_size_bytes && category == 'image'
        return file_size_bytes > (5 * 1024 * 1024) # > 5MB
      end
      
      false
    end

    # Get recommended format for specific use case
    def recommend_format(use_case, source_format)
      case use_case
      when 'thumbnail'
        'webp' # Best compression
      when 'hero'
        'webp' # Best compression, fallback to original
      when 'animated'
        source_format == 'gif' ? 'webm' : source_format # Convert GIF to WebM
      when 'video'
        'mp4' # Most compatible
      else
        source_format
      end
    end

    # Get player configuration for media
    def get_player_config(media_url, options = {})
      category = get_media_category(media_url)
      
      base_config = {
        url: sanitize_url(media_url),
        type: get_mime_type(media_url),
        category: category,
        poster: options[:poster] || generate_poster_url(media_url)
      }

      case category
      when 'video'
        base_config.merge({
          autoplay: options[:autoplay] || false,
          controls: options[:controls] != false,
          loop: options[:loop] || false,
          muted: options[:muted] || true,
          playsinline: true,
          preload: options[:preload] || 'metadata'
        })
      when 'animated_image'
        base_config.merge({
          autoplay: true,
          loop: true,
          controls: false,
          muted: true,
          playsinline: true
        })
      else
        base_config
      end
    end

    private

    def extract_extension(file_path_or_url)
      # Handle URLs with query strings
      path = file_path_or_url.split('?').first
      File.extname(path)
    end

    def sanitize_url(url)
      # Basic URL sanitization
      return '' unless url
      url.to_s.strip
    end

    def generate_poster_url(video_url)
      # Generate poster URL by replacing extension
      video_url.gsub(/\.(mp4|webm|mov)$/i, '.jpg')
    end

    def generate_video_sources(base_url)
      # Generate <source> tags for multiple formats
      formats = [
        { format: 'mp4', mime: 'video/mp4; codecs="avc1.42E01E"' },
        { format: 'webm', mime: 'video/webm; codecs="vp8, vorbis"' }
      ]

      sources = formats.map do |f|
        url = base_url.gsub(/\.(mp4|webm)$/i, ".#{f[:format]}")
        %(<source src="#{url}" type="#{f[:mime]}" />)
      end.join("\n          ")

      sources
    end
  end
end
