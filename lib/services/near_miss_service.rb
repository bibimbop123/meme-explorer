# Near-Miss Service
# Creates anticipation by teasing premium content "coming up"

module MemeExplorer
  class NearMissService
    class << self
      # Check if we should show a near-miss tease
      def should_show_tease?(pool, session_id = nil)
        return false unless pool.is_a?(Array) && pool.any?
        
        # 20% chance to show tease
        return false unless rand < 0.20
        
        # Must have legendary content in pool
        legendary_count = pool.count { |m| m['likes'].to_i >= 50000 }
        legendary_count > 0
      end
      
      # Generate near-miss message
      def generate_tease(pool, session_id = nil)
        legendary_count = pool.count { |m| m['likes'].to_i >= 50000 }
        ultra_viral_count = pool.count { |m| m['likes'].to_i >= 10000 }
        
        messages = []
        
        if legendary_count > 0
          messages << {
            type: 'legendary_coming',
            icon: '👑',
            message: "LEGENDARY meme in the next few...",
            urgency: 'high',
            count: legendary_count
          }
        end
        
        if ultra_viral_count > 3
          messages << {
            type: 'ultra_viral_batch',
            icon: '🔥',
            message: "#{ultra_viral_count} VIRAL memes coming up!",
            urgency: 'medium',
            count: ultra_viral_count
          }
        end
        
        # Check for new categories
        if session_id
          seen_subreddits = get_seen_subreddits(session_id)
          unseen = pool.reject { |m| seen_subreddits.include?(m['subreddit']) }
          
          if unseen.size >= 5
            new_category = unseen.first['subreddit']
            messages << {
              type: 'new_category',
              icon: '✨',
              message: "New category unlocked: r/#{new_category}",
              urgency: 'low',
              category: new_category
            }
          end
        end
        
        messages.sample  # Return one random tease
      end
      
      # Track tease effectiveness (did they keep browsing?)
      def track_tease_shown(tease, session_id)
        return unless defined?(REDIS) && REDIS && session_id
        
        begin
          key = "near_miss:#{session_id}:shown"
          data = {
            type: tease[:type],
            timestamp: Time.now.iso8601,
            message: tease[:message]
          }
          
          REDIS.setex(key, 300, data.to_json)  # 5 min expiry
        rescue => e
          AppLogger.error("Tease tracking error: #{e.message}")
        end
      end
      
      # Check if tease led to continued browsing
      def tease_was_effective?(session_id)
        return false unless defined?(REDIS) && REDIS && session_id
        
        begin
          key = "near_miss:#{session_id}:shown"
          tease_data = REDIS.get(key)
          
          if tease_data
            # If tease was shown in last 5 min and user is still browsing
            tease = JSON.parse(tease_data)
            shown_at = Time.parse(tease['timestamp'])
            
            # Tease is effective if user continued browsing
            (Time.now - shown_at) < 300  # Still within 5 min window
          else
            false
          end
        rescue
          false
        end
      end
      
      private
      
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
