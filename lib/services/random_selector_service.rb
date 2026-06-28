# Enhanced Random Selector Service - MAXIMUM HUMOR & ENGAGEMENT
# Improvements:
# 1. FEWER FALLBACKS: Aggressive media validation, URL quality scoring
# 2. FUNNIER CONTENT: Advanced humor detection, viral boost, quality filters
# 3. MORE ADDICTIVE: Variety algorithm, surprise mechanics, streak tracking

# Phase 2: Load algorithm configuration service
require_relative './algorithm_config_service'

# Phase 3: Load addiction/gamification services
require_relative './surprise_mechanics_service' rescue nil
require_relative './near_miss_service' rescue nil
require_relative './milestone_service' rescue nil

# Phase 4-6: Load quality, humor, and retention services
require_relative './quality_control_service' rescue nil
require_relative './humor_optimizer_service' rescue nil
require_relative './retention_service' rescue nil

module MemeExplorer
  class RandomSelectorService
    # Excluded categories (safety filters)
    EXCLUDED_CATEGORIES = [
      'explicit_adult_content', 'graphic_violence', 'hate_speech',
      'harassment', 'political_extremism', 'violent_extremism',
      'self_harm', 'illegal_activity', 'lgbtq', 'trans', 
      'political_extreme', 'incest'
    ].freeze

    # ENHANCED HUMOR WEIGHTS - Optimized for maximum laughs
    HUMOR_WEIGHTS = {
      'relationship' => 2.0,   # Relationship memes = comedy gold
      'dating_fail' => 1.9,    # Dating disasters are hilarious
      'absurdist' => 1.7,      # Absurd humor is highly engaging
      'dank' => 1.6,           # Edgy memes perform well
      'funny' => 1.5,          # Classic humor baseline
      'dark' => 1.4,           # Dark humor has loyal fans
      'wholesome' => 1.2,      # Palate cleanser
      'relatable' => 1.8,      # Super relatable = viral potential
      'cringe' => 1.6,         # Cringe is engaging
      'unexpected' => 1.7      # Plot twists = addictive
    }.freeze

    # QUALITY TIER MULTIPLIERS - Prioritize high-quality sources
    SOURCE_QUALITY = {
      # Tier S: Absolute best
      'dankmemes' => 2.0, 'me_irl' => 2.0, 'meirl' => 2.0,
      'Tinder' => 1.9, 'Bumble' => 1.9, 'ComedyHeaven' => 1.9,
      
      # Tier A: Excellent
      'relationship_memes' => 1.8, 'HolUp' => 1.8, '2meirl4meirl' => 1.8,
      'cursedcomments' => 1.7, 'blursedimages' => 1.7,
      
      # Tier B: Very good
      'memes' => 1.5, 'funny' => 1.5, 'OkBuddyRetard' => 1.6,
      'shitposting' => 1.6, 'niceguys' => 1.5, 'Nicegirls' => 1.5,
      
      # Default: 1.0 for unlisted subs
    }.freeze

    # Media URL quality scoring - Higher = more reliable
    MEDIA_DOMAIN_SCORES = {
      'i.redd.it' => 1.0,        # Reddit's CDN - most reliable
      'i.imgur.com' => 0.95,     # Imgur direct - very reliable
      'preview.redd.it' => 0.90, # Reddit preview - reliable
      'imgur.com/a/' => 0.75,    # Imgur albums - slower
      'gfycat.com' => 0.70,      # Often breaks
      'redgifs.com' => 0.65,     # Sometimes NSFW issues
      'v.redd.it' => 0.85,       # Reddit video - usually works
      'tenor.com' => 0.80,       # GIF host - decent
      'giphy.com' => 0.80        # GIF host - decent
    }.freeze

    class << self
      # Main selection method with enhanced algorithms
      def select_random_meme(memes, session_id: nil, preferences: {})
        start_time = Time.now  # Track performance
        return nil if memes.empty?

        # PHASE 1 FIX #1: Batch fetch ALL session data in ONE Redis pipeline call
        @session_cache = fetch_session_data_batch(session_id) if session_id

        # STEP 1: Aggressive media filtering (eliminate fallback risks)
        filtered_memes = filter_high_quality_media(memes)
        return nil if filtered_memes.empty?

      # STEP 2: Skip crossposts (safety filter - should already be filtered at API level)
      filtered_memes = filter_crossposts(filtered_memes)
      return nil if filtered_memes.empty?

      # STEP 3: Content safety filtering
      filtered_memes = filter_excluded_content(filtered_memes, preferences)
      return nil if filtered_memes.empty?

      # STEP 4: Anti-repetition filtering (session-aware)
      if session_id
        filtered_memes = filter_recent_and_similar(filtered_memes, session_id)
          # If too aggressive, relax constraints
          filtered_memes = filter_recent_memes(memes, session_id) if filtered_memes.empty?
        end

        # PHASE 4: Quality Control filtering - Never show a bad meme
        if defined?(MemeExplorer::QualityControlService)
          filtered_memes = MemeExplorer::QualityControlService.filter_quality_pool(filtered_memes)
          # Fallback if quality filter too aggressive
          filtered_memes = filter_high_quality_media(memes) if filtered_memes.empty?
        end

        # PHASE 5: Humor Optimization - Comedy sequencing
        if session_id && defined?(MemeExplorer::HumorOptimizerService)
          filtered_memes = MemeExplorer::HumorOptimizerService.optimize_humor_sequence(filtered_memes, session_id)
        end

        # STEP 4: Variety algorithm - prevent same type repeatedly
        filtered_memes = apply_variety_filter(filtered_memes, session_id) if session_id

        # STEP 5: Smart weighted selection with surprise factor
        selected = intelligent_weighted_selection(filtered_memes, session_id)
        
        # STEP 6: Intelligent fallback if needed
        selected ||= intelligent_fallback(memes, session_id)
        return nil if selected.nil?
        
        # STEP 7: Enhance with metadata
        enhanced = enhance_with_metadata(selected)
        
        # STEP 8: Track for future selections
        track_selection(enhanced, session_id) if session_id

        # PHASE 5: Track humor type and themes for comedy optimization
        if session_id && defined?(MemeExplorer::HumorOptimizerService)
          MemeExplorer::HumorOptimizerService.track_humor_type(session_id, enhanced)
          MemeExplorer::HumorOptimizerService.track_theme(session_id, enhanced)
        end

        # PHASE 1 FIX #2: Log selection metadata for observability
        log_selection_metadata(enhanced, {
          pool_size: memes.size,
          filtered_size: filtered_memes.size,
          session_id: session_id,
          duration_ms: ((Time.now - start_time) * 1000).round(2),
          personalization_applied: !session_id.nil?,
          algorithm_version: 'v2_personalized'
        })

        enhanced
      end

      private

      # PHASE 1 FIX #1: Batch fetch session data (10x faster)
      def fetch_session_data_batch(session_id)
        return {} unless defined?(REDIS) && REDIS
        
        keys = [
          "recent_humor_types:#{session_id}",
          "recent_memes:#{session_id}",
          "recent_titles:#{session_id}"
        ]
        
        values = REDIS.pipelined do |pipe|
          keys.each { |key| pipe.get(key) }
        end
        
        {
          humor_types: JSON.parse(values[0] || '[]'),
          meme_ids: JSON.parse(values[1] || '[]'),
          titles: JSON.parse(values[2] || '[]')
        }
      rescue => e
        puts "⚠️  Session batch fetch failed: #{e.message}"
        {}
      end

      # PHASE 1 FIX #2: Log algorithm decisions for observability
      def log_selection_metadata(meme, metadata)
        # Basic logging
        puts "[ALGORITHM] #{metadata.to_json}"
        
        # Track in Redis for dashboard
        if defined?(REDIS) && REDIS
          REDIS.lpush('algorithm:selections', {
            timestamp: Time.now.to_i,
            meme_id: meme['id'] || meme['url'],
            **metadata
          }.to_json)
          REDIS.ltrim('algorithm:selections', 0, 999)  # Keep last 1000
        end
      rescue => e
        # Don't break selection if logging fails
        puts "Logging error: #{e.message}"
      end

      # ENHANCEMENT 1: Aggressive high-quality media filtering
      def filter_high_quality_media(memes)
        memes.select do |meme|
          score = calculate_media_quality_score(meme)
          score >= 0.6 # Only accept media with 60%+ quality score
        end
      end

      # Calculate comprehensive media quality score
      def calculate_media_quality_score(meme)
        url = meme['url'] || meme['media_url'] || meme['link']
        return 0.0 if url.nil? || url.empty?

        # Local files = perfect score
        if url.start_with?('/', 'images/', 'videos/')
          file_path = url.start_with?('/') ? File.join('public', url[1..-1]) : File.join('public', url)
          return File.exist?(file_path) ? 1.0 : 0.0
        end

        # Remote URL validation
        return 0.0 unless url.match?(/^https?:\/\//)
        
        score = 0.0
        url_lower = url.downcase

        # CRITICAL: Reject Reddit post URLs (these show fallback images)
        return 0.0 if url_lower.include?('/r/') && url_lower.include?('/comments/')
        
        # Score based on domain quality
        MEDIA_DOMAIN_SCORES.each do |domain, domain_score|
          if url_lower.include?(domain)
            score = [score, domain_score].max
          end
        end

        # Boost for direct media file extensions
        if url_lower =~ /\.(jpg|jpeg|png|webp)(\?|$|&)/
          score += 0.3
        elsif url_lower =~ /\.(gif)(\?|$|&)/
          score += 0.25
        elsif url_lower =~ /\.(mp4|webm)(\?|$|&)/
          score += 0.2
        end

        # Bonus for preview data available
        score += 0.1 if meme['preview'] && meme['preview'].is_a?(Hash)

        # Penalty for suspicious patterns
        score -= 0.3 if url_lower.include?('removed') || url_lower.include?('deleted')
        
        # Historical performance boost
        successful = meme['successful_loads'].to_i
        failed = meme['failed_loads'].to_i
        if successful + failed > 10
          success_rate = successful.to_f / (successful + failed)
          score += (success_rate - 0.5) * 0.2 # ±0.1 based on history
        end

        [[score, 1.0].min, 0.0].max # Clamp between 0.0 and 1.0
      end

      # ENHANCEMENT 2: Advanced humor detection and scoring
      def calculate_humor_score(meme)
        title = (meme['title'] || '').downcase
        subreddit = (meme['subreddit'] || '').downcase
        
        humor_types = []
        
        # Relationship/Dating humor (TOP TIER)
        dating_keywords = ['tinder', 'bumble', 'hinge', 'dating', 'boyfriend', 'girlfriend', 
                          'crush', 'ex', 'marriage', 'wife', 'husband', 'relationship',
                          'valentine', 'single', 'couples']
        if dating_keywords.any? { |kw| title.include?(kw) || subreddit.include?(kw) }
          humor_types << 'relationship'
        end

        # Dating fail specific
        fail_keywords = ['rejected', 'ghosted', 'unmatched', 'friendzone', 'cringe', 'awkward']
        if fail_keywords.any? { |kw| title.include?(kw) }
          humor_types << 'dating_fail'
        end

        # Relatable content
        relatable_keywords = ['me_irl', 'meirl', 'relatable', 'literally me', 'too real']
        relatable_subs = ['me_irl', 'meirl', '2meirl4meirl', 'absolutelynotmeirl']
        if relatable_keywords.any? { |kw| title.include?(kw) } || 
           relatable_subs.any? { |sub| subreddit.include?(sub) }
          humor_types << 'relatable'
        end

        # Absurdist
        absurdist_subs = ['okbuddyretard', 'comedyheaven', 'shitposting', 'blursed', 
                         'hmmm', 'surrealmemes']
        if absurdist_subs.any? { |sub| subreddit.include?(sub) }
          humor_types << 'absurdist'
        end

        # Unexpected/Plot twist
        unexpected_keywords = ['plot twist', 'unexpected', 'holup', 'wait what']
        unexpected_subs = ['holup', 'unexpected', 'yesyesyesyesno', 'nonononoyes']
        if unexpected_keywords.any? { |kw| title.include?(kw) } ||
           unexpected_subs.any? { |sub| subreddit.include?(sub) }
          humor_types << 'unexpected'
        end

        # Cringe humor
        cringe_subs = ['niceguys', 'nicegirls', 'creepypms', 'cringepics', 'sadcringe']
        if cringe_subs.any? { |sub| subreddit.include?(sub) }
          humor_types << 'cringe'
        end

        # Dank
        dank_subs = ['dank', 'dankmemes', 'cursed']
        if dank_subs.any? { |sub| subreddit.include?(sub) }
          humor_types << 'dank'
        end

        # Dark humor
        dark_keywords = ['dark', 'cursed', 'offensive']
        if dark_keywords.any? { |kw| title.include?(kw) || subreddit.include?(kw) }
          humor_types << 'dark'
        end

        # Wholesome (palate cleanser)
        wholesome_subs = ['wholesome', 'mademesmile', 'eyebleach', 'aww']
        if wholesome_subs.any? { |sub| subreddit.include?(sub) }
          humor_types << 'wholesome'
        end

        # Default
        humor_types << 'funny' if humor_types.empty?

        # Get highest weight
        max_weight = humor_types.map { |type| HUMOR_WEIGHTS[type] || 1.0 }.max
        max_weight
      end

      # ENHANCEMENT 3: Intelligent weighted selection with surprise mechanics + time-of-day
      def intelligent_weighted_selection(memes, session_id = nil)
        return memes.sample if memes.size <= 3

        # Enhanced surprise mechanics with multiple types
        if session_id
          surprise_chance = calculate_surprise_chance(session_id)
          if rand < surprise_chance
            return select_surprise_meme(memes, session_id)
          end
        end

        # Calculate weights for all memes
        weighted_memes = memes.map do |meme|
          {
            meme: meme,
            weight: calculate_comprehensive_weight(meme, session_id)
          }
        end

        # Sort by weight and use weighted random from top 30%
        weighted_memes.sort_by! { |wm| -wm[:weight] }
        top_tier_size = [weighted_memes.size / 3, 3].max
        top_tier = weighted_memes.take(top_tier_size)

        # Weighted random selection from top tier
        total_weight = top_tier.sum { |wm| wm[:weight] }
        random_value = rand * total_weight
        cumulative = 0

        top_tier.each do |wm|
          cumulative += wm[:weight]
          return wm[:meme] if random_value <= cumulative
        end

        top_tier.last[:meme]
      end

      # ENHANCEMENT 4: Comprehensive weight calculation with personalization + time-of-day
      def calculate_comprehensive_weight(meme, session_id = nil)
        # Base engagement score
        likes = meme['likes'].to_i
        comments = meme['comments'].to_i
        upvote_ratio = meme['upvote_ratio'].to_f || 0.5

        base_score = 1.0 + (likes * 0.01) + (comments * 0.008) + (upvote_ratio * 0.3)

        # Humor multiplier with time-of-day adjustment
        humor_score = calculate_humor_score_with_time(meme)

        # Source quality multiplier
        subreddit = (meme['subreddit'] || '').downcase
        source_multiplier = SOURCE_QUALITY[subreddit] || 1.0

        # Media quality multiplier (CRITICAL for reducing fallbacks)
        media_quality = calculate_media_quality_score(meme)
        media_multiplier = 0.5 + (media_quality * 1.5) # Range: 0.5 to 2.0

        # Viral boost (ENHANCED)
        viral_multiplier = calculate_viral_multiplier(likes, comments, upvote_ratio)

        # Freshness factor (AGGRESSIVE - new content prioritized)
        freshness = calculate_freshness_multiplier(meme)

        # Variety bonus (NEW - prevents monotony)
        variety_bonus = calculate_variety_bonus(meme, session_id)

        # Quality filter - reject low-quality upvote ratios
        quality_filter = upvote_ratio >= 0.6 ? 1.0 : 0.5

        # Personalization multiplier (if user has history)
        personalization_bonus = calculate_personalization_bonus(meme, session_id)

        # Hot streak bonus (reward engagement momentum)
        streak_bonus = calculate_streak_bonus(session_id)

        # FINAL WEIGHT with all enhancements
        final_weight = base_score * 
                      humor_score * 
                      source_multiplier * 
                      media_multiplier * 
                      viral_multiplier * 
                      freshness * 
                      variety_bonus * 
                      quality_filter *
                      personalization_bonus *
                      streak_bonus

        final_weight
      end

      # Enhanced viral detection
      def calculate_viral_multiplier(likes, comments, upvote_ratio)
        # Mega viral (10k+ upvotes)
        return 2.5 if likes >= 10000 && upvote_ratio >= 0.8

        # Super viral (5k+ upvotes)
        return 2.0 if likes >= 5000 && upvote_ratio >= 0.75

        # Viral (1k+ upvotes)
        return 1.7 if likes >= 1000 && comments >= 100

        # Popular (500+ upvotes)
        return 1.4 if likes >= 500 && comments >= 50

        # Good (200+ upvotes)
        return 1.2 if likes >= 200

        # Decent engagement
        return 1.1 if likes >= 100

        1.0
      end

      # Variety bonus to prevent showing same type repeatedly (PHASE 2: Config-driven)
      def calculate_variety_bonus(meme, session_id)
        return 1.0 unless session_id
        
        recent_types = fetch_recent_humor_types(session_id)
        return 1.0 if recent_types.empty?

        current_humor = detect_primary_humor_type(meme)
        
        # Count how many of last 5 were this type
        last_5 = recent_types.last(5)
        same_type_count = last_5.count(current_humor)

        # PHASE 2: Use config service for variety bonuses
        AlgorithmConfigService.variety_bonus(same_type_count)
      end

      def detect_primary_humor_type(meme)
        title = (meme['title'] || '').downcase
        subreddit = (meme['subreddit'] || '').downcase
        
        return 'relationship' if title =~ /tinder|dating|girlfriend|boyfriend/ || 
                                 subreddit =~ /tinder|relationship|dating/
        return 'relatable' if subreddit =~ /me_irl|meirl/
        return 'absurdist' if subreddit =~ /okbuddy|comedyheaven|shitpost/
        return 'wholesome' if subreddit =~ /wholesome|mademesmile|aww/
        return 'cringe' if subreddit =~ /niceguy|cringe/
        return 'unexpected' if subreddit =~ /holup|unexpected/
        
        'funny'
      end

      # IMPROVED: Aggressive freshness multiplier (PHASE 2: Config-driven)
      def calculate_freshness_multiplier(meme)
        created_at = meme['created_at']
        return 1.0 unless created_at

        age_hours = (Time.now - Time.parse(created_at.to_s)).to_i / 3600
        
        # PHASE 2: Use config service for freshness multipliers
        AlgorithmConfigService.freshness_multiplier(age_hours)
      rescue
        1.0
      end

      # ENHANCEMENT 5: Anti-repetition with similarity detection
      def filter_recent_and_similar(memes, session_id)
        recent_ids    = Array(fetch_recent_memes(session_id))
        recent_titles = Array(fetch_recent_titles(session_id))
        
        memes.reject do |meme|
          meme_id = meme_identifier(meme)
          title = (meme['title'] || '').downcase
          
          # Exact match rejection
          next true if recent_ids.include?(meme_id)
          
          # Similar title rejection (prevents duplicate jokes)
          next true if recent_titles.any? { |rt| titles_similar?(rt, title) }
          
          false
        end
      end

      # Check if titles are too similar
      def titles_similar?(title1, title2)
        return false if title1.nil? || title2.nil?
        return false if title1.length < 10 || title2.length < 10
        
        # Extract key words (remove common words)
        words1 = title1.downcase.split(/\W+/) - ['the', 'a', 'an', 'and', 'or', 'but', 'in', 'on', 'at', 'to', 'for']
        words2 = title2.downcase.split(/\W+/) - ['the', 'a', 'an', 'and', 'or', 'but', 'in', 'on', 'at', 'to', 'for']
        
        return false if words1.empty? || words2.empty?
        
        # Calculate overlap
        common = words1 & words2
        total_unique = (words1 | words2).size
        
        overlap_ratio = common.size.to_f / total_unique
        overlap_ratio > 0.6 # >60% overlap = too similar
      end

      # Apply variety filter
      def apply_variety_filter(memes, session_id)
        return memes if memes.size <= 5
        
        # Get recent humor types
        recent_types = fetch_recent_humor_types(session_id)
        return memes if recent_types.empty?

        # If last 3 were all the same type, strongly prefer different types
        last_3 = recent_types.last(3)
        if last_3.uniq.size == 1
          dominant_type = last_3.first
          different_types = memes.reject { |m| detect_primary_humor_type(m) == dominant_type }
          return different_types unless different_types.empty?
        end

        memes
      end

      # Intelligent fallback system
      def intelligent_fallback(all_memes, session_id)
        # Try to find best loadable meme
        sorted = all_memes.sort_by do |meme|
          -calculate_media_quality_score(meme)
        end

        # Return best that meets minimum quality
        sorted.find { |m| calculate_media_quality_score(m) >= 0.4 } || sorted.first
      end

      # Enhanced metadata
      def enhance_with_metadata(meme)
        enhanced = meme.dup
        url = meme['url'] || meme['media_url'] || meme['link']
        
        enhanced['media_metadata'] = {
          primary_url: url,
          all_urls: meme['media_urls'] || meme['images'] || [url].compact,
          is_gallery: (meme['media_urls'] || meme['images'] || []).is_a?(Array) && 
                     (meme['media_urls'] || meme['images'] || []).length > 1,
          quality_score: calculate_media_quality_score(meme),
          humor_score: calculate_humor_score(meme),
          comprehensive_weight: calculate_comprehensive_weight(meme, nil)
        }
        
        enhanced
      end

      # Tracking methods
      def track_selection(meme, session_id)
        # Track meme ID — Array() guards against nil when Redis returns nothing
        recent_ids = Array(fetch_recent_memes(session_id))
        recent_ids << meme_identifier(meme)
        store_recent_memes(session_id, recent_ids.last(100))

        # Track title
        recent_titles = Array(fetch_recent_titles(session_id))
        recent_titles << (meme['title'] || '').downcase
        store_recent_titles(session_id, recent_titles.last(50))

        # Track humor type
        recent_types = Array(fetch_recent_humor_types(session_id))
        recent_types << detect_primary_humor_type(meme)
        store_recent_humor_types(session_id, recent_types.last(20))
      end

      # Session storage helpers (use Redis if available, fallback to memory)
      def fetch_recent_memes(session_id)
        return Array(@session_cache[:meme_ids]) if @session_cache
        key = "recent_memes:#{session_id}"
        Array(fetch_from_storage(key))
      end

      def store_recent_memes(session_id, data)
        key = "recent_memes:#{session_id}"
        store_in_storage(key, data, 3600) # 1 hour TTL
      end

      def fetch_recent_titles(session_id)
        return Array(@session_cache[:titles]) if @session_cache
        key = "recent_titles:#{session_id}"
        Array(fetch_from_storage(key))
      end

      def store_recent_titles(session_id, data)
        key = "recent_titles:#{session_id}"
        store_in_storage(key, data, 3600)
      end

      def fetch_recent_humor_types(session_id)
        return Array(@session_cache[:humor_types]) if @session_cache
        key = "recent_humor_types:#{session_id}"
        Array(fetch_from_storage(key))
      end

      def store_recent_humor_types(session_id, data)
        key = "recent_humor_types:#{session_id}"
        store_in_storage(key, data, 3600)
      end

      # Storage abstraction with PHASE 1 FIX #3: Graceful degradation
      def fetch_from_storage(key)
        # Tier 1: Try Redis (fast)
        if defined?(REDIS) && REDIS
          data = REDIS.get(key)
          return JSON.parse(data) if data
        end
        
        # Tier 2: Try in-memory cache (slower but works)
        @memory_cache ||= {}
        return @memory_cache[key] if @memory_cache[key]
        
        # Tier 3: Empty state (graceful degradation)
        nil
      rescue => e
        puts "⚠️  Storage error for #{key}: #{e.message}"
        Sentry.capture_exception(e) if defined?(Sentry)
        nil
      end

      def store_in_storage(key, data, ttl = 3600)
        # Try Redis first
        if defined?(REDIS) && REDIS
          REDIS.setex(key, ttl, data.to_json)
        end
        
        # PHASE 1 FIX #3: Always store in memory cache as backup
        @memory_cache ||= {}
        @memory_cache[key] = data
        
        # Cleanup memory cache periodically
        if @memory_cache.size > 1000
          @memory_cache.shift(500)  # Remove oldest 500
        end
      rescue => e
        puts "⚠️  Storage error: #{e.message}"
        # Site still works even if storage fails
      end

      # Filter crossposts - keep only original content
      def filter_crossposts(memes)
        memes.reject do |meme|
          meme['is_crosspost'] || meme['crosspost_parent'] || meme['crosspost_parent_list']
        end
      end

      # Filter embedded posts - keep only direct media (defensive layer)
      def filter_embedded_posts(memes)
        memes.reject do |meme|
          # Check if post_hint indicates embedded content
          post_hint = meme['post_hint']
          next true if post_hint == 'rich:video'
          
          # Check URL patterns for embedded content (YouTube, Twitter, etc.)
          url = meme['url'] || meme['media_url'] || meme['link']
          next true if url&.include?('youtube.com')
          next true if url&.include?('youtu.be')
          next true if url&.include?('twitter.com')
          next true if url&.include?('x.com')
          
          false
        end
      end

      # Helper methods
      def filter_excluded_content(memes, preferences = {})
        excluded = preferences[:excluded_categories] || EXCLUDED_CATEGORIES
        
        memes.select do |meme|
          categories = extract_categories(meme)
          !categories.any? { |cat| excluded.any? { |exc| cat.downcase.include?(exc.downcase) } }
        end
      end

      def filter_recent_memes(memes, session_id)
        recent = fetch_recent_memes(session_id)
        return memes if recent.empty?
        
        memes.reject { |meme| recent.include?(meme_identifier(meme)) }
      end

      def extract_categories(meme)
        categories = meme['categories'] || meme['tags'] || []
        categories.is_a?(Array) ? categories : [categories.to_s]
      end

      def meme_identifier(meme)
        meme['id'] || meme['url'] || meme['file'] || meme.to_s
      end

      # NEW: Time-of-day adjusted humor scoring
      def calculate_humor_score_with_time(meme)
        base_humor = calculate_humor_score(meme)
        time_multiplier = get_time_of_day_multiplier(meme)
        base_humor * time_multiplier
      end

      # NEW: Time-of-day content strategy
      def get_time_of_day_multiplier(meme)
        hour = Time.now.hour
        humor_type = detect_primary_humor_type(meme)

        case hour
        when 6..10  # Morning: wholesome, uplifting
          case humor_type
          when 'wholesome' then 1.8
          when 'funny', 'relatable' then 1.5
          when 'dark', 'cringe' then 0.6
          else 1.0
          end
        when 11..14  # Lunch: quick laughs, work humor
          case humor_type
          when 'relatable', 'funny' then 1.7
          when 'cringe' then 1.4
          else 1.0
          end
        when 15..17  # Afternoon slump: energetic, unexpected
          case humor_type
          when 'unexpected', 'absurdist' then 1.6
          when 'funny' then 1.3
          else 1.0
          end
        when 18..22  # Evening: diverse, relationships
          case humor_type
          when 'relationship', 'dating_fail' then 1.9
          when 'dark', 'dank' then 1.5
          else 1.0
          end
        when 23..27  # Late night: weird, absurdist (27 = 3am next day)
          hour = hour % 24
          if hour >= 23 || hour < 3
            case humor_type
            when 'absurdist', 'unexpected' then 2.0
            when 'wholesome' then 0.7
            else 1.0
            end
          else
            1.0
          end
        else  # Early morning 3-6am: contemplative
          case humor_type
          when 'relatable', 'funny' then 1.5
          else 1.0
          end
        end
      end

      # NEW: Enhanced surprise mechanics with multiple types
      def calculate_surprise_chance(session_id)
        base_chance = 0.15
        
        # Increase if user is on hot streak
        recent_actions = fetch_recent_humor_types(session_id).last(5)
        consecutive_likes = recent_actions.count('liked')
        
        if consecutive_likes >= 3
          base_chance *= 1.5  # 22.5% when hot
        end
        
        # Time-based bonus (late night = more surprises)
        hour = Time.now.hour
        if (hour >= 23 || hour < 3)
          base_chance *= 1.3  # ~20-30% late night
        end
        
        [base_chance, 0.40].min  # Cap at 40%
      end

      # NEW: Select surprise meme with variety
      def select_surprise_meme(memes, session_id)
        surprise_type = rand
        
        case surprise_type
        when 0.0..0.40  # 40%: Random variety
          memes.sample
        when 0.40..0.65  # 25%: Ultra-premium quality
          premium = memes.select { |m| m['likes'].to_i > 10000 && calculate_media_quality_score(m) > 0.85 }
          premium.any? ? premium.sample : memes.sample
        when 0.65..0.85  # 20%: Unseen category
          seen_subs = fetch_recent_humor_types(session_id).map { |type| type.split(':').last }.uniq
          unseen = memes.reject { |m| seen_subs.include?(m['subreddit']) }
          unseen.any? ? unseen.sample : memes.sample
        else  # 15%: Oldest/vintage content (throwback)
          oldest = memes.sort_by { |m| m['created_at'] || Time.now.to_s }.first(10)
          oldest.sample
        end
      end

      # NEW: Personalization bonus based on user history
      def calculate_personalization_bonus(meme, session_id)
        return 1.0 unless session_id
        
        # Get user's interaction history
        recent_types = fetch_recent_humor_types(session_id)
        return 1.0 if recent_types.empty?
        
        # Count likes vs skips for this humor type
        current_humor = detect_primary_humor_type(meme)
        humor_interactions = recent_types.select { |t| t.include?(current_humor) }
        
        return 1.0 if humor_interactions.empty?
        
        # Calculate engagement rate for this type
        likes = humor_interactions.count { |t| t.include?('liked') }
        total = humor_interactions.size
        engagement_rate = likes.to_f / total
        
        # Convert to multiplier (0.5 - 2.0 range)
        0.5 + (engagement_rate * 1.5)
      end

      # NEW: Hot streak detection and bonus (PHASE 2: Config-driven)
      def calculate_streak_bonus(session_id)
        return 1.0 unless session_id
        
        recent_actions = fetch_recent_humor_types(session_id).last(10)
        return 1.0 if recent_actions.empty?
        
        # Count consecutive likes at the end
        consecutive_likes = 0
        recent_actions.reverse.each do |action|
          if action.include?('liked')
            consecutive_likes += 1
          else
            break
          end
        end
        
        # PHASE 2: Use config service for streak bonuses
        AlgorithmConfigService.streak_bonus(consecutive_likes)
      end
    end
  end
end
