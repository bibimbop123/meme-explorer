# Phase 2: Stats Tracker Service
# Tracks detailed user statistics for dashboard and profile display

class StatsTracker
  STORAGE_KEY = 'user_stats'

  def initialize
    @data = load_from_storage
    @session_start = Time.now.to_i
  end

  # Record a meme like
  def record_like(genre)
    @data['lifetime'] ||= {}
    @data['lifetime']['total_likes'] ||= 0
    @data['lifetime']['total_likes'] += 1

    # Genre breakdown
    @data['lifetime']['genres'] ||= {}
    @data['lifetime']['genres'][genre.to_s] ||= 0
    @data['lifetime']['genres'][genre.to_s] += 1

    # Session stats
    @data['current_session'] ||= {}
    @data['current_session']['memes_liked'] ||= 0
    @data['current_session']['memes_liked'] += 1

    save_to_storage
  end

  # Record session meme view
  def record_view
    @data['lifetime'] ||= {}
    @data['lifetime']['total_views'] ||= 0
    @data['lifetime']['total_views'] += 1

    @data['current_session'] ||= {}
    @data['current_session']['memes_viewed'] ||= 0
    @data['current_session']['memes_viewed'] += 1
  end

  # Get lifetime statistics
  def get_lifetime_stats
    @data['lifetime'] || {}
  end

  # Get current session statistics
  def get_session_stats
    @data['current_session'] || {}
  end

  # Get genre preference breakdown with percentages
  def get_genre_breakdown
    genres = @data['lifetime']&.[]('genres') || {}
    total = genres.values.sum.to_f

    return {} if total.zero?

    genres.transform_values do |count|
      {
        count: count,
        percentage: ((count / total) * 100).round(1)
      }
    end
  end

  # Get favorite genre
  def get_favorite_genre
    genres = @data['lifetime']&.[]('genres') || {}
    return nil if genres.empty?

    genres.max_by { |_, count| count }[0]
  end

  # Calculate engagement metrics
  def get_engagement_metrics
    lifetime = @data['lifetime'] || {}
    session = @data['current_session'] || {}

    total_views = lifetime['total_views'] || 0
    total_likes = lifetime['total_likes'] || 0
    like_rate = total_views.zero? ? 0 : ((total_likes.to_f / total_views) * 100).round(1)

    session_views = session['memes_viewed'] || 0
    session_likes = session['memes_liked'] || 0
    session_like_rate = session_views.zero? ? 0 : ((session_likes.to_f / session_views) * 100).round(1)

    {
      lifetime: {
        total_views: total_views,
        total_likes: total_likes,
        like_rate: like_rate
      },
      session: {
        views: session_views,
        likes: session_likes,
        like_rate: session_like_rate
      }
    }
  end

  # Get comprehensive stats for profile
  def get_profile_stats
    {
      lifetime: get_lifetime_stats,
      session: get_session_stats,
      engagement: get_engagement_metrics,
      genres: get_genre_breakdown,
      favorite_genre: get_favorite_genre,
      export_date: Time.now.to_i
    }
  end

  # Reset session stats (called when user starts new session)
  def reset_session
    @data['current_session'] = {}
    @session_start = Time.now.to_i
    save_to_storage
  end

  # Export all data for analytics
  def export_analytics
    {
      profile_stats: get_profile_stats,
      data_version: 2,
      generated_at: Time.now.to_i
    }
  end

  private

  def load_from_storage
    JSON.parse(localStorage_get(STORAGE_KEY) || '{}')
  rescue
    { 'lifetime' => {}, 'current_session' => {} }
  end

  def save_to_storage
    localStorage_set(STORAGE_KEY, @data.to_json)
  end

  def localStorage_get(key)
    # TODO: Replace with actual storage implementation
    nil
  end

  def localStorage_set(key, value)
    # TODO: Replace with actual storage implementation
  end
end
