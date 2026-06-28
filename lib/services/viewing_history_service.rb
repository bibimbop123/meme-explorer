# lib/services/viewing_history_service.rb
# Service for tracking meme viewing history using Redis (not sessions!)
# This fixes the "session cookie exceeds 4K" error

module MemeExplorer
  class ViewingHistoryService
    # TTL for viewing history (2 hours)
    HISTORY_TTL = 7200
    
    # Maximum history size per user
    MAX_HISTORY_SIZE = 200
    
    class << self
      # Mark a meme as seen
      def mark_seen(visitor_id, meme_identifier)
        return unless visitor_id && meme_identifier
        
        redis = REDIS  # Use global REDIS constant
        return unless redis  # Guard against Redis being unavailable
        
        key = history_key(visitor_id)
        
        # Add to sorted set with timestamp score
        redis.zadd(key, Time.now.to_i, meme_identifier)
        
        # Keep only last MAX_HISTORY_SIZE memes
        redis.zremrangebyrank(key, 0, -(MAX_HISTORY_SIZE + 1))
        
        # Set expiry
        redis.expire(key, HISTORY_TTL)
        
        AppLogger.debug("📝 Marked meme as seen: #{meme_identifier} for #{visitor_id}")
      rescue => e
        AppLogger.error("Failed to mark meme as seen: #{e.message}")
      end
      
      # Get list of seen meme identifiers
      def get_seen_memes(visitor_id)
        return [] unless visitor_id
        
        redis = REDIS
        return [] unless redis
        
        key = history_key(visitor_id)
        
        # Get all seen memes (returns array of strings)
        seen = redis.zrange(key, 0, -1)
        
        AppLogger.debug("📊 Retrieved #{seen.size} seen memes for #{visitor_id}")
        seen
      rescue => e
        AppLogger.error("Failed to get seen memes: #{e.message}")
        []
      end
      
      # Check if a meme has been seen
      def seen?(visitor_id, meme_identifier)
        return false unless visitor_id && meme_identifier
        
        redis = REDIS
        return false unless redis
        
        key = history_key(visitor_id)
        
        score = redis.zscore(key, meme_identifier)
        !score.nil?
      rescue => e
        AppLogger.error("Failed to check if meme seen: #{e.message}")
        false
      end
      
      # Get count of seen memes
      def seen_count(visitor_id)
        return 0 unless visitor_id
        
        redis = REDIS
        return 0 unless redis
        
        key = history_key(visitor_id)
        
        redis.zcard(key).to_i
      rescue => e
        AppLogger.error("Failed to get seen count: #{e.message}")
        0
      end
      
      # Clear viewing history for a visitor
      def clear_history(visitor_id)
        return unless visitor_id
        
        redis = REDIS
        return unless redis
        
        key = history_key(visitor_id)
        
        redis.del(key)
        AppLogger.info("🗑️  Cleared viewing history for #{visitor_id}")
      rescue => e
        AppLogger.error("Failed to clear history: #{e.message}")
      end
      
      # Get viewing stats for debugging
      def get_stats(visitor_id)
        return {} unless visitor_id
        
        redis = REDIS
        return {} unless redis
        
        key = history_key(visitor_id)
        
        count = redis.zcard(key).to_i
        ttl = redis.ttl(key).to_i
        
        {
          total_seen: count,
          ttl_seconds: ttl,
          ttl_minutes: (ttl / 60.0).round(1)
        }
      rescue => e
        AppLogger.error("Failed to get stats: #{e.message}")
        {}
      end
      
      private
      
      def history_key(visitor_id)
        "viewing_history:#{visitor_id}"
      end
    end
  end
end
