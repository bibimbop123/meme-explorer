# routes/trending_api.rb
# API endpoints for trending memes

module Routes
  module TrendingAPI
    def self.registered(app)
      # Get trending memes with filters and pagination
      app.get '/api/v1/trending' do
        content_type :json
        
        time_window = params['time_window'] || '24h'
        # Normalize all-time to all_time for consistency
        time_window = 'all_time' if time_window == 'all-time'
        
        sort_by = params['sort_by'] || 'trending'
        limit = [(params['limit'] || 20).to_i, 100].min
        cursor = params['cursor']
        
        valid_windows = ['1h', '24h', '7d', 'all_time']
        valid_sorts = ['trending', 'latest', 'most_liked', 'rising']
        
        unless valid_windows.include?(time_window)
          status 400
          return { error: "Invalid time_window", received: time_window }.to_json
        end
        
        unless valid_sorts.include?(sort_by)
          status 400
          return { error: "Invalid sort_by" }.to_json
        end
        
        begin
          # Temporarily use simplified service for debugging
          require_relative '../lib/services/trending_service_simple'
          result = TrendingServiceSimple.trending_memes(
            time_window: time_window,
            sort_by: sort_by,
            limit: limit,
            cursor: cursor
          )
          
          { 
            success: true, 
            data: result[:memes], 
            pagination: result[:pagination], 
            meta: { 
              time_window: time_window, 
              sort_by: sort_by, 
              limit: limit 
            } 
          }.to_json
        rescue => e
          puts "❌ [TRENDING API] Error: #{e.class}: #{e.message}"
          puts "❌ [TRENDING API] Backtrace: #{e.backtrace.first(5).join("\n")}"
          status 500
          { error: 'Failed to fetch trending memes', details: e.message }.to_json
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
