# routes/session_metrics.rb
# Session tracking endpoints for iFunny-style analytics
# Updated to use SessionTrackerService for proper session management

require_relative '../lib/services/session_tracker_service'

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
          user_id = current_user_id
          
          # Use SessionTrackerService to update metrics
          session_data = SessionTrackerService.update_metrics(session_id, {
            duration: duration,
            memes_viewed: memes_viewed,
            avg_time_per_meme: avg_time_per_meme
          })
          
          # Log only if session is active and has engagement
          if session_data && session_data[:is_active] && memes_viewed > 0
            AppLogger.debug("📊 [SESSION METRICS] #{session_id[0..7]}: #{memes_viewed} memes, #{duration}s duration, #{avg_time_per_meme.round(1)}s avg")
          elsif session_data && !session_data[:is_active]
            # Don't spam logs with idle sessions
            AppLogger.info("💤 [SESSION] #{session_id[0..7]} idle (#{duration}s, #{memes_viewed} memes)" if memes_viewed == 0 && duration > 600)
          end
          
          status 200
          { 
            success: true,
            session_id: session_id,
            is_active: session_data ? session_data[:is_active] : false,
            recorded_at: Time.now.iso8601
          }.to_json
          
        rescue => e
          AppLogger.error("⚠️  [SESSION METRICS] Error: #{e.message}")
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
          user_id = current_user_id
          
          # Use SessionTrackerService to properly end session
          final_data = SessionTrackerService.end_session(session_id, {
            duration: duration,
            memes_viewed: memes_viewed
          })
          
          # Logging is handled by the service
          
          status 200
          { success: true }.to_json
          
        rescue => e
          AppLogger.error("⚠️  [SESSION END] Error: #{e.message}")
          status 200 # Return 200 to prevent client errors
          { success: false }.to_json
        end
      end
      
      # ============================================
      # POST /api/session/heartbeat
      # Track that user is still active (called every 30s)
      # ============================================
      app.post "/api/session/heartbeat" do
        content_type :json
        
        begin
          # Get session ID and convert to string
          session_id = (session[:session_id] ||= SecureRandom.uuid).to_s
          
          if session_id
            # Update heartbeat
            SessionTrackerService.heartbeat(session_id)
            
            status 200
            { success: true, session_id: session_id }.to_json
          else
            status 200
            { success: false, error: 'No session' }.to_json
          end
          
        rescue => e
          AppLogger.error("⚠️  [SESSION HEARTBEAT] Error: #{e.message}")
          status 200
          { success: false, error: e.message }.to_json
        end
      end
      
    end
  end
end
