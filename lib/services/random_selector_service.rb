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
      
      # Track in session to prevent immediate repetition
      track_shown_meme(weighted_meme, session_id) if session_id

      weighted_meme
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

      base_weight * humor_multiplier * freshness_bonus
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
