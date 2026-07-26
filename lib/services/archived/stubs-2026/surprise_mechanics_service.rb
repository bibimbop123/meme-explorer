# Surprise Mechanics Service
# Implements variable ratio reinforcement for addictive UX

class SurpriseMechanicsService
  class << self
    # Determine if this selection should be a "surprise"
    def should_trigger_surprise?(session_id = nil)
      config = AlgorithmConfigService.surprise_config
      base_chance = config['base_chance']  # 15% default
      
      # Increase chance during hot streaks
      if session_id
        recent_actions = fetch_recent_actions(session_id)
        consecutive_likes = count_consecutive_likes(recent_actions)
        
        if consecutive_likes >= 3
          # Hot streak multiplier
          base_chance *= config['hot_streak_multiplier']  # 1.5x
        end
        
        # Late night multiplier (11pm - 3am)
        hour = Time.now.hour
        if hour >= 23 || hour <= 3
          base_chance *= config['late_night_multiplier']  # 1.3x
        end
        
        # Cap at max chance
        base_chance = [base_chance, config['max_chance']].min  # Max 40%
        
        rand < base_chance
      end
      
      # Select surprise type based on weights
      def select_surprise_type
        config = AlgorithmConfigService.surprise_config
        types = config['types']
        
        # Weighted random selection
        total_weight = types.values.sum
        random_value = rand * total_weight
        
        cumulative = 0
        types.each do |type, weight|
          cumulative += weight
          return type if random_value <= cumulative
        end
        
        types.keys.first  # Fallback
      end
      
      # Apply surprise selection to meme pool
      def apply_surprise(pool, session_id = nil)
        return pool.sample unless should_trigger_surprise?(session_id)
        
        surprise_type = select_surprise_type
        
        case surprise_type
        when 'ultra_premium'
          # Show ultra-viral meme (10k+ upvotes)
          premium = pool.select { |m| m['likes'].to_i >= 10000 }
          premium.any? ? premium.sample : pool.sample
          
        when 'random_variety'
          # Completely random selection (chaos!)
          pool.sample
          
        when 'unseen_category'
          # New subreddit user hasn't seen
          if session_id
            seen_subreddits = get_seen_subreddits(session_id)
            unseen = pool.reject { |m| seen_subreddits.include?(m['subreddit']) }
            unseen.any? ? unseen.sample : pool.sample
          else
            pool.sample
          end
          
        when 'vintage_throwback'
          # Classic meme from 6+ months ago
          old_memes = pool.select do |m|
            if m['created_at']
              age_days = (Time.now - Time.parse(m['created_at'].to_s)) / 86400
              age_days >= 180 && age_days <= 730  # 6 months to 2 years
            end
          end
          old_memes.any? ? old_memes.sample : pool.sample
          
        else
          pool.sample
        end
      end
      
      # Track that surprise was shown (for analytics)
      def log_surprise(meme, surprise_type, session_id = nil)
        return unless defined?(REDIS) && REDIS && session_id
        
        begin
          key = "surprise_mechanics:#{session_id}"
          data = {
            meme_url: meme['url'],
            surprise_type: surprise_type,
            timestamp: Time.now.iso8601,
            likes: meme['likes']
          }
          
          REDIS.lpush(key, data.to_json)
          REDIS.ltrim(key, 0, 99)  # Keep last 100
          REDIS.expire(key, 30 * 86400)  # 30 days
        rescue => e
          AppLogger.error("Surprise logging error: #{e.message}")
        end
      end
      
      private
      
      def fetch_recent_actions(session_id)
        return [] unless defined?(REDIS) && REDIS
        
        begin
          key = "session:#{session_id}:recent_humor"
          REDIS.lrange(key, 0, -1) || []
        rescue
          []
        end
      end
      
      def count_consecutive_likes(actions)
        count = 0
        actions.reverse.each do |action|
          if action.include?('liked')
            count += 1
          else
            break
          end
        end
        count
      end
      
      def get_seen_subreddits(session_id)
        return [] unless defined?(REDIS) && REDIS
        
        begin
          key = "session:#{session_id}:seen_subreddits"
          REDIS.smembers(key) || []
        rescue
          []
        end
      end
    end
  end
end