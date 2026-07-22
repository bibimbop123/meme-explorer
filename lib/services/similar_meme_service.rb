# frozen_string_literal: true

# lib/services/similar_meme_service.rb
# Service for finding similar memes based on subreddit, tags, and user preferences
# Implements intelligent selection with diversity and quality scoring

class SimilarMemeService
  class << self
    # Find similar memes based on source meme characteristics
    # @param source_meme [Hash] The meme to find similar content for
    # @param meme_pool [Array<Hash>] Available memes to select from
    # @param session_id [String] User session identifier
    # @param options [Hash] Additional options
    # @return [Hash, nil] Selected similar meme or nil
    def find_similar(source_meme, meme_pool, session_id:, options: {})
      return nil if source_meme.nil? || meme_pool.empty?

      subreddit = normalize_subreddit(source_meme['subreddit'])
      return nil if subreddit.nil?

      # Filter candidates by subreddit
      candidates = filter_by_subreddit(meme_pool, subreddit)
      
      # If too few candidates, expand to related subreddits
      if candidates.size < 5
        candidates = expand_to_related_subreddits(meme_pool, subreddit)

        return nil if candidates.empty?

        # Exclude recently shown memes
        candidates = exclude_recent_memes(candidates, session_id)
        
        # If we filtered everything out, use original candidates
        candidates = filter_by_subreddit(meme_pool, subreddit) if candidates.empty?

        # Score and rank candidates
        scored_candidates = score_candidates(
          candidates,
          source_meme: source_meme,
          session_id: session_id
        )

        # Select best candidate with some randomness to avoid predictability
        select_with_weighted_randomness(scored_candidates)
      end

      # Track that user requested similar content
      # @param subreddit [String] Subreddit being explored
      # @param session_id [String] User session identifier
      def track_similar_request(subreddit, session_id)
        return unless defined?(REDIS) && REDIS

        subreddit = normalize_subreddit(subreddit)
        return if subreddit.nil?

        key = "similar_requests:#{session_id}"
        timestamp = Time.now.to_i

        begin
          # Store request with timestamp
          REDIS.zadd(key, timestamp, subreddit)
          
          # Keep only last 50 requests
          REDIS.zremrangebyrank(key, 0, -51)
          
          # Expire after 24 hours
          REDIS.expire(key, 86400)

          # Track subreddit preference score
          pref_key = "subreddit_preference:#{session_id}:#{subreddit}"
          REDIS.incr(pref_key)
          REDIS.expire(pref_key, 604800) # 7 days
        rescue => e
          AppLogger.error("⚠️  [SimilarMemeService] Redis tracking error: #{e.message}")
        end
      end

      # Get user's subreddit preferences based on history
      # @param session_id [String] User session identifier
      # @return [Hash<String, Integer>] Subreddit preferences with scores
      def get_user_preferences(session_id)
        return {} unless defined?(REDIS) && REDIS

        begin
          key = "similar_requests:#{session_id}"
          recent_requests = REDIS.zrange(key, 0, -1)
          
          # Count frequency
          preferences = Hash.new(0)
          recent_requests.each { |subreddit| preferences[subreddit] += 1 }
          
          preferences
        rescue => e
          AppLogger.error("⚠️  [SimilarMemeService] Error fetching preferences: #{e.message}")
          {}
        end
      end

      private

      # Normalize subreddit name
      def normalize_subreddit(subreddit)
        return nil if subreddit.nil? || subreddit.to_s.strip.empty?
        subreddit.to_s.strip.downcase
      end

      # Filter memes by exact subreddit match
      def filter_by_subreddit(memes, subreddit)
        memes.select do |meme|
          normalize_subreddit(meme['subreddit']) == subreddit
        end
      end

      # Expand search to related subreddits if needed
      def expand_to_related_subreddits(memes, subreddit)
        related = SUBREDDIT_RELATIONSHIPS[subreddit] || []
        all_subreddits = [subreddit] + related

        memes.select do |meme|
          all_subreddits.include?(normalize_subreddit(meme['subreddit']))
        end
      end

      # Exclude memes shown in recent history
      def exclude_recent_memes(candidates, session_id)
        return candidates unless defined?(REDIS) && REDIS

        begin
          recent_key = "recent_memes:#{session_id}"
          recent_urls = REDIS.lrange(recent_key, 0, -1).to_set

          candidates.reject do |meme|
            url = meme['url'] || meme['file']
            recent_urls.include?(url)
          end
        rescue => e
          AppLogger.error("⚠️  [SimilarMemeService] Error filtering recent: #{e.message}")
          candidates
        end
      end

      # Score candidates based on quality and relevance
      def score_candidates(candidates, source_meme:, session_id:)
        user_prefs = get_user_preferences(session_id)

        candidates.map do |meme|
          score = calculate_meme_score(meme, source_meme, user_prefs)
          { meme: meme, score: score }
        end.sort_by { |c| -c[:score] }
      end

      # Calculate quality score for a meme
      def calculate_meme_score(meme, source_meme, user_prefs)
        score = 100.0 # Base score

        # Exact subreddit match bonus
        if normalize_subreddit(meme['subreddit']) == normalize_subreddit(source_meme['subreddit'])
          score += 50
        end

        # User preference bonus
        subreddit = normalize_subreddit(meme['subreddit'])
        if user_prefs[subreddit]
          score += user_prefs[subreddit] * 10
        end

        # Gallery posts bonus (more content)
        score += 25 if meme['is_gallery'] && meme['gallery_images']&.size&.>(1)

        # Recency bonus for API memes
        if meme['created_utc']
          age_days = (Time.now.to_i - meme['created_utc'].to_i) / 86400.0
          score += [30 - age_days, 0].max # Newer is better, up to 30 points
        end

        # Engagement score bonus
        if meme['score']
          score += Math.log10([meme['score'], 1].max) * 5
        end

        score
      end

      # Select candidate with weighted randomness (not always the top)
      def select_with_weighted_randomness(scored_candidates)
        return nil if scored_candidates.empty?

        # Top 5 candidates get consideration
        top_candidates = scored_candidates.first(5)

        # Weight by score (exponential for more differentiation)
        total_weight = top_candidates.sum { |c| Math.exp(c[:score] / 50.0) }
        random_point = rand * total_weight

        cumulative = 0.0
        top_candidates.each do |candidate|
          cumulative += Math.exp(candidate[:score] / 50.0)
          return candidate[:meme] if cumulative >= random_point
        end

        # Fallback to top candidate
        top_candidates.first[:meme]
      end

      # Related subreddits for expansion
      SUBREDDIT_RELATIONSHIPS = {
        'memes' => ['dankmemes', 'funny', 'me_irl'],
        'dankmemes' => ['memes', 'funny'],
        'wholesomememes' => ['aww', 'mademesmile'],
        'meirl' => ['me_irl', 'memes'],
        'funny' => ['memes', 'dankmemes'],
        'aww' => ['wholesomememes', 'eyebleach'],
        'programmerhumor' => ['programmingmemes', 'coding']
      }.freeze
    end
  end
end