# Phase 2: Preference Tracker Service
# Tracks user genre preferences and enables smart genre biasing

class PreferenceTracker
  STORAGE_KEY = 'preference_data'
  DEFAULT_BIAS_WEIGHT = 0.6  # 60% preferred, 40% random

  def initialize
    @data = load_from_storage
  end

  # Record a user's like action for tracking genre preference
  def record_like(genre, weight = 1)
    @data['genre_weights'] ||= {}
    @data['genre_weights'][genre.to_s] ||= 0
    @data['genre_weights'][genre.to_s] += weight
    @data['total_likes'] = (@data['total_likes'] || 0) + 1
    @data['last_updated'] = Time.now.to_i
    save_to_storage
  end

  # Get weighted genres for smart biasing
  # Returns array with weighted probability distribution
  def get_weighted_genres(all_genres)
    weights = @data['genre_weights'] || {}
    
    if weights.empty?
      # No preference data yet, return all genres equally
      return all_genres
    end

    # Calculate total likes to determine preference strength
    total_likes = weights.values.sum
    minimum_likes_for_bias = 3

    if total_likes < minimum_likes_for_bias
      # Not enough data yet, return all genres
      return all_genres
    end

    # Build weighted selection pool
    weighted_pool = []
    
    # Add preferred genres (60% of pool)
    preferred_count = (all_genres.count * DEFAULT_BIAS_WEIGHT).ceil
    sorted_genres = weights.sort_by { |_, count| -count }.map { |genre, _| genre }
    
    preferred_count.times do |i|
      weighted_pool << sorted_genres[i % sorted_genres.count]
    end

    # Add random genres (40% of pool)
    random_count = all_genres.count - preferred_count
    random_count.times do
      weighted_pool << all_genres.sample
    end

    weighted_pool.shuffle
  end

  # Get user's top preferred genre
  def get_favorite_genre
    weights = @data['genre_weights'] || {}
    return nil if weights.empty?
    
    weights.max_by { |_, count| count }[0]
  end

  # Get genre preference percentages
  def get_genre_breakdown
    weights = @data['genre_weights'] || {}
    return {} if weights.empty?

    total = weights.values.sum.to_f
    weights.transform_values { |count| (count / total * 100).round(1) }
  end

  # Clear preference data (for testing or user reset)
  def clear
    @data = {
      'genre_weights' => {},
      'total_likes' => 0,
      'created_at' => Time.now.to_i
    }
    save_to_storage
  end

  # Check if user has enough preference data
  def has_sufficient_data?
    total_likes = @data['total_likes'] || 0
    total_likes >= 3  # Minimum threshold
  end

  # Export data for analytics
  def export_analytics
    {
      genre_breakdown: get_genre_breakdown,
      favorite_genre: get_favorite_genre,
      total_likes: @data['total_likes'] || 0,
      has_bias: has_sufficient_data?,
      last_updated: @data['last_updated']
    }
  end

  private

  def load_from_storage
    # In production, load from localStorage (client-side) or database
    JSON.parse(localStorage_get(STORAGE_KEY) || '{}')
  rescue
    { 'genre_weights' => {}, 'total_likes' => 0 }
  end

  def save_to_storage
    localStorage_set(STORAGE_KEY, @data.to_json)
  end

  # Mock localStorage methods (implement with actual storage)
  def localStorage_get(key)
    # TODO: Replace with actual localStorage call
    nil
  end

  def localStorage_set(key, value)
    # TODO: Replace with actual localStorage call
  end
end
