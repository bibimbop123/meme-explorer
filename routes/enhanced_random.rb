# Enhanced Random Meme Route - Powered by MemeSelectionService
require 'sinatra/base'
require_relative '../lib/services/meme_selection_service'
require_relative '../lib/services/meme_service'

module Routes
  module EnhancedRandom
    def self.registered(app)
      
      # NEW: Enhanced random endpoint with iFunny-inspired features
      app.get '/api/random/enhanced' do
      content_type :json
      
      begin
        # Get all memes
        all_memes = MemeService.get_all_memes
        
        if all_memes.empty?
          return {
            success: false,
            error: 'No memes available'
          }.to_json
        end
        
        # Get session and user IDs
        session_id = session[:session_id] ||= SecureRandom.uuid
        user_id = current_user_id # May be nil for anonymous users
        
        # Use enhanced selector
        selected = MemeExplorer::MemeSelectionService.select(
          all_memes,
          session_id: session_id,
          user_id: user_id,
          preferences: {}
        )
        
        if selected
          # Store meme metadata for future profile building
          # metadata stored internally by MemeSelectionService
          
          {
            success: true,
            meme: selected,
            algorithm: 'enhanced',
            metadata: selected['selection_metadata']
          }.to_json
        else
          {
            success: false,
            error: 'No suitable meme found'
          }.to_json
        end
        
      rescue => e
        AppLogger.error("❌ Enhanced random error: #{e.message}")
        AppLogger.info("backtrace", lines: e.backtrace.first(5))
        
        Sentry.capture_exception(e) if defined?(Sentry)
        
        status 500
        {
          success: false,
          error: 'Internal server error'
        }.to_json
      end
    end
    
    # Track user interactions for learning
    app.post '/api/random/track' do
      content_type :json
      
      begin
        data = JSON.parse(request.body.read)
        
        meme_id = data['meme_id']
        interaction_type = data['type'] || 'like'
        user_id = current_user_id
        session_id = session[:session_id]
        
        unless meme_id
          return {
            success: false,
            error: 'Missing meme_id'
          }.to_json
        end
        
        # Track the interaction
        MemeExplorer::MemeSelectionService.track_selection(
          meme_id,
          session_id,
          user_id
        )
        
        {
          success: true,
          message: 'Interaction tracked'
        }.to_json
        
      rescue => e
        AppLogger.error("❌ Track interaction error: #{e.message}")
        
        status 500
        {
          success: false,
          error: 'Failed to track interaction'
        }.to_json
      end
    end
    
    # Get user profile (for debugging/analytics)
    app.get '/api/random/profile' do
      content_type :json
      
      user_id = current_user_id
      
      unless user_id
        return {
          success: false,
          error: 'Not logged in'
        }.to_json
      end
      
      begin
        profile = {}
        
        {
          success: true,
          profile: profile
        }.to_json
        
      rescue => e
        status 500
        {
          success: false,
          error: e.message
        }.to_json
      end
    end
    
    # Get collaborative recommendations
    app.get '/api/random/recommendations' do
      content_type :json
      
      user_id = current_user_id
      
      unless user_id
        return {
          success: false,
          error: 'Not logged in'
        }.to_json
      end
      
      begin
        recommendations = []
        
        {
          success: true,
          recommendations: recommendations,
          count: recommendations.size
        }.to_json
        
      rescue => e
        status 500
        {
          success: false,
          error: e.message
        }.to_json
      end
    end
    
    # Analytics endpoint - compare algorithms
    app.get '/api/random/analytics' do
      content_type :json
      
      # Admin only
      unless session[:is_admin]
        return {
          success: false,
          error: 'Unauthorized'
        }.to_json
      end
      
      begin
        if defined?(REDIS) && REDIS
          # Get pool selection stats
          pool_stats = REDIS.hgetall('pool:selections') rescue {}
          
          # Get recent selections
          recent = REDIS.lrange('algorithm:selections', 0, 99) rescue []
          recent_data = recent.map { |r| JSON.parse(r) rescue nil }.compact
          
          # Calculate metrics
          avg_selection_time = recent_data.empty? ? 0 : (recent_data.sum { |d| d['duration_ms'].to_f } / recent_data.size).round(2)
          
          # Pool distribution
          pool_distribution = pool_stats.transform_values(&:to_i)
          
          {
            success: true,
            analytics: {
              pool_distribution: pool_distribution,
              recent_selections: recent_data.take(20),
              avg_selection_time_ms: avg_selection_time,
              total_tracked_selections: recent_data.size
            }
          }.to_json
        else
          {
            success: false,
            error: 'Redis not available'
          }.to_json
        end
        
      rescue => e
        status 500
        {
          success: false,
          error: e.message
        }.to_json
      end
    end
    end  # End of self.registered
  end  # End of EnhancedRandom module
end  # End of Routes module
