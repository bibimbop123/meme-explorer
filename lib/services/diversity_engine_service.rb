# Diversity Engine - Eliminates Repetitiveness Through Multi-Pool Strategy
# Senior Dev Approach: Users get bored from sameness, not randomness
# Solution: Multiple content pools with intelligent rotation

module MemeExplorer
  class DiversityEngineService
    class << self
      # CORE INNOVATION: Rotate through diverse content pools to prevent monotony
      def select_diverse_meme(all_memes, session_id:, preferences: {})
        return all_memes.sample if all_memes.empty?
        
        # Initialize session state
        init_session_state(session_id)
        
        # Determine which pool to use based on session pattern
        pool_type = determine_next_pool(session_id)
        
        # Get memes from that pool
        pool_memes = get_pool_memes(all_memes, pool_type, session_id)
        
        # If pool is too small, blend with random pool
        if pool_memes.size < 10
          random_pool = all_memes.sample([all_memes.size / 3, 20].min)
          pool_memes = (pool_memes + random_pool).uniq
        end
        
        # Use RandomSelectorService for intelligent selection from pool
        selected = RandomSelectorService.select_random_meme(
          pool_memes, 
          session_id: session_id, 
          preferences: preferences
        )
        
        # Track pool usage for rotation
        track_pool_usage(session_id, pool_type)
        
        # Add diversity metadata
        selected['diversity_pool'] = pool_type if selected
        selected['diversity_score'] = calculate_diversity_score(selected, session_id) if selected
        
        selected
      end
      
      private
      
      def init_session_state(session_id)
        return unless defined?(REDIS) && REDIS
        
        # Initialize pool history if doesn't exist
        key = "diversity:pools:#{session_id}"
        unless REDIS.exists(key)
          REDIS.setex(key, 3600, [].to_json)
        end
      end
      
      # INTELLIGENT POOL ROTATION: Never use same pool twice in a row
      def determine_next_pool(session_id)
        recent_pools = get_recent_pools(session_id)
        last_pool = recent_pools.last
        
        # Pool rotation rules
        pools = [:trending, :fresh, :vintage, :random, :serendipity]
        
        # Remove last used pool to force variety
        available_pools = pools - [last_pool]
        
        # Smart selection based on session patterns
        if recent_pools.count(:trending) >= 2
          # Too much trending, need variety
          available_pools = [:vintage, :random, :serendipity]
        elsif recent_pools.count(:fresh) >= 2
          # Too much fresh, show some classics
          available_pools = [:trending, :vintage]
        elsif recent_pools.count(:random) >= 3
          # Too random, show curated content
          available_pools = [:trending, :fresh]
        end
        
        # Weighted random selection from available pools
        weights = {
          trending: 30,    # 30% - What's hot now
          fresh: 25,       # 25% - Brand new content
          vintage: 15,     # 15% - Classics/throwbacks
          random: 20,      # 20% - Surprise variety
          serendipity: 10  # 10% - Completely unexpected
        }
        
        selected = weighted_pool_selection(available_pools, weights)
        selected
      end
      
      def weighted_pool_selection(pools, weights)
        total_weight = pools.sum { |p| weights[p] || 0 }
        random_value = rand * total_weight
        cumulative = 0
        
        pools.each do |pool|
          cumulative += (weights[pool] || 0)
          return pool if random_value <= cumulative
        end
        
        pools.last
      end
      
      # POOL DEFINITIONS: Each pool has distinct characteristics
      def get_pool_memes(all_memes, pool_type, session_id)
        case pool_type
        when :trending
          get_trending_pool(all_memes, session_id)
        when :fresh
          get_fresh_pool(all_memes, session_id)
        when :vintage
          get_vintage_pool(all_memes, session_id)
        when :random
          get_random_pool(all_memes, session_id)
        when :serendipity
          get_serendipity_pool(all_memes, session_id)
        else
          all_memes
        end
      end
      
      # TRENDING: High engagement, recent, popular
      def get_trending_pool(all_memes, session_id)
        all_memes.select do |meme|
          likes = meme['likes'].to_i
          upvote_ratio = meme['upvote_ratio'].to_f
          
          # Must have decent engagement
          likes >= 100 && upvote_ratio >= 0.7
        end.sort_by do |meme|
          # Sort by trending score
          -calculate_trending_score(meme)
        end.take(50) # Top 50 trending
      end
      
      def calculate_trending_score(meme)
        likes = meme['likes'].to_i
        comments = meme['comments'].to_i
        upvote_ratio = meme['upvote_ratio'].to_f || 0.5
        
        # Recency boost
        created_at = meme['created_at']
        age_hours = if created_at
          (Time.now - Time.parse(created_at.to_s)).to_i / 3600
        else
          72
        end
        
        freshness = age_hours < 24 ? 2.0 : (age_hours < 48 ? 1.5 : 1.0)
        
        (likes * 1.0 + comments * 2.0) * upvote_ratio * freshness
      end
      
      # FRESH: Brand new content (last 6 hours)
      def get_fresh_pool(all_memes, session_id)
        cutoff = Time.now - (6 * 3600)
        
        all_memes.select do |meme|
          next false unless meme['created_at']
          created = Time.parse(meme['created_at'].to_s) rescue nil
          created && created > cutoff
        end
      rescue
        [] # If parsing fails, return empty
      end
      
      # VINTAGE: Classic memes from 30+ days ago
      def get_vintage_pool(all_memes, session_id)
        cutoff = Time.now - (30 * 24 * 3600)
        
        all_memes.select do |meme|
          next false unless meme['created_at']
          created = Time.parse(meme['created_at'].to_s) rescue nil
          created && created < cutoff && meme['likes'].to_i >= 500
        end
      rescue
        []
      end
      
      # RANDOM: Pure variety - different subreddits
      def get_random_pool(all_memes, session_id)
        # Get subreddits user hasn't seen recently
        recent_subreddits = get_recent_subreddits(session_id)
        
        all_memes.select do |meme|
          subreddit = (meme['subreddit'] || '').downcase
          !recent_subreddits.include?(subreddit)
        end
      end
      
      # SERENDIPITY: Completely unexpected - low engagement gems
      def get_serendipity_pool(all_memes, session_id)
        # Find hidden gems: low likes but good quality
        all_memes.select do |meme|
          likes = meme['likes'].to_i
          upvote_ratio = meme['upvote_ratio'].to_f || 0.5
          
          # Hidden gems: 50-200 likes, high quality
          likes.between?(50, 200) && upvote_ratio >= 0.75
        end
      end
      
      # TRACKING: Remember pools used
      def track_pool_usage(session_id, pool_type)
        return unless defined?(REDIS) && REDIS
        
        key = "diversity:pools:#{session_id}"
        recent = get_recent_pools(session_id)
        recent << pool_type
        
        REDIS.setex(key, 3600, recent.last(20).to_json)
      rescue
        nil
      end
      
      def get_recent_pools(session_id)
        return [] unless defined?(REDIS) && REDIS
        
        key = "diversity:pools:#{session_id}"
        data = REDIS.get(key)
        data ? JSON.parse(data, symbolize_names: true) : []
      rescue
        []
      end
      
      def get_recent_subreddits(session_id)
        return [] unless defined?(REDIS) && REDIS
        
        key = "recent_subreddits:#{session_id}"
        data = REDIS.get(key)
        data ? JSON.parse(data) : []
      rescue
        []
      end
      
      # DIVERSITY SCORE: How different this meme is from recent history
      def calculate_diversity_score(meme, session_id)
        score = 0.0
        
        # Different subreddit = +1.0
        recent_subs = get_recent_subreddits(session_id)
        current_sub = (meme['subreddit'] || '').downcase
        score += 1.0 unless recent_subs.include?(current_sub)
        
        # Different humor type = +0.5
        # (use RandomSelectorService's humor detection)
        
        # Different age category = +0.5
        age_hours = if meme['created_at']
          (Time.now - Time.parse(meme['created_at'].to_s)).to_i / 3600
        else
          72
        end
        
        age_category = case age_hours
        when 0..6 then 'ultra_fresh'
        when 6..24 then 'fresh'
        when 24..72 then 'recent'
        when 72..720 then 'classic'
        else 'vintage'
        end
        
        # Track and compare
        recent_ages = get_recent_age_categories(session_id)
        score += 0.5 unless recent_ages.last(3).include?(age_category)
        
        # Track age category
        track_age_category(session_id, age_category)
        
        score
      end
      
      def get_recent_age_categories(session_id)
        return [] unless defined?(REDIS) && REDIS
        
        key = "diversity:ages:#{session_id}"
        data = REDIS.get(key)
        data ? JSON.parse(data) : []
      rescue
        []
      end
      
      def track_age_category(session_id, category)
        return unless defined?(REDIS) && REDIS
        
        key = "diversity:ages:#{session_id}"
        recent = get_recent_age_categories(session_id)
        recent << category
        
        REDIS.setex(key, 3600, recent.last(20).to_json)
      rescue
        nil
      end
    end
  end
end
