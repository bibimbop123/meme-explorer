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

require 'set'

module MemeExplorer
  class SimpleMemeSelector
    # Owner-directed editorial pilot, not inferred humor/politics classification.
    # Selection-only: no provider budget changes, deletions or unseen bypass.
    HUMOR_FIRST_SOURCES = %w[memes dankmemes me_irl meirl adviceanimals
      wholesomememes starterpacks antimeme bonehurtingjuice programmerhumor
      prequelmemes lotrmemes animalsbeingderps reactiongifs highqualitygifs
      comedyheaven holup blursedimages bikinibottomtwitter historymemes
      trippinthroughtime fakehistoryporn marvelmemes animalsbeingjerks
      contagiouslaughter unexpected yesyesyesyesno nonononoyes bettereveryloop
      youseeingthisshit speedoflobsters sbubby shitposting okbuddyretard
      gamingmemes minecraftmemes crappydesign expectationvsreality
      photoshopbattles hmmm atbge redneckengineering whatcouldgowrong
      instant_regret therewasanattempt eyebleach aww rarepuppers].freeze
    COMMENTARY_SOURCES = %w[whitepeopletwitter blackpeopletwitter murderedbywords
      clevercomebacks suicidebywords kamikazebywords genz antiwork
      aboringdystopia publicfreakout actualpublicfreakouts scottishpeopletwitter
      tinder bumble dating dating_advice dating_fails niceguys nicegirls
      creepypms choosingbeggars sadcringe cringetopia justneckbeardthings
      amitheasshole tifu confession offmychest trueoffmychest outoftheloop
      explainlikeimfive nostupidquestions tooafraidtoask lifehacks lifeprotips
      youshouldknow todayilearned recruitinghell linkedinlunatics brandnewsentence
      rareinsults nottheonion].freeze

    class << self
      # Main selection method
      # @param all_memes [Array] Pool of all available memes
      # @param session_id [String] User session identifier
      # @param options [Hash] Optional configuration
      # @param user_id [Integer, nil] Logged-in user id, for personalization
      # @return [Hash] Selected meme
      #
      # ROADMAP.md Phase 1 ("Feed real per-user signal ... back into
      # MemePoolManager's tier-distributed pool selection weighting"):
      # this is the actual, live selection algorithm - the one
      # routes/random_meme.rb's real /random.json calls on every request
      # after the first page load (confirmed via grep: it's the only
      # caller in the whole app). Before this change, it had ZERO
      # per-user personalization: `weighted_sample` below only weighted
      # by global likes/views, the exact same for every user regardless
      # of what they've liked/saved before. The separate
      # `apply_user_preferences`/`get_time_based_pools`/
      # `user_subreddit_preferences` machinery
      # (lib/helpers/meme_pool_helpers.rb) that reads per-user subreddit
      # preference scores was never actually in this code path at all -
      # it's built on top of `navigate_meme_unified`
      # (lib/helpers/meme_navigation_helpers.rb), which nothing in the
      # live app calls (confirmed via grep, same way `update_user_preference`
      # was found to be uncalled). So even with `user_subreddit_preferences`
      # now actually being populated (see EngagementService.track_like/
      # track_save), that data structurally could not have influenced a
      # single real meme selection. Threading `user_id` through here -
      # not switching to the unused pool-selection path - is what
      # actually closes the loop, since this is the code real traffic runs.
      def select(all_memes, session_id, options = {})
        user_id = options[:user_id] || options['user_id']
        return all_memes.sample if all_memes.empty?
        
        # 1. Filter out previously seen memes
        all_memes = all_memes.uniq { |m| m['url'] || m[:url] || m['file'] || m[:file] || m['id'] || m[:id] }
        seen = ViewingHistoryService.get_seen_memes(session_id)
        seen_lookup = seen.to_set
        unseen = all_memes.reject do |meme|
          meme_id = meme['url'] || meme[:url] || meme['file'] || meme[:file] || meme['id'] || meme[:id]
          seen_lookup.include?(meme_id.to_s)
        end
        
        # 2. Preserve history on exhaustion. Replay the least recently selected
        # item instead of making the entire pool (including the last item) unseen.
        exhausted = unseen.empty?
        if unseen.empty?
          recency = seen.each_with_index.to_h
          oldest = all_memes.min_by do |m|
            id = m['url'] || m[:url] || m['file'] || m[:file] || m['id'] || m[:id]
            recency.fetch(id.to_s, -1)
          end
          unseen = [oldest]
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
        # Unseen-first applies while eligible URLs remain. Redis availability,
        # history expiry/eviction and visual reposts limit repeat protection;
        # engagement weighting is not evidence of humor quality.
        #
        # ROADMAP.md Phase 1: when logged in, also fold in this specific
        # user's subreddit preferences (real signal from likes/saves - see
        # EngagementService#bump_subreddit_preference) as a per-user
        # multiplier on top of the global engagement weight, rather than
        # letting every user see the identical weighting. `user_prefs`
        # is a plain lookup, not a route-context call, so it works from
        # this plain Ruby class - unlike the separate, previously-unused
        # apply_user_preferences path this replaces functionally.
        user_prefs = user_id ? subreddit_preferences_for(user_id) : {}
        selected = weighted_sample(pool, user_prefs)
        selection_method = if selected && !user_prefs.empty?
                             'personalized_weighted_random'
                           elsif selected && has_engagement_data?(pool)
                             'weighted_random'
                           else
                             'simple_random'
                           end
        selected ||= pool.sample
        
        # 5. Mark as seen (for next time)
        selected = selected.dup
        meme_id = selected['url'] || selected[:url] || selected['file'] || selected[:file] || selected['id'] || selected[:id]
        ViewingHistoryService.mark_seen(session_id, meme_id.to_s)
        
        # 6. Add metadata for debugging
        selected['selection_method'] = selection_method
        selected['pool_size'] = pool.size
        selected['total_unseen'] = unseen.size
        selected['total_unseen'] = 0 if exhausted
        selected['inventory_exhausted'] = exhausted
        
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

      # ROADMAP.md Phase 1: real per-user signal, read fresh on every
      # selection call rather than cached - preference_score changes on
      # every like/save (EngagementService#bump_subreddit_preference),
      # and this is a single indexed lookup by user_id, not the kind of
      # expensive query that needs its own caching layer on top of
      # SelectionBenchmark's own :selection stage timing. Fails safe to
      # {} (i.e. no personalization applied, identical to the previous
      # behavior) on any DB error - this must never be able to break
      # the core selection loop.
      def subreddit_preferences_for(user_id)
        return {} unless user_id && defined?(DB) && DB

        rows = DB.execute(
          "SELECT subreddit, preference_score FROM user_subreddit_preferences WHERE user_id = ?",
          [user_id]
        )
        rows.each_with_object({}) do |row, hash|
          subreddit = (row['subreddit'] || row[:subreddit]).to_s.downcase
          hash[subreddit] = (row['preference_score'] || row[:preference_score]).to_f
        end
      rescue => e
        AppLogger.warn("[SimpleMemeSelector] subreddit_preferences_for failed: #{e.message}") if defined?(AppLogger)
        {}
      end

      # Weighted random selection by engagement score (likes/views),
      # optionally scaled by this specific user's subreddit preference.
      # score = sqrt(likes * 2 + views), with a floor so untested memes
      # still have a fair (if smaller) chance of being shown — this keeps
      # discovery alive instead of only ever surfacing already-popular memes.
      #
      # ROADMAP.md Phase 1: `user_prefs` maps a downcased subreddit name
      # to its preference_score (default 1.0 for an unknown/neutral
      # subreddit, so a user with no signal for a given subreddit sees
      # the exact same weighting as before this change - this only ever
      # boosts, never penalizes, since preference_score only increases).
      def weighted_sample(pool, user_prefs = {})
        return nil if pool.empty?

        weights = pool.map do |m|
          likes = (m['likes'] || m[:likes]).to_i
          views = (m['views'] || m[:views]).to_i
          score = Math.sqrt((likes * 2 + views).to_f)
          score = [score, 0.1].max

          if user_prefs.any?
            subreddit = (m['subreddit'] || m[:subreddit]).to_s.downcase
            score *= (user_prefs[subreddit] || 1.0)
          end

          if ENV['ENABLE_HUMOR_FIRST_MIX'] == 'true'
            source = (m['subreddit'] || m[:subreddit]).to_s.downcase
            score *= 2.0 if HUMOR_FIRST_SOURCES.include?(source)
            score *= 0.15 if COMMENTARY_SOURCES.include?(source)
          end

          score
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
