# Image Fallback Service
# Smart category-based fallback logic
# Phase 3: Advanced Features - Part 1
# Updated to use Tattoo Annie as primary placeholder

class ImageFallbackService
  # Primary placeholder - Tattoo Annie (SEO-optimized)
  PRIMARY_PLACEHOLDER = '/images/tattoo-annie-placeholder.jpg'.freeze

  # Category-aware fallback images (secondary fallbacks)
  CATEGORY_FALLBACKS = {
    'funny' => [
      PRIMARY_PLACEHOLDER,
      '/images/funny1.jpeg',
      '/images/funny2.jpeg',
      '/images/funny3.jpeg'
    ],
    'wholesome' => [
      PRIMARY_PLACEHOLDER,
      '/images/wholesome1.jpeg',
      '/images/wholesome2.jpeg',
      '/images/wholesome3.jpeg'
    ],
    'selfcare' => [
      PRIMARY_PLACEHOLDER,
      '/images/selfcare1.jpeg',
      '/images/selfcare2.jpeg',
      '/images/selfcare3.jpeg'
    ],
    'dank' => [
      PRIMARY_PLACEHOLDER,
      '/images/dank1.jpeg',
      '/images/dank2.jpeg'
    ]
  }.freeze

  # Subreddit to category mapping
  SUBREDDIT_CATEGORIES = {
    # Funny
    /funny|laugh|jokes|lol|humor/ => 'funny',
    # Wholesome
    /wholesome|aww|heartwarming|feel_good|mademesmile/ => 'wholesome',
    # Self-care
    /health|fitness|mindfulness|mental|wellness|meditation|yoga/ => 'selfcare',
    # Default: dank
  }.freeze

  class << self
    # Get fallback image for subreddit
    # @param subreddit [String] Subreddit name
    # @param randomize [Boolean] Randomize or return first
    # @param use_primary [Boolean] Always use Tattoo Annie as primary
    # @return [String] Fallback image URL
    def get_fallback(subreddit, randomize: true, use_primary: true)
      # Always return Tattoo Annie if use_primary is true
      return PRIMARY_PLACEHOLDER if use_primary

      category = categorize_subreddit(subreddit)
      fallbacks = CATEGORY_FALLBACKS[category] || CATEGORY_FALLBACKS['dank']
      randomize ? fallbacks.sample : fallbacks.first
    end

    # Get primary placeholder (Tattoo Annie)
    # @return [String] Primary placeholder URL
    def get_primary_placeholder
      PRIMARY_PLACEHOLDER
    end

    # Get all fallbacks for category
    # @param category [String] Category name
    # @return [Array] Array of fallback URLs
    def get_category_fallbacks(category)
      CATEGORY_FALLBACKS[category] || CATEGORY_FALLBACKS['dank']
    end

    # Categorize subreddit by name
    # @param subreddit [String] Subreddit name
    # @return [String] Category name
    def categorize_subreddit(subreddit)
      return 'dank' if subreddit.blank?

      subreddit_lower = subreddit.downcase

      # Check each regex pattern
      SUBREDDIT_CATEGORIES.each do |pattern, category|
        return category if subreddit_lower.match?(pattern)
      end

      # Default fallback
      'dank'
    end

    # Test categorization
    # @param subreddit [String] Subreddit name
    # @return [Hash] Debug info
    def debug_category(subreddit)
      category = categorize_subreddit(subreddit)
      fallback = get_fallback(subreddit, randomize: false)

      {
        subreddit:,
        category:,
        fallback:,
        all_fallbacks: get_category_fallbacks(category)
      }
    end
  end
end

# Usage:
#
# # Get random fallback for funny subreddit
# ImageFallbackService.get_fallback('r/funny') 
# # => "/images/funny2.jpeg"
#
# # Get first fallback (deterministic)
# ImageFallbackService.get_fallback('r/jokes', randomize: false)
# # => "/images/funny1.jpeg"
#
# # Debug categorization
# ImageFallbackService.debug_category('r/GetMotivated')
# # => { subreddit: 'r/GetMotivated', category: 'selfcare', fallback: '/images/selfcare1.jpeg', ... }
