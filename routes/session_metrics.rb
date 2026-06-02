# routes/session_metrics.rb
# Session tracking endpoints for iFunny-style analytics

module Routes
  module SessionMetrics
    def self.registered(app)
      
      # ============================================
      # POST /api/session/metrics
      # Track session metrics (called periodically)
      # ============================================
      app.post "/api/session/metrics" do
        content_type :json
        
        begin
          # Parse request body
          request.body.rewind
          data = JSON.parse(request.body.read) rescue {}
          
          # Extract metrics
          duration = data['duration'].to_i
          memes_viewed = data['memes_viewed'].to_i
          avg_time_per_meme = data['avg_time_per_meme'].to_f
          
          # Get session ID from cookie or generate one
          session_id = (session[:session_id] ||= SecureRandom.uuid).to_s
          user_id = session[:user_id]
          
          # Log the metrics (can be expanded to store in DB)
          puts "📊 [SESSION METRICS] #{session_id[0..7]}: #{memes_viewed} memes, #{duration}s duration, #{avg_time_per_meme.round(1)}s avg"
          
          # Optionally store in database if needed
          # This is a placeholder for future implementation
          # DB[:session_metrics].insert(
          #   session_id: session_id,
          #   user_id: user_id,
          #   duration: duration,
          #   memes_viewed: memes_viewed,
          #   avg_time_per_meme: avg_time_per_meme,
          #   updated_at: Time.now
          # )
          
          status 200
          { 
            success: true,
            session_id: session_id,
            recorded_at: Time.now.iso8601
          }.to_json
          
        rescue => e
          puts "⚠️  [SESSION METRICS] Error: #{e.message}"
          status 200 # Return 200 to prevent client errors
          { success: false, error: e.message }.to_json
        end
      end
      
      # ============================================
      # POST /api/session/end
      # Track session end (called on page unload)
      # ============================================
      app.post "/api/session/end" do
        content_type :json
        
        begin
          # Parse form data (sent via sendBeacon)
          duration = params['duration'].to_i
          memes_viewed = params['memes_viewed'].to_i
          
          # Get session ID
          session_id = (session[:session_id] ||= SecureRandom.uuid).to_s
          user_id = session[:user_id]
          
          # Log the session end
          puts "🏁 [SESSION END] #{session_id[0..7]}: #{memes_viewed} memes, #{duration}s total"
          
          # Optionally store final session data in database
          # This is a placeholder for future implementation
          # DB[:session_metrics].where(session_id: session_id).update(
          #   final_duration: duration,
          #   final_memes_viewed: memes_viewed,
          #   ended_at: Time.now
          # )
          
          status 200
          { success: true }.to_json
          
        rescue => e
          puts "⚠️  [SESSION END] Error: #{e.message}"
          status 200 # Return 200 to prevent client errors
          { success: false }.to_json
        end
      end
      
    end
  end
end
