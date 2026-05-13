# Enhanced Random Meme Route - iFunny-Inspired Algorithm
require 'sinatra/base'
require_relative '../lib/services/enhanced_random_selector'
require_relative '../lib/services/meme_service'

class MemeExplorer < Sinatra::Base
  
  # NEW: Enhanced random endpoint with iFunny-inspired features
    get '/api/random/enhanced' do
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
        user_id = session[:user_id] # May be nil for anonymous users
        
        # Use enhanced selector
        selected = EnhancedRandomSelector.select_meme(
          all_memes,
          session_id: session_id,
          user_id: user_id,
          preferences: {}
        )
        
        if selected
          # Store meme metadata for future profile building
          EnhancedRandomSelector.send(:store_meme_metadata, selected)
          
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
        puts "❌ Enhanced random error: #{e.message}"
        puts e.backtrace.first(5)
        
        Sentry.capture_exception(e) if defined?(Sentry)
        
        status 500
        {
          success: false,
          error: 'Internal server error'
        }.to_json
      end
    end
    
    # Track user interactions for learning
    post '/api/random/track' do
      content_type :json
      
      begin
        data = JSON.parse(request.body.read)
        
        meme_id = data['meme_id']
        interaction_type = data['type'] || 'like'
        user_id = session[:user_id]
        session_id = session[:session_id]
        
        unless meme_id
          return {
            success: false,
            error: 'Missing meme_id'
          }.to_json
        end
        
        # Track the interaction
        EnhancedRandomSelector.track_interaction(
          meme_id,
          user_id: user_id,
          session_id: session_id,
          interaction_type: interaction_type
        )
        
        {
          success: true,
          message: 'Interaction tracked'
        }.to_json
        
      rescue => e
        puts "❌ Track interaction error: #{e.message}"
        
        status 500
        {
          success: false,
          error: 'Failed to track interaction'
        }.to_json
      end
    end
    
    # Get user profile (for debugging/analytics)
    get '/api/random/profile' do
      content_type :json
      
      user_id = session[:user_id]
      
      unless user_id
        return {
          success: false,
          error: 'Not logged in'
        }.to_json
      end
      
      begin
        profile = EnhancedRandomSelector.send(:get_user_profile, user_id)
        
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
    get '/api/random/recommendations' do
      content_type :json
      
      user_id = session[:user_id]
      
      unless user_id
        return {
          success: false,
          error: 'Not logged in'
        }.to_json
      end
      
      begin
        recommendations = EnhancedRandomSelector.send(:get_collaborative_recommendations, user_id, limit: 20)
        
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
    get '/api/random/analytics' do
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
end
