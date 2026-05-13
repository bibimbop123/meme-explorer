# Enhanced Random Selector - iFunny-Inspired + Our Diversity Strengths
# 
# HYBRID APPROACH:
# 1. iFunny's Best: Engagement rates, user profiles, collaborative filtering
# 2. Our Strength: Diversity pools, cold start handling, serendipity
# 3. Improvements: Better ranking, content similarity, adaptive learning
#
# KEY INNOVATIONS OVER IFUNNY:
# - Solves their diversity/filter bubble problem
# - Solves their cold start problem
# - Adds serendipity and surprise mechanics
# - Simpler to implement (no ML models required)

require_relative './random_selector_service'
require_relative './diversity_engine_service'

module MemeExplorer
  class EnhancedRandomSelector
    class << self
      
      # Main entry point - combines all improvements
      def select_meme(all_memes, session_id:, user_id: nil, preferences: {})
        return all_memes.sample if all_memes.empty?
        
        start_time = Time.now
        
        # LAYER 1: DIVERSITY ENGINE (Our strength - solves iFunny's filter bubble)
        pool_type = DiversityEngineService.send(:determine_next_pool, session_id)
        pool_memes = DiversityEngineService.send(:get_pool_memes, all_memes, pool_type, session_id)
        
        # Fallback if pool too small
        if pool_memes.size < 10
          pool_memes = (pool_memes + all_memes.sample(20)).uniq
        end
        
        # LAYER 2: ENHANCED RANKING (iFunny-inspired improvements)
        ranked_memes = rank_with_all_signals(pool_memes, session_id, user_id)
        
        # LAYER 3: INTELLIGENT SELECTION (Hybrid approach)
        selected = smart_selection(ranked_memes, session_id, user_id)
        
        # Track everything for learning
        track_selection(selected, session_id, user_id, pool_type) if selected
        
        # Add metadata
        if selected
          selected['selection_metadata'] = {
            pool_type: pool_type,
            rank_score: ranked_memes.find { |r| r[:meme] == selected }&.dig(:score),
            engagement_rate: calculate_engagement_rate(selected),
            user_affinity: user_id ? calculate_user_affinity(selected, user_id) : nil,
            selection_time_ms: ((Time.now - start_time) * 1000).round(2)
          }
        end
        
        selected
      end
      
      private
      
      # IFUNNY FEATURE #1: Engagement Rate Tracking (their "smile_rate")
      # This is what makes their algorithm so good
      def calculate_engagement_rate(meme)
        meme_id = meme['id'] || meme['url']
        return 0 unless meme_id && defined?(REDIS) && REDIS
        
        # Get stats from Redis
        views = REDIS.get("meme:views:#{meme_id}").to_i
        likes = REDIS.get("meme:likes:#{meme_id}").to_i
        
        return 0 if views.zero?
        
        # iFunny's formula: likes / views * 100
        engagement_rate = (likes.to_f / views * 100).round(2)
        
        # Cache for performance
        REDIS.setex("meme:engagement:#{meme_id}", 300, engagement_rate.to_s)
        
        engagement_rate
      rescue
        # Fallback to Reddit score
        likes = meme['likes'].to_i
        return 0 if likes.zero?
        
        # Estimate: assume 10x views per like (industry standard)
        estimated_rate = (1.0 / 10 * 100).round(2)
        estimated_rate
      end
      
      # IFUNNY FEATURE #2: User Profile Building
      # Track what each user actually engages with
      def get_user_profile(user_id)
        return nil unless user_id && defined?(REDIS) && REDIS
        
        key = "user:profile:#{user_id}"
        cached = REDIS.get(key)
        return JSON.parse(cached, symbolize_names: true) if cached
        
        # Build profile from interaction history
        profile = build_user_profile(user_id)
        REDIS.setex(key, 3600, profile.to_json)
        
        profile
      rescue
        nil
      end
      
      def build_user_profile(user_id)
        return {} unless defined?(REDIS) && REDIS
        
        # Get user's interaction history
        likes_key = "user:likes:#{user_id}"
        views_key = "user:views:#{user_id}"
        
        liked_memes = REDIS.smembers(likes_key) rescue []
        viewed_memes = REDIS.lrange(views_key, 0, -1) rescue []
        
        # Analyze preferences
        {
          total_views: viewed_memes.size,
          total_likes: liked_memes.size,
          engagement_rate: viewed_memes.empty? ? 0 : (liked_memes.size.to_f / viewed_memes.size * 100).round(2),
          preferred_subreddits: extract_preferred_subreddits(liked_memes),
          preferred_humor_types: extract_preferred_humor_types(liked_memes),
          avg_session_length: calculate_avg_session_length(user_id),
          last_active: Time.now.to_i
        }
      end
      
      # IFUNNY FEATURE #3: Collaborative Filtering
      # "Users who liked X also liked Y"
      def get_collaborative_recommendations(user_id, limit: 20)
        return [] unless user_id && defined?(REDIS) && REDIS
        
        # Get user's liked memes
        user_likes_key = "user:likes:#{user_id}"
        user_likes = REDIS.smembers(user_likes_key) rescue []
        return [] if user_likes.empty?
        
        # Find users with similar tastes (who liked same memes)
        similar_users = find_similar_users(user_id, user_likes)
        return [] if similar_users.empty?
        
        # Get memes they liked that this user hasn't seen
        recommended_memes = []
        similar_users.each do |similar_user_id|
          their_likes_key = "user:likes:#{similar_user_id}"
          their_likes = REDIS.smembers(their_likes_key) rescue []
          
          # Find new memes
          new_memes = their_likes - user_likes
          recommended_memes.concat(new_memes)
        end
        
        # Score by frequency (how many similar users liked it)
        meme_scores = Hash.new(0)
        recommended_memes.each { |meme_id| meme_scores[meme_id] += 1 }
        
        # Return top recommendations
        meme_scores.sort_by { |_, score| -score }.take(limit).map(&:first)
      rescue
        []
      end
      
      def find_similar_users(user_id, user_likes, limit: 10)
        return [] unless defined?(REDIS) && REDIS
        
        # Simple approach: Find users who liked the same memes
        similar = Hash.new(0)
        
        user_likes.take(20).each do |meme_id|
          # Get all users who liked this meme
          likers_key = "meme:likers:#{meme_id}"
          likers = REDIS.smembers(likers_key) rescue []
          
          likers.each do |liker_id|
            next if liker_id == user_id.to_s
            similar[liker_id] += 1  # Count overlapping likes
          end
        end
        
        # Return users with most overlap
        similar.sort_by { |_, overlap| -overlap }.take(limit).map(&:first)
      rescue
        []
      end
      
      # IMPROVEMENT #1: Enhanced Ranking with ALL Signals
      # Combines iFunny's features + our features
      def rank_with_all_signals(memes, session_id, user_id)
        user_profile = user_id ? get_user_profile(user_id) : nil
        collab_recommendations = user_id ? get_collaborative_recommendations(user_id) : []
        
        memes.map do |meme|
          {
            meme: meme,
            score: calculate_comprehensive_score(meme, session_id, user_id, user_profile, collab_recommendations)
          }
        end.sort_by { |r| -r[:score] }
      end
      
      def calculate_comprehensive_score(meme, session_id, user_id, user_profile, collab_recs)
        meme_id = meme['id'] || meme['url']
        
        # BASE SCORE: Reddit engagement
        likes = meme['likes'].to_i
        comments = meme['comments'].to_i
        upvote_ratio = meme['upvote_ratio'].to_f || 0.5
        base_score = 1.0 + (likes * 0.01) + (comments * 0.008) + (upvote_ratio * 0.3)
        
        # IFUNNY SIGNAL #1: Engagement Rate (their "smile_rate")
        # This is their secret sauce - shows actual user enjoyment
        engagement_rate = calculate_engagement_rate(meme)
        engagement_multiplier = 1.0 + (engagement_rate / 100.0)  # 0% = 1.0x, 50% = 1.5x, 100% = 2.0x
        
        # IFUNNY SIGNAL #2: User Preference Match
        user_match_multiplier = 1.0
        if user_profile && !user_profile.empty?
          user_match_multiplier = calculate_user_preference_match(meme, user_profile)
        end
        
        # IFUNNY SIGNAL #3: Collaborative Filtering Boost
        collab_boost = 1.0
        if collab_recs.include?(meme_id)
          # Higher rank = bigger boost
          rank = collab_recs.index(meme_id)
          collab_boost = 1.5 + (0.5 * (20 - rank) / 20.0)  # 1.5x - 2.0x based on rank
        end
        
        # OUR SIGNALS: Keep what makes us better than iFunny
        humor_score = RandomSelectorService.send(:calculate_humor_score, meme)
        source_quality = RandomSelectorService.send(:SOURCE_QUALITY)[(meme['subreddit'] || '').downcase] || 1.0
        media_quality = RandomSelectorService.send(:calculate_media_quality_score, meme)
        freshness = RandomSelectorService.send(:calculate_freshness_multiplier, meme)
        variety_bonus = session_id ? RandomSelectorService.send(:calculate_variety_bonus, meme, session_id) : 1.0
        
        # IMPROVEMENT #2: Content Similarity Penalty
        # Prevent showing too-similar content (iFunny doesn't do this well)
        similarity_penalty = calculate_content_similarity_penalty(meme, session_id)
        
        # IMPROVEMENT #3: Discovery Bonus
        # Reward showing users content outside their bubble (iFunny's weakness)
        discovery_bonus = calculate_discovery_bonus(meme, user_profile)
        
        # COMBINED SCORE
        final_score = base_score *
                     engagement_multiplier *    # iFunny feature
                     user_match_multiplier *    # iFunny feature  
                     collab_boost *             # iFunny feature
                     humor_score *              # Our feature
                     source_quality *           # Our feature
                     media_quality *            # Our feature
                     freshness *                # Our feature
                     variety_bonus *            # Our feature
                     similarity_penalty *       # Our improvement
                     discovery_bonus            # Our improvement
        
        final_score
      end
      
      # Calculate how well meme matches user's known preferences
      def calculate_user_preference_match(meme, user_profile)
        return 1.0 unless user_profile
        
        score = 1.0
        
        # Subreddit preference
        if user_profile[:preferred_subreddits]
          subreddit = (meme['subreddit'] || '').downcase
          if user_profile[:preferred_subreddits].include?(subreddit)
            score *= 1.4  # 40% boost for preferred subreddit
          end
        end
        
        # Humor type preference
        if user_profile[:preferred_humor_types]
          humor_type = RandomSelectorService.send(:detect_primary_humor_type, meme)
          if user_profile[:preferred_humor_types].include?(humor_type)
            score *= 1.3  # 30% boost for preferred humor
          end
        end
        
        # Engagement rate preference (some users like only viral content)
        if user_profile[:engagement_rate] && user_profile[:engagement_rate] > 50
          # Power user - show high-engagement content
          meme_engagement = calculate_engagement_rate(meme)
          if meme_engagement > 30
            score *= 1.2
          end
        end
        
        score
      end
      
      # IMPROVEMENT OVER IFUNNY: Content similarity detection
      # Prevents showing duplicate or near-duplicate content
      def calculate_content_similarity_penalty(meme, session_id)
        return 1.0 unless session_id
        
        recent_titles = RandomSelectorService.send(:fetch_recent_titles, session_id)
        return 1.0 if recent_titles.empty?
        
        current_title = (meme['title'] || '').downcase
        
        # Check similarity with recent titles
        similarities = recent_titles.last(10).map do |recent_title|
          title_similarity_score(current_title, recent_title)
        end
        
        max_similarity = similarities.max || 0
        
        # Heavy penalty for very similar content
        case max_similarity
        when 0.8..1.0 then 0.3   # 70% penalty - almost identical
        when 0.6..0.8 then 0.6   # 40% penalty - very similar
        when 0.4..0.6 then 0.8   # 20% penalty - somewhat similar
        else 1.0                  # No penalty
        end
      end
      
      def title_similarity_score(title1, title2)
        return 0.0 if title1.nil? || title2.nil? || title1.length < 10 || title2.length < 10
        
        words1 = tokenize_title(title1)
        words2 = tokenize_title(title2)
        
        return 0.0 if words1.empty? || words2.empty?
        
        # Jaccard similarity
        intersection = (words1 & words2).size
        union = (words1 | words2).size
        
        intersection.to_f / union
      end
      
      def tokenize_title(title)
        # Remove common words and split
        stopwords = %w[the a an and or but in on at to for of with by]
        title.downcase.split(/\W+/).reject { |w| w.length < 3 || stopwords.include?(w) }
      end
      
      # IMPROVEMENT OVER IFUNNY: Discovery bonus
      # Rewards showing content outside user's filter bubble
      def calculate_discovery_bonus(meme, user_profile)
        return 1.0 unless user_profile && user_profile[:preferred_subreddits]
        
        subreddit = (meme['subreddit'] || '').downcase
        
        # If from a subreddit user hasn't engaged with much, small bonus
        unless user_profile[:preferred_subreddits].include?(subreddit)
          return 1.15  # 15% discovery bonus
        end
        
        1.0
      end
      
      # IMPROVEMENT #4: Smart selection with multiple strategies
      def smart_selection(ranked_memes, session_id, user_id)
        return ranked_memes.first[:meme] if ranked_memes.size <= 3
        
        # Determine selection strategy
        strategy = determine_selection_strategy(session_id, user_id)
        
        case strategy
        when :exploit
          # Pick from top 5 (exploit known preferences)
          top_5 = ranked_memes.take(5)
          weighted_random_selection(top_5)
        when :explore
          # Pick from top 20 with more randomness (explore new content)
          top_20 = ranked_memes.take(20)
          top_20[rand(top_20.size)][:meme]
        when :discovery
          # Deliberately pick from middle of the pack (discovery mode)
          middle_section = ranked_memes[10..30] || ranked_memes
          middle_section.sample[:meme]
        when :surprise
          # Random surprise from any ranked meme
          ranked_memes.sample[:meme]
        else
          # Default: Top pick
          ranked_memes.first[:meme]
        end
      end
      
      # Epsilon-greedy strategy with adaptive exploration
      def determine_selection_strategy(session_id, user_id)
        # New users: Explore more to learn preferences
        if user_id
          user_profile = get_user_profile(user_id)
          if user_profile && user_profile[:total_views].to_i < 50
            # New user - 40% explore, 40% exploit, 10% discovery, 10% surprise
            rand_val = rand
            return :explore if rand_val < 0.4
            return :exploit if rand_val < 0.8
            return :discovery if rand_val < 0.9
            return :surprise
          end
        end
        
        # Regular users: Mostly exploit with occasional exploration
        # 60% exploit, 20% explore, 15% discovery, 5% surprise
        rand_val = rand
        return :exploit if rand_val < 0.6
        return :explore if rand_val < 0.8
        return :discovery if rand_val < 0.95
        :surprise
      end
      
      def weighted_random_selection(ranked_memes)
        total_score = ranked_memes.sum { |r| r[:score] }
        random_val = rand * total_score
        cumulative = 0
        
        ranked_memes.each do |ranked|
          cumulative += ranked[:score]
          return ranked[:meme] if random_val <= cumulative
        end
        
        ranked_memes.last[:meme]
      end
      
      # TRACKING: Learn from every interaction
      def track_selection(meme, session_id, user_id, pool_type)
        meme_id = meme['id'] || meme['url']
        return unless meme_id && defined?(REDIS) && REDIS
        
        timestamp = Time.now.to_i
        
        begin
          REDIS.pipelined do |pipe|
            # Track view for engagement rate calculation
            pipe.incr("meme:views:#{meme_id}")
            
            # Track user view
            if user_id
              pipe.lpush("user:views:#{user_id}", meme_id)
              pipe.ltrim("user:views:#{user_id}", 0, 999)  # Keep last 1000
            end
            
            # Track pool effectiveness
            pipe.hincrby("pool:selections", pool_type.to_s, 1)
            
            # Track for session-based filtering (existing system)
            RandomSelectorService.send(:track_selection, meme, session_id) if session_id
            
            # Track selection timestamp for time-based analysis
            pipe.zadd("meme:view_times:#{meme_id}", timestamp, "#{session_id}:#{timestamp}")
            pipe.zremrangebyrank("meme:view_times:#{meme_id}", 0, -1001)  # Keep last 1000
          end
        rescue => e
          puts "⚠️ Tracking error: #{e.message}"
        end
      end
      
      # Track user interactions (likes, shares, etc.) - called from frontend
      def track_interaction(meme_id, user_id: nil, session_id: nil, interaction_type: 'like')
        return unless meme_id && defined?(REDIS) && REDIS
        
        begin
          REDIS.pipelined do |pipe|
            case interaction_type
            when 'like'
              pipe.incr("meme:likes:#{meme_id}")
              
              if user_id
                pipe.sadd("user:likes:#{user_id}", meme_id)
                pipe.sadd("meme:likers:#{meme_id}", user_id)
                
                # Invalidate user profile cache
                pipe.del("user:profile:#{user_id}")
              end
              
            when 'share'
              pipe.incr("meme:shares:#{meme_id}")
              
            when 'skip'
              # Track skips for negative signal
              pipe.incr("meme:skips:#{meme_id}")
            end
            
            # Update engagement rate cache
            pipe.del("meme:engagement:#{meme_id}")
          end
        rescue => e
          puts "⚠️ Interaction tracking error: #{e.message}"
        end
      end
      
      # Helper methods for user profile building
      def extract_preferred_subreddits(liked_memes)
        return [] if liked_memes.empty? || !defined?(REDIS) || !REDIS
        
        subreddit_counts = Hash.new(0)
        
        liked_memes.take(100).each do |meme_id|
          # Try to get subreddit from meme metadata
          subreddit = REDIS.hget("meme:meta:#{meme_id}", 'subreddit') rescue nil
          subreddit_counts[subreddit] += 1 if subreddit
        end
        
        # Return top 5 subreddits
        subreddit_counts.sort_by { |_, count| -count }.take(5).map(&:first)
      rescue
        []
      end
      
      def extract_preferred_humor_types(liked_memes)
        return [] if liked_memes.empty? || !defined?(REDIS) || !REDIS
        
        humor_counts = Hash.new(0)
        
        liked_memes.take(100).each do |meme_id|
          humor_type = REDIS.hget("meme:meta:#{meme_id}", 'humor_type') rescue nil
          humor_counts[humor_type] += 1 if humor_type
        end
        
        humor_counts.sort_by { |_, count| -count }.take(5).map(&:first)
      rescue
        []
      end
      
      def calculate_avg_session_length(user_id)
        return 0 unless user_id && defined?(REDIS) && REDIS
        
        # Get recent session data
        sessions_key = "user:sessions:#{user_id}"
        sessions = REDIS.lrange(sessions_key, 0, 29) rescue []  # Last 30 sessions
        
        return 0 if sessions.empty?
        
        total_length = sessions.sum { |s| JSON.parse(s)['length'].to_i rescue 0 }
        (total_length.to_f / sessions.size).round
      rescue
        0
      end
      
      # Store meme metadata for profile building
      def store_meme_metadata(meme)
        meme_id = meme['id'] || meme['url']
        return unless meme_id && defined?(REDIS) && REDIS
        
        begin
          REDIS.pipelined do |pipe|
            pipe.hset("meme:meta:#{meme_id}", 'subreddit', meme['subreddit'].to_s.downcase)
            pipe.hset("meme:meta:#{meme_id}", 'humor_type', RandomSelectorService.send(:detect_primary_humor_type, meme))
            pipe.hset("meme:meta:#{meme_id}", 'likes', meme['likes'].to_i.to_s)
            pipe.expire("meme:meta:#{meme_id}", 86400 * 7)  # 7 days
          end
        rescue => e
          # Non-critical
        end
      end
    end
  end
end
