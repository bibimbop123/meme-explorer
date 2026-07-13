# Diversity Engine V2 - ANTI-REPETITION EDITION
# Fix: Dramatically relaxed filters for 10x larger pools
# Goal: Users should NEVER see the same meme twice in a session

module MemeExplorer
  class DiversityEngineServiceV2
    class << self
      # CORE: Select from MUCH larger, less restrictive pools
      def select_diverse_meme(all_memes, session_id:, preferences: {})
        return all_memes.sample if all_memes.empty?
        
        # Use ViewingHistoryService for consistent tracking
        # session_id is used as visitor_id for unified tracking
        seen_memes = MemeExplorer::ViewingHistoryService.get_seen_memes(session_id)
        
        # CRITICAL: Remove ALL previously seen memes
        unseen_memes = all_memes.reject do |meme|
          meme_id = meme['url'] || meme['file'] || meme['id']
          seen_memes.include?(meme_id)
        end
        
        # If we've seen everything, reset history and start fresh
        if unseen_memes.empty?
          puts "🔄 User has seen all #{all_memes.size} memes! Resetting history..."
          MemeExplorer::ViewingHistoryService.clear_history(session_id)
          unseen_memes = all_memes
        end
        
        puts "📊 Pool stats: #{all_memes.size} total, #{unseen_memes.size} unseen (#{seen_memes.size} seen)"
        
        # Determine pool type
        pool_type = determine_next_pool(session_id)
        
        # Get pool with RELAXED filters
        pool_memes = get_pool_memes(unseen_memes, pool_type, session_id)
        
        # If pool still too small, use ALL unseen memes
        if pool_memes.size < 20
          puts "⚠️  Pool '#{pool_type}' only has #{pool_memes.size} memes, using all unseen (#{unseen_memes.size})"
          pool_memes = unseen_memes
        end
        
        # Select using existing selection service
        selected = MemeExplorer::MemeSelectionService.select_random_meme(
          pool_memes,
          session_id: session_id,
          preferences: preferences
        )
        
        # Track usage
        track_pool_usage(session_id, pool_type)
        
        # DON'T mark as seen here! Let the route do it after successful delivery
        # This prevents marking memes that fail to load or aren't actually shown
        
        # Add metadata
        selected['diversity_pool'] = pool_type if selected
        selected['pool_size'] = pool_memes.size if selected
        selected['total_unseen'] = unseen_memes.size if selected
        
        selected
      end
      
      private
      
      # Pool rotation (unchanged)
      def determine_next_pool(session_id)
        recent_pools = get_recent_pools(session_id)
        last_pool = recent_pools.last
        
        pools = [:trending, :fresh, :diverse, :random, :surprise]
        available_pools = pools - [last_pool]
        
        # Smart rotation
        if recent_pools.count(:trending) >= 2
          available_pools = [:diverse, :random, :surprise]
        elsif recent_pools.count(:fresh) >= 2
          available_pools = [:trending, :diverse]
        elsif recent_pools.count(:random) >= 3
          available_pools = [:trending, :fresh]
        end
        
        weights = {
          trending: 25,   # What's hot
          fresh: 25,      # New content
          diverse: 25,    # Maximum variety
          random: 15,     # Pure randomness
          surprise: 10    # Hidden gems
        }
        
        weighted_pool_selection(available_pools, weights)
      end
      
      def weighted_pool_selection(pools, weights)
        total_weight = pools.sum { |p| weights[p] || 0 }
        return pools.first if total_weight == 0
        
        random_value = rand * total_weight
        cumulative = 0
        
        pools.each do |pool|
          cumulative += (weights[pool] || 0)
          return pool if random_value <= cumulative
        end
        
        pools.last
      end
      
      # COMPREHENSIVE POOL RETRIEVAL - FIXED July 13, 2026
      # Tries multiple strategies in order: JSON blob → Redis Lists → attribute filtering
      def get_pool_memes(all_memes, pool_type, session_id)
        begin
          pool_name = pool_type.to_s
          
          # Strategy 1: Try JSON blob (new dual-format storage)
          json_key = "meme_pool:#{pool_name}"
          pool_json = RedisService.get(json_key)
          
          if pool_json && !pool_json.empty?
            begin
              pool_memes = JSON.parse(pool_json)
              if pool_memes.is_a?(Array) && pool_memes.any?
                AppLogger.info("✅ Retrieved #{pool_memes.size} memes from Redis JSON pool '#{json_key}'")
                return pool_memes
              end
            rescue JSON::ParserError => e
              AppLogger.warn("⚠️  JSON parse failed for '#{json_key}': #{e.message}")
            end
          end
          
          # Strategy 2: Try Redis Lists (if JSON failed)
          list_key = "meme_pool:#{pool_name}_ids"
          list_size = RedisService.llen(list_key)
          
          if list_size > 0
            meme_ids = RedisService.lrange(list_key, 0, -1)
            pool_memes = meme_ids.map do |meme_id|
              json = RedisService.hget("meme:data", meme_id)
              JSON.parse(json) if json
            end.compact
            
            if pool_memes.any?
              AppLogger.info("✅ Retrieved #{pool_memes.size} memes from Redis Lists '#{list_key}'")
              return pool_memes
            end
          end
          
          # Strategy 3: Fallback to attribute-based filtering
          AppLogger.warn("⚠️  Redis pool '#{pool_name}' empty, falling back to filtering #{all_memes.size} memes")
          case pool_type
          when :trending
            get_trending_pool_relaxed(all_memes)
          when :fresh
            get_fresh_pool_relaxed(all_memes)
          when :diverse
            get_diverse_pool(all_memes, session_id)
          when :random
            all_memes.shuffle.take(200) # Increased from 100
          when :surprise
            get_surprise_pool_relaxed(all_memes)
          else
            all_memes.shuffle.take(200)
          end
        rescue => e
          AppLogger.error("❌ Error retrieving pool '#{pool_type}': #{e.message}")
          all_memes.shuffle.take(200)
        end
      end
      
      # RELAXED TRENDING: Lower thresholds
      def get_trending_pool_relaxed(all_memes)
        all_memes.select do |meme|
          likes = meme['likes'].to_i
          upvote_ratio = meme['upvote_ratio'].to_f
          
          # VERY relaxed threshold for bootstrap: 5+ likes OR 0.6+ ratio OR recent
          likes >= 5 || upvote_ratio >= 0.6 || meme['created_at']
        end.sort_by do |meme|
          -calculate_trending_score(meme)
        end.take(150) # Top 150 (was 50)
      end
      
      def calculate_trending_score(meme)
        likes = meme['likes'].to_i
        comments = meme['comments'].to_i
        upvote_ratio = meme['upvote_ratio'].to_f || 0.5
        
        created_at = meme['created_at']
        age_hours = if created_at
          begin
            (Time.now - Time.parse(created_at.to_s)).to_i / 3600
          rescue
            72
          end
        else
          72
        end
        
        freshness = age_hours < 24 ? 2.0 : (age_hours < 48 ? 1.5 : 1.0)
        
        (likes * 1.0 + comments * 2.0) * upvote_ratio * freshness
      end
      
      # RELAXED FRESH: Last 24 hours (was 6)
      def get_fresh_pool_relaxed(all_memes)
        cutoff = Time.now - (24 * 3600) # 24 hours instead of 6
        
        fresh = all_memes.select do |meme|
          next false unless meme['created_at']
          created = begin
            Time.parse(meme['created_at'].to_s)
          rescue
            nil
          end
          created && created > cutoff
        end
        
        # If still too few, include 48h
        if fresh.size < 20
          cutoff_48h = Time.now - (48 * 3600)
          fresh = all_memes.select do |meme|
            next false unless meme['created_at']
            created = begin
              Time.parse(meme['created_at'].to_s)
            rescue
              nil
            end
            created && created > cutoff_48h
          end
        end
        
        fresh
      rescue => e
        AppLogger.warn("get_fresh_pool_relaxed failed", error: e.message)
        []
      end
      
      # NEW: Maximum diversity - different subreddits
      def get_diverse_pool(all_memes, session_id)
        recent_subs = get_recent_subreddits(session_id)
        
        # Get memes from subreddits NOT recently seen
        diverse = all_memes.select do |meme|
          subreddit = (meme['subreddit'] || '').downcase
          !recent_subs.include?(subreddit)
        end
        
        # If filtered too much, just shuffle all
        diverse.size >= 50 ? diverse : all_memes.shuffle.take(100)
      end
      
      # RELAXED SURPRISE: Lower threshold
      def get_surprise_pool_relaxed(all_memes)
        all_memes.select do |meme|
          likes = meme['likes'].to_i
          upvote_ratio = meme['upvote_ratio'].to_f || 0.5
          
          # Hidden gems: 10-100 likes, decent quality (was 50-200)
          likes.between?(10, 100) && upvote_ratio >= 0.6
        end
      end
      
      # Tracking helpers - use RedisService wrapper for safety
      def track_pool_usage(session_id, pool_type)
        key = "diversity:pools:#{session_id}"
        recent = get_recent_pools(session_id)
        recent << pool_type
        
        RedisService.set(key, recent.last(20).to_json, ttl: 3600)
      rescue => e
        AppLogger.warn("track_pool_usage failed", error: e.message)
      end
      
      def get_recent_pools(session_id)
        key = "diversity:pools:#{session_id}"
        data = RedisService.get(key, default: nil)
        data ? JSON.parse(data, symbolize_names: true) : []
      rescue => e
        []
      end
      
      def get_recent_subreddits(session_id)
        key = "recent_subreddits:#{session_id}"
        data = RedisService.get(key, default: nil)
        data ? JSON.parse(data) : []
      rescue => e
        []
      end
    end
  end
end
