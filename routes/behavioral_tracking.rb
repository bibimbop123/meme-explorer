# Behavioral Tracking Routes
# Tracks user behavior for personalization and learning algorithms

module Routes
  module BehavioralTracking
    def self.registered(app)
      # Track user behavior for personalization
      app.post "/api/track-behavior" do
        content_type :json
        
        begin
          # Parse request body
          request.body.rewind
          data = JSON.parse(request.body.read)
          
          # Extract tracking data
          meme_url = data['meme_url']
          action = data['action']
          duration = data['duration'].to_f
          subreddit = data['subreddit']
          
          # Store in Redis for real-time personalization
          if defined?(REDIS) && REDIS
            session_id = session[:session_id] || session.id
            
            # Create tracking entry
            tracking_entry = {
              meme_url: meme_url,
              action: action,
              duration: duration,
              subreddit: subreddit,
              timestamp: Time.now.to_i
            }
            
            # Store in user's recent actions
            key = "recent_humor_types:#{session_id}"
            recent = REDIS.get(key)
            recent_array = recent ? JSON.parse(recent) : []
            
            # Add action with metadata for personalization
            action_with_meta = "#{action}:#{subreddit}"
            recent_array << action_with_meta
            recent_array = recent_array.last(20)  # Keep last 20
            
            REDIS.setex(key, 3600, recent_array.to_json)
            
            # Also track in database for long-term learning (if user logged in)
            if current_user_id
              DB.execute(
                "INSERT INTO user_behavior_log (user_id, meme_url, action, duration, subreddit, created_at) 
                 VALUES (?, ?, ?, ?, ?, ?) 
                 ON CONFLICT DO NOTHING",
                [current_user_id, meme_url, action, duration, subreddit, Time.now.to_s]
              ) rescue nil
            end
            
            { success: true, tracked: action }.to_json
          else
            { success: false, error: "Redis not available" }.to_json
          end
        rescue => e
          logger.error "Behavioral tracking error: #{e.message}"
          { success: false, error: e.message }.to_json
        end
      end
    end
  end
end
