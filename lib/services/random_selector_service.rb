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

    # Humor type weights for diversity
    HUMOR_WEIGHTS = {
      'dank' => 1.0,
      'funny' => 1.2,
      'wholesome' => 0.9,
      'absurdist' => 1.1,
      'dark' => 0.95
    }.freeze

    def self.select_random_meme(memes, session_id: nil, preferences: {})
      return nil if memes.empty?

      # Filter out excluded categories
      filtered_memes = filter_excluded_content(memes, preferences)
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
      # Base weight from engagement
      likes = (meme['likes'] || 0).to_i
      base_weight = 1.0 + (likes * 0.01)

      # Apply humor type weight
      humor_type = meme['humor_type'] || 'funny'
      humor_multiplier = HUMOR_WEIGHTS[humor_type] || 1.0

      # Freshness bonus (newer memes slightly preferred)
      freshness_bonus = calculate_freshness_bonus(meme)

      # Media loadability factor (NEW)
      loadability_factor = calculate_loadability_score(meme)

      base_weight * humor_multiplier * freshness_bonus * loadability_factor
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

      # Memes from last 24 hours get 1.1x bonus, last 7 days get 1.05x
      age_days = (Time.now - Time.parse(created_at.to_s)).to_i / (24 * 3600)
      
      case age_days
      when 0..1
        1.15
      when 2..7
        1.08
      else
        1.0
      end
    rescue
      1.0
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
      recent = recent.last(10) # Keep last 10 to prevent repetition
      
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
