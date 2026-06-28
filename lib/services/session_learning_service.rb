# Session-Based Learning Service - iFunny-Style Real-Time Personalization
# Learns user preferences during a session and adapts recommendations in real-time
# Uses both database and Redis for fast learning

module MemeExplorer
  class SessionLearningService
    class << self
      
      # Learn from user interaction in real-time
      def learn_from_interaction(session_id, meme, interaction_type, user_id: nil, duration: 0)
        # Extract learning signals
        subreddit = (meme['subreddit'] || '').downcase
        humor_type = detect_humor_type(meme)
        hour_of_day = Time.now.hour
        
        # Update session preferences (Redis for speed)
        update_session_preferences_redis(session_id, subreddit, humor_type, interaction_type)
        
        # Update database for persistence
        update_session_preferences_db(session_id, user_id, subreddit, humor_type, interaction_type, hour_of_day)
        
        # Track in user_interactions table
        track_detailed_interaction(session_id, user_id, meme, interaction_type, duration, humor_type)
        
        # Update user engagement patterns if logged in
        update_engagement_patterns(user_id, hour_of_day, interaction_type) if user_id
      end
      
      # Get current session preferences
      def get_session_preferences(session_id)
        # Try Redis first (fast)
        redis_prefs = get_session_preferences_redis(session_id)
        return redis_prefs unless redis_prefs.empty?
        
        # Fallback to database
        get_session_preferences_db(session_id)
      end
      
      # Predict what user will like based on session learning
      def predict_preference_score(session_id, meme)
        preferences = get_session_preferences(session_id)
        return 0.5 if preferences.empty? # Neutral score
        
        score = 0.5 # Start neutral
        
        # Subreddit preference
        subreddit = (meme['subreddit'] || '').downcase
        if preferences[:subreddits] && preferences[:subreddits][subreddit]
          subreddit_score = preferences[:subreddits][subreddit]
          score += (subreddit_score - 0.5) * 0.4 # Up to ±0.4 adjustment
        end
        
        # Humor type preference
        humor_type = detect_humor_type(meme)
        if preferences[:humor_types] && preferences[:humor_types][humor_type]
          humor_score = preferences[:humor_types][humor_type]
          score += (humor_score - 0.5) * 0.3 # Up to ±0.3 adjustment
        end
        
        # Time of day preference
        hour = Time.now.hour
        if preferences[:time_preferences] && preferences[:time_preferences][hour]
          time_score = preferences[:time_preferences][hour]
          score += (time_score - 0.5) * 0.2 # Up to ±0.2 adjustment
        end
        
        # Clamp between 0 and 1
        [[score, 0.0].max, 1.0].min
      end
      
      # Get learning confidence (how much data we have)
      def get_learning_confidence(session_id)
        preferences = get_session_preferences(session_id)
        return 0.0 if preferences.empty?
        
        total_samples = 0
        total_samples += preferences[:subreddits].values.sum if preferences[:subreddits]
        total_samples += preferences[:humor_types].values.sum if preferences[:humor_types]
        
        # Confidence grows with samples, maxes at 1.0 after 50 interactions
        confidence = [total_samples / 50.0, 1.0].min
        confidence
      end
      
      # Get best recommendations based on session learning
      def get_learned_recommendations(session_id, available_memes, limit: 10)
        preferences = get_session_preferences(session_id)
        return available_memes.sample(limit) if preferences.empty?
        
        # Score all memes
        scored_memes = available_memes.map do |meme|
          {
            meme: meme,
            score: predict_preference_score(session_id, meme)
          }
        end
        
        # Sort by score and return top N
        scored_memes.sort_by { |sm| -sm[:score] }
                    .take(limit)
                    .map { |sm| sm[:meme] }
      end
      
      # Analyze session learning effectiveness
      def get_session_analytics(session_id)
        preferences = get_session_preferences(session_id)
        
        {
          confidence: get_learning_confidence(session_id),
          total_interactions: calculate_total_interactions(preferences),
          top_subreddits: get_top_items(preferences[:subreddits], 5),
          top_humor_types: get_top_items(preferences[:humor_types], 3),
          preferred_hours: get_top_items(preferences[:time_preferences], 3),
          learning_stage: determine_learning_stage(session_id)
        }
      end
      
      # Clear session learning (useful for testing)
      def clear_session_learning(session_id)
        # Clear Redis
        if defined?(REDIS) && REDIS
          REDIS.del("session:prefs:#{session_id}")
        end
        
        # Clear database
        if defined?(DB) && DB
          DB.execute("DELETE FROM session_learning WHERE session_id = ?", [session_id])
        end
      end
      
      private
      
      # Redis-based session preferences (fast)
      def update_session_preferences_redis(session_id, subreddit, humor_type, interaction_type)
        return unless defined?(REDIS) && REDIS
        
        key = "session:prefs:#{session_id}"
        
        begin
          # Get current preferences
          prefs_json = REDIS.get(key)
          prefs = prefs_json ? JSON.parse(prefs_json, symbolize_names: true) : {}
          
          # Initialize structures
          prefs[:subreddits] ||= {}
          prefs[:humor_types] ||= {}
          prefs[:interactions] ||= 0
          
          # Update based on interaction type
          weight = case interaction_type
          when 'like' then 1.0
          when 'view' then 0.1
          when 'skip' then -0.5
          when 'share' then 1.5
          else 0.0
          end
          
          # Update subreddit preference (exponential moving average)
          alpha = 0.3 # Learning rate
          prefs[:subreddits][subreddit] ||= 0.5
          prefs[:subreddits][subreddit] = prefs[:subreddits][subreddit] * (1 - alpha) + weight * alpha
          
          # Update humor type preference
          prefs[:humor_types][humor_type] ||= 0.5
          prefs[:humor_types][humor_type] = prefs[:humor_types][humor_type] * (1 - alpha) + weight * alpha
          
          # Track interaction count
          prefs[:interactions] += 1
          
          # Save back to Redis (expire after 1 hour of inactivity)
          REDIS.setex(key, 3600, prefs.to_json)
        rescue => e
          puts "⚠️ Redis session learning error: #{e.message}"
        end
      end
      
      def get_session_preferences_redis(session_id)
        return {} unless defined?(REDIS) && REDIS
        
        begin
          key = "session:prefs:#{session_id}"
          prefs_json = REDIS.get(key)
          prefs_json ? JSON.parse(prefs_json, symbolize_names: true) : {}
        rescue => e
          puts "⚠️ Redis get preferences error: #{e.message}"
          {}
        end
      end
      
      # Database-based session preferences (persistent)
      def update_session_preferences_db(session_id, user_id, subreddit, humor_type, interaction_type, hour)
        return unless defined?(DB) && DB
        
        begin
          # Calculate preference value
          value = case interaction_type
          when 'like' then 1.0
          when 'view' then 0.1
          when 'skip' then 0.0
          when 'share' then 1.0
          else 0.5
          end
          
          # Update subreddit preference
          update_learning_entry(session_id, user_id, 'subreddit_preference', subreddit, value)
          
          # Update humor preference
          update_learning_entry(session_id, user_id, 'humor_preference', humor_type, value)
          
          # Update time preference
          update_learning_entry(session_id, user_id, 'time_preference', hour.to_s, value)
        rescue => e
          puts "⚠️ DB session learning error: #{e.message}"
        end
      end
      
      def update_learning_entry(session_id, user_id, learning_type, key, value)
        DB.execute(
          "INSERT INTO session_learning 
           (session_id, user_id, learning_type, key, value, confidence, sample_size, last_updated)
           VALUES (?, ?, ?, ?, ?, 0.5, 1, CURRENT_TIMESTAMP)
           ON CONFLICT (session_id, learning_type, key)
           DO UPDATE SET
             value = (session_learning.value * session_learning.sample_size + ?) / (session_learning.sample_size + 1),
             sample_size = session_learning.sample_size + 1,
             confidence = LEAST(1.0, (session_learning.sample_size + 1) / 50.0),
             last_updated = CURRENT_TIMESTAMP",
          [session_id, user_id, learning_type, key, value, value]
        )
      rescue StandardError => e
        puts "⚠️ [SessionLearning] update_learning_entry failed: #{e.message}"
      end
      
      def get_session_preferences_db(session_id)
        return {} unless defined?(DB) && DB
        
        begin
          results = DB.execute(
            "SELECT learning_type, key, value, confidence, sample_size
             FROM session_learning
             WHERE session_id = ?
             AND last_updated > datetime('now', '-1 hour')",
            [session_id]
          )
          
          preferences = {
            subreddits: {},
            humor_types: {},
            time_preferences: {}
          }
          
          results.each do |row|
            type = row['learning_type']
            key = row['key']
            value = row['value'].to_f
            
            case type
            when 'subreddit_preference'
              preferences[:subreddits][key] = value
            when 'humor_preference'
              preferences[:humor_types][key] = value
            when 'time_preference'
              preferences[:time_preferences][key.to_i] = value
            end
          end
          
          preferences
        rescue => e
          puts "⚠️ DB get preferences error: #{e.message}"
          {}
        end
      end
      
      def track_detailed_interaction(session_id, user_id, meme, interaction_type, duration, humor_type)
        return unless defined?(DB) && DB
        
        begin
          meme_id = meme['id'] || meme['url']
          pool_type = meme['diversity_pool'] || meme['pool_type'] || 'unknown'
          
          DB.execute(
            "INSERT INTO user_interactions 
             (user_id, session_id, meme_id, meme_url, interaction_type, duration_seconds, 
              subreddit, pool_type, humor_type, engagement_rate, created_at)
             VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, CURRENT_TIMESTAMP)",
            [user_id, session_id, meme_id, meme['url'], interaction_type, duration,
             meme['subreddit'], pool_type, humor_type, meme['engagement_rate'].to_f]
          )
        rescue => e
          puts "⚠️ Interaction tracking error: #{e.message}"
        end
      end
      
      def update_engagement_patterns(user_id, hour, interaction_type)
        return unless defined?(DB) && DB
        
        begin
          day_of_week = Time.now.wday
          
          DB.execute(
            "INSERT INTO user_engagement_patterns 
             (user_id, hour_of_day, day_of_week, sample_size, last_updated)
             VALUES (?, ?, ?, 1, CURRENT_TIMESTAMP)
             ON CONFLICT (user_id, hour_of_day, day_of_week)
             DO UPDATE SET
               sample_size = user_engagement_patterns.sample_size + 1,
               engagement_rate = CASE 
                 WHEN ? = 'like' THEN (user_engagement_patterns.engagement_rate * user_engagement_patterns.sample_size + 1.0) / (user_engagement_patterns.sample_size + 1)
                 ELSE (user_engagement_patterns.engagement_rate * user_engagement_patterns.sample_size) / (user_engagement_patterns.sample_size + 1)
               END,
               last_updated = CURRENT_TIMESTAMP",
            [user_id, hour, day_of_week, interaction_type]
          )
        rescue => e
          # SQLite fallback - simpler approach
          puts "⚠️ Engagement pattern update skipped: #{e.message}"
        end
      end
      
      def detect_humor_type(meme)
        # Use existing humor detection from RandomSelectorService
        if defined?(RandomSelectorService)
          RandomSelectorService.send(:detect_primary_humor_type, meme) rescue 'general'
        else
          'general'
        end
      end
      
      def calculate_total_interactions(preferences)
        total = 0
        total += preferences[:subreddits].values.sum if preferences[:subreddits]
        total += preferences[:humor_types].values.sum if preferences[:humor_types]
        total
      end
      
      def get_top_items(hash, limit)
        return [] unless hash
        hash.sort_by { |_, v| -v }.take(limit).to_h
      end
      
      def determine_learning_stage(session_id)
        confidence = get_learning_confidence(session_id)
        
        case confidence
        when 0.0...0.2 then 'exploration' # Still learning
        when 0.2...0.5 then 'learning'    # Building preferences
        when 0.5...0.8 then 'confident'   # Good understanding
        else 'expert'                      # Strong preferences
        end
      end
    end
  end
end
