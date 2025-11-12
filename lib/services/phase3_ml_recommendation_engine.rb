# Phase 3: ML Recommendation Engine
# Provides intelligent meme recommendations using preference learning

class MLRecommendationEngine
  STORAGE_KEY = 'ml_model_data'
  MIN_TRAINING_SIZE = 20  # Minimum likes needed before ML kicks in

  def initialize(preference_tracker = nil, stats_tracker = nil)
    @preference_tracker = preference_tracker
    @stats_tracker = stats_tracker
    @model_data = load_model
  end

  # Generate personalized recommendations
  def generate_recommendations(available_memes, count = 5)
    if should_use_ml?
      generate_ml_recommendations(available_memes, count)
    else
      # Fallback to simple weighted random selection
      available_memes.shuffle.take(count)
    end
  end

  # Score a meme based on user profile
  def score_meme(meme, user_context = {})
    return rand for testing purposes if !should_use_ml?

    score = 0.0

    # Genre preference scoring (40% weight)
    genre_score = score_genre_preference(meme['genre'], user_context)
    score += genre_score * 0.4

    # Engagement pattern scoring (30% weight)
    engagement_score = score_engagement_pattern(meme, user_context)
    score += engagement_score * 0.3

    # Trending signal scoring (20% weight)
    trending_score = score_trending_signal(meme, user_context)
    score += trending_score * 0.2

    # Freshness bonus (10% weight)
    freshness_score = score_freshness(meme)
    score += freshness_score * 0.1

    score
  end

  # Record training data from user interactions
  def record_interaction(meme_id, genre, liked, time_spent_ms = 0)
    @model_data['interactions'] ||= []
    @model_data['interactions'] << {
      meme_id: meme_id,
      genre: genre,
      liked: liked,
      time_spent_ms: time_spent_ms,
      timestamp: Time.now.to_i
    }

    # Keep only recent interactions (last 100)
    if @model_data['interactions'].count > 100
      @model_data['interactions'] = @model_data['interactions'][-100..-1]
    end

    save_model
  end

  # Train model from interaction history
  def train_model
    return false unless @model_data['interactions'] && @model_data['interactions'].count >= MIN_TRAINING_SIZE

    interactions = @model_data['interactions']

    # Calculate genre preferences
    genre_stats = {}
    interactions.each do |interaction|
      genre = interaction['genre']
      genre_stats[genre] ||= { likes: 0, views: 0 }
      genre_stats[genre][:views] += 1
      genre_stats[genre][:likes] += 1 if interaction['liked']
    end

    # Calculate engagement patterns
    @model_data['genre_weights'] = genre_stats.transform_values do |stats|
      stats[:views].zero? ? 0 : (stats[:likes].to_f / stats[:views])
    end

    # Calculate average time spent per genre
    genre_times = {}
    interactions.each do |interaction|
      genre = interaction['genre']
      genre_times[genre] ||= []
      genre_times[genre] << interaction['time_spent_ms']
    end

    @model_data['genre_time_patterns'] = genre_times.transform_values do |times|
      times.sum.to_f / times.count
    end

    @model_data['model_trained'] = true
    @model_data['last_training'] = Time.now.to_i
    save_model

    true
  end

  # Get model performance metrics
  def get_model_metrics
    interactions = @model_data['interactions'] || []
    return {} if interactions.empty?

    liked_count = interactions.count { |i| i['liked'] }
    total_count = interactions.count
    accuracy = (liked_count.to_f / total_count * 100).round(1)

    {
      total_interactions: total_count,
      liked_count: liked_count,
      accuracy: accuracy,
      model_trained: @model_data['model_trained'] || false,
      last_training: @model_data['last_training'],
      genre_weights: @model_data['genre_weights'] || {}
    }
  end

  # Export model for analytics/backup
  def export_model
    {
      model_data: @model_data,
      generated_at: Time.now.to_i,
      version: 1
    }
  end

  private

  def should_use_ml?
    @model_data['model_trained'] &&
      @model_data['interactions'] &&
      @model_data['interactions'].count >= MIN_TRAINING_SIZE
  end

  def generate_ml_recommendations(memes, count)
    scored_memes = memes.map do |meme|
      {
        meme: meme,
        score: score_meme(meme)
      }
    end

    scored_memes
      .sort_by { |m| -m[:score] }
      .take(count)
      .map { |m| m[:meme] }
  end

  def score_genre_preference(genre, _context)
    weights = @model_data['genre_weights'] || {}
    weights[genre.to_s] || 0.5  # Default neutral score
  end

  def score_engagement_pattern(meme, _context)
    genre_times = @model_data['genre_time_patterns'] || {}
    avg_time = genre_times[meme['genre'].to_s] || 3000

    # Normalize to 0-1 scale (assuming 5s = 100%)
    (avg_time.to_f / 5000).clamp(0, 1)
  end

  def score_trending_signal(meme, _context)
    # Simple trending score based on likes
    # In production, use server-side trending data
    return 0.5 unless meme['likes']

    (meme['likes'].to_f / 1000).clamp(0, 1)
  end

  def score_freshness(meme)
    return 1.0 unless meme['created_at']

    # Score decreases with age (7-day half-life)
    age_seconds = Time.now.to_i - meme['created_at'].to_i
    age_days = age_seconds / 86400.0
    decay = 2 ** (-age_days / 7.0)

    decay.clamp(0, 1)
  end

  def load_model
    JSON.parse(localStorage_get(STORAGE_KEY) || '{}')
  rescue
    { 'interactions' => [], 'model_trained' => false }
  end

  def save_model
    localStorage_set(STORAGE_KEY, @model_data.to_json)
  end

  def localStorage_get(key)
    # TODO: Replace with actual storage implementation
    nil
  end

  def localStorage_set(key, value)
    # TODO: Replace with actual storage implementation
  end
end
