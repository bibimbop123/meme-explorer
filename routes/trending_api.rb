# routes/trending_api.rb
# API endpoints for trending memes

module Routes
  module TrendingAPI
    def self.registered(app)
      # Get trending memes with filters and pagination
      app.get '/api/v1/trending' do
        content_type :json
        
        begin
          time_window = params['time_window'] || '24h'
          # Normalize all-time to all_time for consistency
          time_window = 'all_time' if time_window == 'all-time'
          
          sort_by = params['sort_by'] || 'trending'
          limit = [(params['limit'] || 20).to_i, 100].min
          limit = 20 if limit < 1  # Ensure minimum limit
          cursor = params['cursor']
          
          valid_windows = ['1h', '24h', '7d', 'all_time']
          valid_sorts = ['trending', 'latest', 'most_liked', 'rising']
          
          unless valid_windows.include?(time_window)
            status 400
            return { 
              success: false,
              error: "Invalid time_window", 
              received: time_window,
              valid_options: valid_windows 
            }.to_json
          end
          
          unless valid_sorts.include?(sort_by)
            status 400
            return { 
              success: false,
              error: "Invalid sort_by",
              received: sort_by,
              valid_options: valid_sorts
            }.to_json
          end
          
          # Use simplified service
          require_relative '../lib/services/trending_service_simple'
          result = TrendingServiceSimple.trending_memes(
            time_window: time_window,
            sort_by: sort_by,
            limit: limit,
            cursor: cursor
          )
          
          # Ensure result has data
          if result[:memes].nil? || !result[:memes].is_a?(Array)
            puts "⚠️ [TRENDING API] Invalid result format from service"
            result[:memes] = []
          end
          
          { 
            success: true, 
            data: result[:memes], 
            pagination: result[:pagination] || { has_more: false, next_cursor: nil, total: 0 }, 
            meta: { 
              time_window: time_window, 
              sort_by: sort_by, 
              limit: limit 
            } 
          }.to_json
        rescue LoadError => e
          puts "❌ [TRENDING API] Service not found: #{e.message}"
          status 500
          { 
            success: false,
            error: 'Trending service unavailable', 
            details: ENV['RACK_ENV'] == 'development' ? e.message : nil 
          }.to_json
        rescue => e
          puts "❌ [TRENDING API] Error: #{e.class}: #{e.message}"
          puts "   Backtrace: #{e.backtrace.first(5).join("\n   ")}"
          status 500
          { 
            success: false,
            error: 'Failed to fetch trending memes', 
            details: ENV['RACK_ENV'] == 'development' ? e.message : nil 
          }.to_json
        end
      end

      # Get available badges
      app.get '/api/v1/trending/badges' do
        content_type :json
        { 
          success: true, 
          badges: [
            { id: 'trending_now', label: 'Trending', emoji: '🔥', color: '#FF6B6B' }, 
            { id: 'hot', label: 'Hot', emoji: '📈', color: '#FFD700' }
          ] 
        }.to_json
      end
    end
  end
end
