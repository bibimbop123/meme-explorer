# lib/services/viewing_history_service.rb
# Service for tracking meme viewing history using Redis (not sessions!)
# This fixes the "session cookie exceeds 4K" error

module MemeExplorer
  class ViewingHistoryService
    # Bounded recent-selection memory, including speculative prefetch selections.
    HISTORY_TTL = 604800 # seven days since the latest selection
    
    # Maximum history size per user
    MAX_HISTORY_SIZE = 5000
    
    class << self
      # Mark a meme as seen
      def mark_seen(visitor_id, meme_identifier)
        return unless visitor_id && meme_identifier
        
        key = history_key(visitor_id)
        
        RedisService.with_redis do |redis|
          # Add to sorted set with timestamp score
          now = Time.now.to_f
          # Commands have no reply dependencies. Preserve their order while
          # avoiding four sequential network waits. This is not a transaction;
          # concurrent-writer and selection-time history semantics are unchanged.
          redis.pipelined do |pipeline|
            pipeline.zremrangebyscore(key, '-inf', now - HISTORY_TTL)
            pipeline.zadd(key, now, meme_identifier)
            pipeline.zremrangebyrank(key, 0, -(MAX_HISTORY_SIZE + 1))
            pipeline.expire(key, HISTORY_TTL)
          end
          
          AppLogger.debug("📝 Marked meme as seen: #{meme_identifier} for #{visitor_id}")
        end
      rescue => e
        AppLogger.error("Failed to mark meme as seen: #{e.message}")
      end
      
      # Get list of seen meme identifiers
      def get_seen_memes(visitor_id)
        return [] unless visitor_id
        
        key = history_key(visitor_id)
        
        seen = RedisService.with_redis do |redis|
          # Get all seen memes (returns array of strings)
          # Read after pruning on the same connection, without a separate wait
          # per command. Read the resolved pipeline result, not a Redis future.
          results = redis.pipelined do |pipeline|
            pipeline.zremrangebyscore(key, '-inf', Time.now.to_f - HISTORY_TTL)
            pipeline.zrange(key, 0, -1)
          end
          results.last
        end
        
        seen ||= []
        AppLogger.debug("📊 Retrieved #{seen.size} seen memes for #{visitor_id}")
        seen
      rescue => e
        AppLogger.error("Failed to get seen memes: #{e.message}")
        []
      end
      
      # Check if a meme has been seen
      def seen?(visitor_id, meme_identifier)
        return false unless visitor_id && meme_identifier
        
        key = history_key(visitor_id)
        
        score = RedisService.with_redis do |redis|
          redis.zscore(key, meme_identifier)
        end
        
        !score.nil?
      rescue => e
        AppLogger.error("Failed to check if meme seen: #{e.message}")
        false
      end
      
      # Get count of seen memes
      def seen_count(visitor_id)
        return 0 unless visitor_id
        
        key = history_key(visitor_id)
        
        count = RedisService.with_redis do |redis|
          redis.zcard(key)
        end
        
        count.to_i
      rescue => e
        AppLogger.error("Failed to get seen count: #{e.message}")
        0
      end
      
      # Clear viewing history for a visitor
      def clear_history(visitor_id)
        return unless visitor_id
        
        key = history_key(visitor_id)
        
        RedisService.with_redis do |redis|
          redis.del(key)
        end
        
        AppLogger.info("🗑️  Cleared viewing history for #{visitor_id}")
      rescue => e
        AppLogger.error("Failed to clear history: #{e.message}")
      end

      # Bidirectional sync between a browser session history key and an account history key
      # so signed-in users keep anti-repeat continuity across devices and browsers.
      def sync_account_history(session_visitor_id, user_id)
        return unless session_visitor_id && user_id
        session_key = history_key(session_visitor_id)
        account_key = history_key("user:#{user_id}")
        cutoff = Time.now.to_f - HISTORY_TTL

        RedisService.with_redis do |redis|
          source_entries = redis.zrangebyscore(session_key, cutoff, '+inf', with_scores: true) || []
          account_entries = redis.zrangebyscore(account_key, cutoff, '+inf', with_scores: true) || []
          merged = {}
          (account_entries + source_entries).each do |member, score|
            next unless member
            ts = score.to_f
            merged[member] = ts if !merged.key?(member) || ts > merged[member]
          end
          return if merged.empty?

          pairs = merged.map { |member, score| [score, member] }
          redis.pipelined do |pipeline|
            [session_key, account_key].each do |key|
              pipeline.zremrangebyscore(key, '-inf', cutoff)
              pipeline.zadd(key, pairs)
              pipeline.zremrangebyrank(key, 0, -(MAX_HISTORY_SIZE + 1))
              pipeline.expire(key, HISTORY_TTL)
            end
          end
        end
      rescue => e
        AppLogger.warn("Account viewing history sync skipped: #{e.class}")
      end
      
      # Get viewing stats for debugging
      def get_stats(visitor_id)
        return {} unless visitor_id
        
        key = history_key(visitor_id)
        
        stats = RedisService.with_redis do |redis|
          count = redis.zcard(key).to_i
          ttl = redis.ttl(key).to_i
          
          {
            total_seen: count,
            ttl_seconds: ttl,
            ttl_minutes: (ttl / 60.0).round(1)
          }
        end
        
        stats || {}
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
