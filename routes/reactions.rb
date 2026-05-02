# Reactions Routes
# Handles meme reactions (😂 🔥 💀 😱 🤔)

module MemeExplorer
  module Routes
    class Reactions
      def self.register(app)
        # Add or toggle a reaction
        app.post '/api/reactions' do
          url = params[:url]
          reaction_type = params[:type]
          user_id = session[:user_id]
          session_id = session.object_id.to_s
          
          halt 400, { error: 'Missing URL parameter' }.to_json unless url
          halt 400, { error: 'Missing reaction type' }.to_json unless reaction_type
          
          # Validate reaction type
          valid_types = %w[hilarious fire dead shocking relatable]
          unless valid_types.include?(reaction_type)
            halt 400, { error: 'Invalid reaction type' }.to_json
          end
          
          begin
            # Check if user already reacted with this type
            existing = DB.execute(
              "SELECT id FROM meme_reactions 
               WHERE meme_url = ? AND reaction_type = ? 
               AND (user_id = ? OR session_id = ?)",
              [url, reaction_type, user_id, session_id]
            ).first
            
            if existing
              # Toggle off - remove reaction
              DB.execute(
                "DELETE FROM meme_reactions 
                 WHERE meme_url = ? AND reaction_type = ? 
                 AND (user_id = ? OR session_id = ?)",
                [url, reaction_type, user_id, session_id]
              )
              toggled = false
            else
              # Add new reaction
              DB.execute(
                "INSERT INTO meme_reactions (meme_url, user_id, session_id, reaction_type) 
                 VALUES (?, ?, ?, ?)",
                [url, user_id, session_id, reaction_type]
              )
              
              # Award XP for first reaction
              if user_id && defined?(GamificationHelpers)
                app.helpers.add_xp(user_id, :react_meme) rescue nil
              end
              
              toggled = true
            end
            
            # Track action
            if defined?(ActivityTrackerService)
              ActivityTrackerService.record_action('reaction', user_id || session_id)
            end
            
            # Get updated counts for this meme
            counts = DB.execute(
              "SELECT reaction_type, COUNT(*) as count 
               FROM meme_reactions 
               WHERE meme_url = ? 
               GROUP BY reaction_type",
              [url]
            ).each_with_object({}) { |row, hash| hash[row['reaction_type']] = row['count'].to_i }
            
            # Get user's reactions
            user_reactions = DB.execute(
              "SELECT reaction_type FROM meme_reactions 
               WHERE meme_url = ? 
               AND (user_id = ? OR session_id = ?)",
              [url, user_id, session_id]
            ).map { |r| r['reaction_type'] }
            
            content_type :json
            { 
              success: true, 
              toggled: toggled,
              counts: counts,
              user_reactions: user_reactions
            }.to_json
          rescue => e
            puts "❌ [REACTIONS] Error: #{e.message}"
            Sentry.capture_exception(e) if defined?(Sentry)
            halt 500, { error: 'Failed to save reaction' }.to_json
          end
        end
        
        # Get reactions for a meme
        app.get '/api/reactions' do
          url = params[:url]
          halt 400, { error: 'Missing URL parameter' }.to_json unless url
          
          begin
            user_id = session[:user_id]
            session_id = session.object_id.to_s
            
            # Get all reaction counts
            counts = DB.execute(
              "SELECT reaction_type, COUNT(*) as count 
               FROM meme_reactions 
               WHERE meme_url = ? 
               GROUP BY reaction_type",
              [url]
            ).each_with_object({}) { |row, hash| hash[row['reaction_type']] = row['count'].to_i }
            
            # Get user's reactions
            user_reactions = DB.execute(
              "SELECT reaction_type FROM meme_reactions 
               WHERE meme_url = ? 
               AND (user_id = ? OR session_id = ?)",
              [url, user_id, session_id]
            ).map { |r| r['reaction_type'] }
            
            content_type :json
            { 
              counts: counts,
              user_reactions: user_reactions,
              total: counts.values.sum
            }.to_json
          rescue => e
            puts "❌ [REACTIONS] Error fetching: #{e.message}"
            content_type :json
            { counts: {}, user_reactions: [], total: 0 }.to_json
          end
        end
        
        # Get top reacted memes
        app.get '/api/reactions/top' do
          limit = (params[:limit] || 20).to_i
          time_window = params[:time_window] || '24h'
          
          begin
            # Calculate time cutoff
            cutoff = case time_window
                     when '1h' then Time.now - 3600
                     when '24h' then Time.now - 86400
                     when '7d' then Time.now - 604800
                     else Time.now - 86400
                     end
            
            top_memes = DB.execute(
              "SELECT meme_url, COUNT(*) as reaction_count,
                      COUNT(DISTINCT reaction_type) as reaction_variety
               FROM meme_reactions
               WHERE created_at > ?
               GROUP BY meme_url
               ORDER BY reaction_count DESC, reaction_variety DESC
               LIMIT ?",
              [cutoff, limit]
            )
            
            content_type :json
            top_memes.to_json
          rescue => e
            puts "❌ [REACTIONS] Error fetching top: #{e.message}"
            content_type :json
            [].to_json
          end
        end
      end
    end
  end
end
