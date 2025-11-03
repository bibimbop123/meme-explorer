# Trending API with Image Optimization
# Returns memes with optimized image URLs (280px, 600px, 1200px in JPEG & WebP)
# Phase 2: Image Optimization Pipeline - Day 4 API Integration

module API
  module V1
    class TrendingOptimized
      def initialize(app)
        @app = app
      end

      def call(env)
        @request = Rack::Request.new(env)
        @response = Rack::Response.new

        case [@request.request_method, @request.path]
        when ['GET', '/api/v1/trending']
          handle_trending_request
        when ['POST', '/api/v1/memes/optimize']
          handle_optimize_request
        else
          @app.call(env)
        end

        @response.finish
      end

      private

      def handle_trending_request
        time_window = @request.params['time_window'] || '24h'
        sort_by = @request.params['sort_by'] || 'trending'
        limit = (@request.params['limit'] || 20).to_i
        page = (@request.params['page'] || 0).to_i

        # Fetch memes
        memes = fetch_trending_memes(time_window, sort_by, limit, page)

        # Format response with optimized images
        data = memes.map { |meme| format_meme_response(meme) }

        @response.status = 200
        @response['Content-Type'] = 'application/json'
        @response.write(JSON.generate({
          success: true,
          data:,
          pagination: {
            page:,
            limit:,
            has_more: memes.length == limit
          }
        }))
      end

      def handle_optimize_request
        meme_id = @request.params['meme_id']
        image_url = @request.params['image_url']

        unless meme_id && image_url
          @response.status = 400
          @response.write(JSON.generate({ error: 'meme_id and image_url required' }))
          return
        end

        # Call image optimization service
        result = ImageOptimizationService.process_image(image_url, meme_id)

        if result[:success]
          @response.status = 200
          @response['Content-Type'] = 'application/json'
          @response.write(JSON.generate(result))
        else
          @response.status = 500
          @response.write(JSON.generate({
            success: false,
            error: result[:error]
          }))
        end
      end

      def format_meme_response(meme)
        # Check if meme has optimized images
        optimized = meme.image_urls.present? && 
                    meme.image_urls['mobile_jpeg_url'].present?

        if optimized
          # Phase 2: Return optimized URLs
          {
            id: meme.id,
            title: meme.title,
            subreddit: meme.subreddit,
            likes: meme.likes,
            views: meme.views,
            # Original URL (fallback)
            image_url: meme.image_url,
            # Optimized image URLs (responsive variants)
            images: {
              thumbnail_jpeg: meme.image_urls['thumbnail_jpeg_url'],
              thumbnail_webp: meme.image_urls['thumbnail_webp_url'],
              mobile_jpeg: meme.image_urls['mobile_jpeg_url'],
              mobile_webp: meme.image_urls['mobile_webp_url'],
              desktop_jpeg: meme.image_urls['desktop_jpeg_url'],
              desktop_webp: meme.image_urls['desktop_webp_url']
            },
            # Metadata
            metadata: {
              blur_hash: meme.image_metadata&.dig('blur_hash'),
              optimization_status: meme.optimization_status,
              optimized_at: meme.optimized_at
            }
          }
        else
          # Phase 1 fallback: Return original URL only
          {
            id: meme.id,
            title: meme.title,
            subreddit: meme.subreddit,
            likes: meme.likes,
            views: meme.views,
            image_url: meme.image_url,
            images: {
              # All point to original URL until optimized
              thumbnail_jpeg: meme.image_url,
              thumbnail_webp: meme.image_url,
              mobile_jpeg: meme.image_url,
              mobile_webp: meme.image_url,
              desktop_jpeg: meme.image_url,
              desktop_webp: meme.image_url
            },
            metadata: {
              optimization_status: 'pending'
            }
          }
        end
      end

      def fetch_trending_memes(time_window, sort_by, limit, page)
        # Placeholder - replace with actual trending logic
        # This would query the database based on time_window and sort_by
        
        filters = build_time_window_filter(time_window)
        order = build_sort_order(sort_by)
        offset = page * limit

        # Query would be something like:
        # Meme.where(filters).order(order).limit(limit).offset(offset)
        
        # For now, return empty array (to be integrated with actual DB logic)
        []
      end

      def build_time_window_filter(time_window)
        case time_window
        when '1h'
          { created_at: (Time.now - 3600)..Time.now }
        when '24h'
          { created_at: (Time.now - 86400)..Time.now }
        when '7d'
          { created_at: (Time.now - 604800)..Time.now }
        when 'all-time'
          {}
        else
          { created_at: (Time.now - 86400)..Time.now } # Default 24h
        end
      end

      def build_sort_order(sort_by)
        case sort_by
        when 'trending'
          { likes: :desc }
        when 'latest'
          { created_at: :desc }
        when 'most_liked'
          { likes: :desc }
        when 'rising'
          # Likes per hour metric
          { likes: :desc }
        else
          { likes: :desc } # Default trending
        end
      end
    end
  end
end

# Integration with app.rb:
# Add to config.ru or app.rb:
#
# use API::V1::TrendingOptimized
#
# Or as direct route in app.rb:
#
# get '/api/v1/trending' do
#   trending_api = API::V1::TrendingOptimized.new(nil)
#   trending_api.call(request.env)
# end
