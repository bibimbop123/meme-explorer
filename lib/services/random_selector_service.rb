# Random Selector Service with Weighted Selection and Content Filtering
module MemeExplorer
  class RandomSelectorService
    # Excluded categories that should be filtered out
    EXCLUDED_CATEGORIES = [
      'explicit_adult_content',
      'graphic_violence',
      'hate_speech',
      'harassment',
      'political_extremism',
      'violent_extremism',
      'self_harm',
      'illegal_activity',
      'lgbtq',
      'trans', 
      'political_extreme', 
      'incest'
    ].freeze

    # Humor type weights for diversity (INCREASED for funnier content)
    HUMOR_WEIGHTS = {
      'dank' => 1.3,
      'funny' => 1.5,
      'wholesome' => 1.1,
      'absurdist' => 1.4,
      'dark' => 1.2,
      'relationship' => 1.6  # NEW: Highest weight for relationship memes
    }.freeze

    def self.select_random_meme(memes, session_id: nil, preferences: {})
      return nil if memes.empty?

      # Filter out memes without valid media (prevents fallback images)
      filtered_memes = filter_invalid_media(memes)
      return nil if filtered_memes.empty?

      # Filter out excluded categories
      filtered_memes = filter_excluded_content(filtered_memes, preferences)
      return nil if filtered_memes.empty?

      # Filter out recently shown memes in this session
      if session_id
        filtered_memes = filter_recent_memes(filtered_memes, session_id)
      end

      # Select using weighted algorithm
      weighted_meme = weighted_random_selection(filtered_memes)
      
      # 3-Tier Intelligent Fallback if primary fails
      if weighted_meme.nil?
        weighted_meme = intelligent_fallback(memes, session_id)
      end
      
      return nil if weighted_meme.nil?
      
      # Enhance with media metadata
      enhanced_meme = enhance_with_media_metadata(weighted_meme)
      
      # Track in session to prevent immediate repetition
      track_shown_meme(enhanced_meme, session_id) if session_id

      enhanced_meme
    end

    private

    def self.filter_invalid_media(memes)
      memes.select do |meme|
        # Check for local file
        if meme['file']
          file_path = File.join("public", meme['file'])
          next true if File.exist?(file_path)
        end
        
        # For URL-based memes, check if it's actual media (not just a reddit post link)
        url = meme['url']
        next false unless url && url.match?(/^https?:\/\//)
        
        # Exclude reddit post URLs (these would show fallback images)
        next false if url.include?('/r/') && url.include?('/comments/')
        
        # Valid media URLs should have recognizable media extensions or domains
        url_lower = url.downcase
        
        # Check for image/video extensions
        next true if url_lower =~ /\.(jpg|jpeg|png|gif|webp|mp4|webm|mov)(\?|$|&)/
        
        # Check for known media hosting domains
        media_domains = [
          'i.redd.it',
          'i.imgur.com',
          'imgur.com',
          'gfycat.com',
          'redgifs.com',
          'v.redd.it',
          'giphy.com',
          'tenor.com'
        ]
        
        next true if media_domains.any? { |domain| url_lower.include?(domain) }
        
        # If we have preview images from Reddit, that's valid
        next true if meme['preview'] && meme['preview'].is_a?(Hash)
        
        # Default: reject to avoid fallback images
        false
      end
    end

    def self.filter_excluded_content(memes, preferences = {})
      excluded = preferences[:excluded_categories] || EXCLUDED_CATEGORIES

      memes.select do |meme|
        categories = extract_categories(meme)
        !categories.any? { |cat| excluded.any? { |exc| cat.downcase.include?(exc.downcase) } }
      end
    end

    def self.filter_recent_memes(memes, session_id)
      recent = fetch_recent_memes(session_id)
      return memes if recent.empty?

      memes.reject { |meme| recent.include?(meme_id(meme)) }
    end

    def self.weighted_random_selection(memes)
      # Calculate total weight
      total_weight = memes.sum { |meme| calculate_weight(meme) }
      return memes.first if total_weight <= 0

      # Select based on weighted probability
      random_value = rand * total_weight
      cumulative_weight = 0

      memes.each do |meme|
        cumulative_weight += calculate_weight(meme)
        return meme if random_value <= cumulative_weight
      end

      memes.last
    end

    def self.calculate_weight(meme)
      # IMPROVED: Use quality_score from API if available
      quality_score = meme['quality_score'] || 0
      
      # Base weight from engagement
      likes = (meme['likes'] || 0).to_i
      comments = (meme['comments'] || 0).to_i
      upvote_ratio = (meme['upvote_ratio'] || 0.5).to_f
      
      # If quality_score exists, use it; otherwise calculate
      base_weight = if quality_score > 0
                      1.0 + (quality_score * 0.01)  # Use pre-calculated score
                    else
                      1.0 + (likes * 0.01) + (comments * 0.005) + (upvote_ratio * 0.5)
                    end

      # IMPROVED: Detect humor type from title/subreddit
      humor_type = detect_humor_type(meme)
      humor_multiplier = HUMOR_WEIGHTS[humor_type] || 1.0

      # Freshness bonus (newer memes slightly preferred)
      freshness_bonus = calculate_freshness_bonus(meme)

      # Media loadability factor
      loadability_factor = calculate_loadability_score(meme)
      
      # BONUS: High engagement posts get extra boost
      viral_boost = calculate_viral_boost(likes, comments)

      base_weight * humor_multiplier * freshness_bonus * loadability_factor * viral_boost
    end

    def self.calculate_loadability_score(meme)
      url = meme['url'] || meme['media_url'] || meme['link']
      return 0.0 if url.blank?

      base = case url.downcase
             when /\.jpg|\.jpeg|\.png|\.webp/ then 1.0
             when /\.gif/ then 0.95
             when /\.mp4|\.webm|\.avi/ then 0.9
             when /imgur|i\.imgur/ then 0.85
             when /gfycat|redgifs/ then 0.80
             when /reddit/ then 0.65
             else 0.5
             end

      boost = [(meme['successful_loads'].to_i * 0.05), 0.2].min
      penalty = [(meme['failed_loads'].to_i * 0.05), 0.3].min
      gallery_bonus = is_meme_gallery?(meme) ? 1.05 : 1.0

      final = (base + boost - penalty) * gallery_bonus
      [[final, 1.0].min, 0.0].max
    end

    def self.is_meme_gallery?(meme)
      urls = meme['media_urls'] || meme['images'] || []
      urls.is_a?(Array) && urls.length > 1
    end

    def self.intelligent_fallback(all_memes, session_id)
      best = find_most_loadable_meme(all_memes)
      return best if best
      return weighted_random_selection(all_memes) unless all_memes.empty?
      nil
    end

    def self.find_most_loadable_meme(memes)
      return nil if memes.empty?
      best_meme = nil
      best_score = 0.5
      memes.each do |meme|
        score = calculate_loadability_score(meme)
        best_meme = meme if score > best_score
        best_score = score if score > best_score
      end
      best_meme
    end

    def self.enhance_with_media_metadata(meme)
      enhanced = meme.dup
      url = meme['url'] || meme['media_url'] || meme['link']
      enhanced['media_metadata'] = {
        primary_url: url,
        all_urls: (meme['media_urls'] || meme['images'] || [url]),
        is_gallery: is_meme_gallery?(meme),
        loadability_score: calculate_loadability_score(meme)
      }
      enhanced
    end

    def self.calculate_freshness_bonus(meme)
      created_at = meme['created_at']
      return 1.0 unless created_at

      # BALANCED: Modest freshness bonus - prioritize FUNNY over NEW
      age_days = (Time.now - Time.parse(created_at.to_s)).to_i / (24 * 3600)
      
      case age_days
      when 0..1
        1.12  # Reduced from 1.25 - less aggressive new content bias
      when 2..3
        1.08  # Reduced from 1.15
      when 4..7
        1.05  # Reduced from 1.08
      else
        1.0
      end
    rescue
      1.0
    end
    
    # NEW: Detect humor type from content
    def self.detect_humor_type(meme)
      title = (meme['title'] || '').downcase
      subreddit = (meme['subreddit'] || '').downcase
      
      # Relationship memes (highest priority)
      relationship_keywords = ['boyfriend', 'girlfriend', 'dating', 'relationship', 'tinder', 
                               'bumble', 'crush', 'ex', 'marriage', 'wife', 'husband']
      return 'relationship' if relationship_keywords.any? { |kw| title.include?(kw) || subreddit.include?(kw) }
      
      # Absurdist
      absurdist_subs = ['okbuddyretard', 'comedyheaven', 'shitposting', 'blursed']
      return 'absurdist' if absurdist_subs.any? { |sub| subreddit.include?(sub) }
      
      # Wholesome
      wholesome_subs = ['wholesome', 'mademesmile', 'eyebleach', 'aww']
      return 'wholesome' if wholesome_subs.any? { |sub| subreddit.include?(sub) }
      
      # Dank
      dank_subs = ['dank', 'holup', 'cursed']
      return 'dank' if dank_subs.any? { |sub| subreddit.include?(sub) }
      
      # Default to funny
      'funny'
    end
    
    # NEW: Viral boost for high-engagement posts
    def self.calculate_viral_boost(likes, comments)
      # Posts with 500+ upvotes and 50+ comments are "viral"
      if likes >= 500 && comments >= 50
        1.5  # 50% boost for viral content
      elsif likes >= 200 && comments >= 20
        1.3  # 30% boost for popular content
      elsif likes >= 100
        1.15 # 15% boost for decent content
      else
        1.0
      end
    end

    def self.extract_categories(meme)
      categories = meme['categories'] || meme['tags'] || []
      categories.is_a?(Array) ? categories : [categories.to_s]
    end

    def self.meme_id(meme)
      meme['id'] || meme['url'] || meme.to_s
    end

    def self.track_shown_meme(meme, session_id)
      key = "recent_memes_#{session_id}"
      recent = fetch_recent_memes(session_id)
      recent.push(meme_id(meme))
      recent = recent.last(50) # Keep last 50 to prevent repetition (increased from 10)
      
      # Store in session or cache (implementation depends on your framework)
      # This is a placeholder - adjust based on your session/cache implementation
    end

    def self.fetch_recent_memes(session_id)
      key = "recent_memes_#{session_id}"
      # Placeholder for session/cache retrieval
      # Implementation depends on your framework
      []
    end
  end
end
