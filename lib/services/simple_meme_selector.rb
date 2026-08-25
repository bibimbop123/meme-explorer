# frozen_string_literal: true

# SimpleMemeSelector - The 80/20 Solution
# 
# PURPOSE: Replace 2,500+ lines of complex selection logic with 50 clean lines
# 
# BEFORE:
# - DiversityEngineService (291 lines)
# - MemeSelectionService (456 lines)  
# - Pool rotation, weighted scoring, contextual boosts, etc.
# 
# AFTER:
# - This file (50 lines)
# - Simple, fast, effective
# 
# ALGORITHM:
# 1. Get unseen memes (via ViewingHistoryService)
# 2. Optionally boost fresh content (10% of time)
# 3. Random selection
# 4. Mark as seen
# 
# Expected Results:
# - Same or BETTER user engagement
# - Easier to debug
# - Faster performance
# - More maintainable
#
# Date: July 21, 2026
# Author: Senior Developer Audit

module MemeExplorer
  class SimpleMemeSelector
    class << self
      # Main selection method
      # @param all_memes [Array] Pool of all available memes
      # @param session_id [String] User session identifier
      # @param options [Hash] Optional configuration
      # @return [Hash] Selected meme
      def select(all_memes, session_id, options = {})
        return all_memes.sample if all_memes.empty?
        
        # 1. Filter out previously seen memes
        seen = ViewingHistoryService.get_seen_memes(session_id)
        unseen = all_memes.reject do |meme|
          meme_id = meme['url'] || meme[:url] || meme['id'] || meme[:id]
          seen.include?(meme_id.to_s)
        end
        
        # 2. Reset if everything has been seen
        if unseen.empty?
          AppLogger.info("[SimpleMemeSelector] User #{session_id} has seen all #{all_memes.size} memes - resetting history")
          ViewingHistoryService.clear_history(session_id)
          unseen = all_memes
        end
        
        # 3. Optionally boost fresh content (10% of the time)
        pool = unseen
        if options[:boost_fresh] != false && rand < 0.1
          fresh = unseen.select { |m| fresh?(m) }
          if fresh.size > 10
            pool = fresh
            AppLogger.debug("[SimpleMemeSelector] Using fresh pool: #{fresh.size} memes")
          end
        end
        
        # 4. Selection: weight towards higher-engagement memes (likes/views)
        # when we have that data, otherwise fall back to pure uniform random.
        # This surfaces content users are more likely to enjoy without
        # sacrificing variety — unseen-filtering (step 1) already guarantees
        # no repeats, and boost_fresh (step 3) still injects new content.
        selected = weighted_sample(pool)
        selection_method = selected && has_engagement_data?(pool) ? 'weighted_random' : 'simple_random'
        selected ||= pool.sample
        
        # 5. Mark as seen (for next time)
        meme_id = selected['url'] || selected[:url] || selected['id'] || selected[:id]
        ViewingHistoryService.mark_seen(session_id, meme_id.to_s)
        
        # 6. Add metadata for debugging
        selected['selection_method'] = selection_method
        selected['pool_size'] = pool.size
        selected['total_unseen'] = unseen.size
        
        AppLogger.debug("[SimpleMemeSelector] Selected meme from pool of #{pool.size} (#{unseen.size} unseen total)")
        
        selected
      end
      
      # Alias for compatibility with existing code
      def select_random_meme(memes, session_id:, preferences: {}, **_opts)
        select(memes, session_id, preferences)
      end
      
      private

      # Does this pool actually carry likes/views data worth weighting on?
      # Local placeholder memes and freshly-fetched Reddit posts often have
      # no stats yet, in which case weighting would be a no-op anyway.
      def has_engagement_data?(pool)
        pool.any? { |m| (m['likes'] || m[:likes]).to_i > 0 || (m['views'] || m[:views]).to_i > 0 }
      end

      # Weighted random selection by engagement score (likes/views).
      # score = sqrt(likes * 2 + views), with a floor so untested memes
      # still have a fair (if smaller) chance of being shown — this keeps
      # discovery alive instead of only ever surfacing already-popular memes.
      def weighted_sample(pool)
        return nil if pool.empty?

        weights = pool.map do |m|
          likes = (m['likes'] || m[:likes]).to_i
          views = (m['views'] || m[:views]).to_i
          score = Math.sqrt((likes * 2 + views).to_f)
          [score, 0.1].max
        end

        total_weight = weights.sum
        return pool.sample if total_weight <= 0

        r = rand * total_weight
        cumulative = 0
        pool.each_with_index do |meme, idx|
          cumulative += weights[idx]
          return meme if cumulative >= r
        end

        pool.last
      end
      
      # Check if meme is fresh (created in last 24 hours)
      def fresh?(meme)
        return false unless meme['created_at'] || meme[:created_at]
        
        created_str = (meme['created_at'] || meme[:created_at]).to_s
        created = Time.parse(created_str) rescue nil
        
        return false unless created
        
        created > 24.hours.ago
      end
    end
  end
end
