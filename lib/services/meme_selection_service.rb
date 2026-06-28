# frozen_string_literal: true

# MemeSelectionService - Unified Meme Selection with Strategy Pattern
#
# STATUS: Active. Migration completed Sprint 5.
#   - RandomSelectorService (861 lines)  — DELETED
#   - EnhancedRandomSelector (556 lines) — DELETED
#   - RandomSelectorServiceV2            — DELETED Sprint 3
#
# TOTAL REDUCTION: ~2,000 lines → 450 lines (78% reduction)
#
# All callsites now route through this single service. DiversityEngineService
# calls select_random_meme; routes/enhanced_random.rb calls select directly.
#
# Features:
# - Strategy pattern for different selection algorithms
# - Unified filtering and ranking logic
# - Comprehensive error handling and logging
# - Session-aware anti-repetition
# - Quality-first media validation
# - Engagement-based ranking
#
# Usage:
#   MemeSelectionService.select(pool, strategy: :intelligent, user_id: 123)
#   MemeSelectionService.select(pool, strategy: :weighted)
#   MemeSelectionService.select(pool, strategy: :diverse, session_id: 'abc')

module MemeExplorer
  class MemeSelectionService
    # Content safety filters
    EXCLUDED_CATEGORIES = %w[
      explicit_adult_content graphic_violence hate_speech harassment
      political_extremism violent_extremism self_harm illegal_activity
      lgbtq trans political_extreme incest
    ].freeze

    # Humor category weights (optimized for engagement)
    HUMOR_WEIGHTS = {
      'relationship' => 2.0,
      'dating_fail' => 1.9,
      'absurdist' => 1.7,
      'dank' => 1.6,
      'funny' => 1.5,
      'dark' => 1.4,
      'wholesome' => 1.2,
      'relatable' => 1.8,
      'cringe' => 1.6,
      'unexpected' => 1.7
    }.freeze

    # Source quality tiers
    SOURCE_QUALITY = {
      # Tier S: Best sources
      'dankmemes' => 2.0, 'me_irl' => 2.0, 'meirl' => 2.0,
      'Tinder' => 1.9, 'Bumble' => 1.9, 'ComedyHeaven' => 1.9,
      # Tier A: Excellent
      'relationship_memes' => 1.8, 'HolUp' => 1.8, '2meirl4meirl' => 1.8,
      'cursedcomments' => 1.7, 'blursedimages' => 1.7,
      # Tier B: Very good
      'memes' => 1.5, 'funny' => 1.5, 'OkBuddyRetard' => 1.6,
      'shitposting' => 1.6, 'niceguys' => 1.5, 'Nicegirls' => 1.5
    }.freeze

    # Media reliability scores
    MEDIA_DOMAIN_SCORES = {
      'i.redd.it' => 1.0,
      'i.imgur.com' => 0.95,
      'preview.redd.it' => 0.90,
      'v.redd.it' => 0.85,
      'tenor.com' => 0.80,
      'giphy.com' => 0.80,
      'imgur.com/a/' => 0.75,
      'gfycat.com' => 0.70,
      'redgifs.com' => 0.65
    }.freeze

    class << self
      # Bridge method: drop-in replacement for RandomSelectorService.select_random_meme
      # Existing callsites can migrate without changing their argument signature.
      def select_random_meme(memes, session_id: nil, preferences: {}, **_opts)
        select(memes,
               strategy:    :intelligent,
               session_id:  session_id,
               preferences: preferences)
      end

      # Main selection interface with strategy pattern
      #
      # @param pool [Array] Pool of memes to select from
      # @param strategy [Symbol] Selection strategy (:random, :weighted, :intelligent, :diverse)
      # @param session_id [String] Session ID for tracking
      # @param user_id [Integer] User ID for personalization
      # @param preferences [Hash] User preferences
      # @return [Hash, nil] Selected meme or nil
      def select(pool, strategy: :intelligent, session_id: nil, user_id: nil, preferences: {})
        return nil if pool.nil? || pool.empty?

        start_time = Time.now

        begin
          # Execute strategy-specific selection
          selected = case strategy
                    when :random
                      select_random(pool)
                    when :weighted
                      select_weighted(pool, preferences)
                    when :intelligent
                      select_intelligent(pool, session_id, user_id, preferences)
                    when :diverse
                      select_diverse(pool, session_id, user_id, preferences)
                    else
                      raise ArgumentError, "Unknown strategy: #{strategy}. " \
                                          "Valid strategies: :random, :weighted, :intelligent, :diverse"
                    end

          # Add selection metadata
          if selected
            selected['selection_metadata'] = {
              strategy: strategy,
              selection_time_ms: ((Time.now - start_time) * 1000).round(2),
              pool_size: pool.size
            }
          end

          selected

        rescue => e
          AppLogger.error("Meme selection failed",
            error: e.message,
            strategy: strategy,
            pool_size: pool&.size,
            backtrace: e.backtrace.first(3)
          )
          
          # Fallback to simple random on error
          pool.sample
        end
      end

      private

      # Strategy 1: Simple random selection
      def select_random(pool)
        pool.sample
      end

      # Strategy 2: Weighted selection by quality
      def select_weighted(pool, preferences = {})
        # Filter by safety and quality
        filtered = apply_base_filters(pool, preferences)
        return pool.sample if filtered.empty?

        # Calculate weights
        weighted_memes = filtered.map do |meme|
          score = calculate_base_score(meme)
          { meme: meme, score: score }
        end

        # Weighted random selection
        weighted_random_select(weighted_memes)
      end

      # Strategy 3: Intelligent selection (session-aware, user preferences)
      def select_intelligent(pool, session_id, user_id, preferences = {})
        # Apply comprehensive filtering
        filtered = apply_base_filters(pool, preferences)
        return pool.sample if filtered.empty?

        # Session-aware anti-repetition
        if session_id
          filtered = filter_recent_memes(filtered, session_id)
          filtered = apply_variety_filter(filtered, session_id) if filtered.size > 10
        end

        return pool.sample if filtered.empty?

        # Score with user affinity
        scored_memes = filtered.map do |meme|
          score = calculate_base_score(meme)
          score += calculate_user_affinity(meme, user_id) if user_id
          score += calculate_engagement_boost(meme)
          { meme: meme, score: score }
        end

        # Select best with some randomness (top 20%)
        top_candidates = scored_memes.sort_by { |m| -m[:score] }.first([scored_memes.size / 5, 1].max)
        selected = weighted_random_select(top_candidates)

        # Track selection for learning
        track_selection(selected, session_id, user_id) if session_id || user_id

        selected
      end

      # Strategy 4: Diverse selection (maximizes content variety)
      def select_diverse(pool, session_id, user_id, preferences = {})
        # Apply filters
        filtered = apply_base_filters(pool, preferences)
        return pool.sample if filtered.empty?

        # Get diversity pool type
        pool_type = determine_diversity_pool(session_id)
        diverse_pool = filter_by_pool_type(filtered, pool_type)

        # Fallback if pool too small
        diverse_pool = filtered if diverse_pool.size < 5

        # Score with diversity boost
        scored_memes = diverse_pool.map do |meme|
          score = calculate_base_score(meme)
          score += calculate_diversity_score(meme, session_id)
          score += calculate_user_affinity(meme, user_id) if user_id
          { meme: meme, score: score }
        end

        # Select with weighted randomness
        selected = weighted_random_select(scored_memes)

        # Track for diversity learning
        track_selection(selected, session_id, user_id, pool_type) if selected

        selected
      end

      # === FILTERING METHODS ===

      def apply_base_filters(memes, preferences = {})
        filtered = memes.dup

        # 1. Media quality filter
        filtered = filter_high_quality_media(filtered)
        return [] if filtered.empty?

        # 2. Safety filter
        filtered = filter_excluded_content(filtered, preferences)
        return [] if filtered.empty?

        # 3. Crosspost filter
        filtered = filter_crossposts(filtered)

        filtered
      end

      def filter_high_quality_media(memes)
        memes.select do |meme|
          url = meme['url'] || meme[:url]
          next false unless url

          # Check media domain reliability
          domain_score = MEDIA_DOMAIN_SCORES.find { |domain, _| url.include?(domain) }&.last || 0.5
          domain_score >= 0.7
        end
      end

      def filter_excluded_content(memes, preferences = {})
        user_excluded = preferences[:excluded_categories] || []
        all_excluded = (EXCLUDED_CATEGORIES + user_excluded).uniq

        memes.reject do |meme|
          categories = meme['categories'] || meme[:categories] || []
          categories = categories.is_a?(String) ? [categories] : categories
          (categories & all_excluded).any?
        end
      end

      def filter_crossposts(memes)
        memes.reject { |meme| meme['is_crosspost'] || meme[:is_crosspost] }
      end

      def filter_recent_memes(memes, session_id)
        return memes unless defined?(REDIS) && REDIS

        begin
          recent_urls = REDIS.lrange("session:#{session_id}:recent", 0, 49) || []
          memes.reject { |meme| recent_urls.include?(meme['url'] || meme[:url]) }
        rescue => e
          AppLogger.warn("Recent memes filter failed", error: e.message)
          memes
        end
      end

      def apply_variety_filter(memes, session_id)
        return memes unless defined?(REDIS) && REDIS

        begin
          recent_subreddits = REDIS.lrange("session:#{session_id}:subreddits", 0, 4) || []
          return memes if recent_subreddits.empty?

          # Prefer memes from different subreddits
          different = memes.reject { |m| recent_subreddits.include?(m['subreddit'] || m[:subreddit]) }
          different.empty? ? memes : different
        rescue => e
          AppLogger.warn("Variety filter failed", error: e.message)
          memes
        end
      end

      # === SCORING METHODS ===

      def calculate_base_score(meme)
        score = 1.0

        # Humor weight boost
        categories = meme['categories'] || meme[:categories] || []
        categories = categories.is_a?(String) ? [categories] : categories
        humor_boost = categories.map { |cat| HUMOR_WEIGHTS[cat] || 1.0 }.max
        score *= humor_boost

        # Source quality boost
        subreddit = meme['subreddit'] || meme[:subreddit]
        source_boost = SOURCE_QUALITY[subreddit] || 1.0
        score *= source_boost

        # Reddit score boost (normalized)
        reddit_score = (meme['score'] || meme[:score] || 0).to_i
        score *= (1.0 + Math.log10([reddit_score, 1].max) / 10.0)

        score
      end

      def calculate_user_affinity(meme, user_id)
        return 0.0 unless user_id && defined?(REDIS) && REDIS

        begin
          subreddit = meme['subreddit'] || meme[:subreddit]
          affinity = REDIS.get("user:#{user_id}:affinity:#{subreddit}").to_f
          affinity / 10.0 # Normalize 0-10 range to 0-1 boost
        rescue => e
          AppLogger.warn("User affinity calculation failed", error: e.message)
          0.0
        end
      end

      def calculate_engagement_boost(meme)
        return 0.0 unless defined?(REDIS) && REDIS

        begin
          meme_id = meme['id'] || meme[:id] || meme['url'] || meme[:url]
          engagement_rate = REDIS.get("meme:engagement:#{meme_id}").to_f
          engagement_rate / 100.0 # Normalize percentage to 0-1 boost
        rescue => e
          AppLogger.warn("Engagement boost calculation failed", error: e.message)
          0.0
        end
      end

      def calculate_diversity_score(meme, session_id)
        return 0.0 unless session_id && defined?(REDIS) && REDIS

        begin
          subreddit = meme['subreddit'] || meme[:subreddit]
          recent_count = REDIS.lrange("session:#{session_id}:subreddits", 0, -1).count(subreddit)
          # Boost memes from less-shown subreddits
          [2.0 - (recent_count * 0.5), 0.0].max
        rescue => e
          AppLogger.warn("Diversity score calculation failed", error: e.message)
          0.0
        end
      end

      # === SELECTION METHODS ===

      def weighted_random_select(weighted_memes)
        return nil if weighted_memes.empty?

        # Build cumulative weights
        total_weight = weighted_memes.sum { |wm| wm[:score] }
        return weighted_memes.first[:meme] if total_weight.zero?

        # Random selection weighted by score
        target = rand * total_weight
        cumulative = 0.0

        weighted_memes.each do |wm|
          cumulative += wm[:score]
          return wm[:meme] if cumulative >= target
        end

        # Fallback (should not reach)
        weighted_memes.last[:meme]
      end

      # === TRACKING METHODS ===

      def track_selection(meme, session_id, user_id, pool_type = nil)
        return unless meme && (session_id || user_id)
        return unless defined?(REDIS) && REDIS

        begin
          meme_url = meme['url'] || meme[:url]
          subreddit = meme['subreddit'] || meme[:subreddit]

          # Track in session
          if session_id
            REDIS.lpush("session:#{session_id}:recent", meme_url)
            REDIS.ltrim("session:#{session_id}:recent", 0, 49)
            REDIS.lpush("session:#{session_id}:subreddits", subreddit)
            REDIS.ltrim("session:#{session_id}:subreddits", 0, 9)
            REDIS.expire("session:#{session_id}:recent", 3600)
          end

          # Track user affinity
          if user_id && subreddit
            current_affinity = REDIS.get("user:#{user_id}:affinity:#{subreddit}").to_f
            REDIS.setex("user:#{user_id}:affinity:#{subreddit}", 86400 * 7, current_affinity + 0.1)
          end
        rescue => e
          AppLogger.warn("Selection tracking failed", error: e.message)
        end
      end

      # === DIVERSITY HELPERS ===

      def determine_diversity_pool(session_id)
        return :general unless session_id && defined?(REDIS) && REDIS

        begin
          sequence = REDIS.get("session:#{session_id}:pool_sequence").to_i
          pools = [:trending, :fresh, :deep_cuts, :surprise]
          pools[sequence % pools.size]
        rescue
          :general
        end
      end

      def filter_by_pool_type(memes, pool_type)
        case pool_type
        when :trending
          memes.sort_by { |m| -(m['score'] || m[:score] || 0).to_i }.first(20)
        when :fresh
          memes.sort_by { |m| -(m['created_utc'] || m[:created_utc] || 0).to_i }.first(20)
        when :deep_cuts
          memes.sort_by { |m| (m['score'] || m[:score] || 0).to_i }.first(20)
        when :surprise
          memes.sample(20)
        else
          memes
        end
      end
    end
  end
end
