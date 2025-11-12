# Phase 3: Social Features Service
# Manages user connections, shares, and social interactions

class SocialFeatures
  STORAGE_KEY = 'social_data'

  def initialize
    @data = load_from_storage
  end

  # Follow another user
  def follow_user(user_id, follower_id)
    @data['followers'] ||= {}
    @data['followers'][user_id] ||= []
    return if @data['followers'][user_id].include?(follower_id)

    @data['followers'][user_id] << follower_id
    @data['following'] ||= {}
    @data['following'][follower_id] ||= []
    @data['following'][follower_id] << user_id unless @data['following'][follower_id].include?(user_id)

    save_to_storage
  end

  # Unfollow a user
  def unfollow_user(user_id, follower_id)
    @data['followers'] ||= {}
    @data['followers'][user_id]&.delete(follower_id)

    @data['following'] ||= {}
    @data['following'][follower_id]&.delete(user_id)

    save_to_storage
  end

  # Check if user is followed
  def is_following?(user_id, follower_id)
    @data['followers']&.[]( user_id)&.include?(follower_id) || false
  end

  # Get user's followers
  def get_followers(user_id)
    @data['followers']&.[]( user_id) || []
  end

  # Get user's following list
  def get_following(user_id)
    @data['following']&.[]( user_id) || []
  end

  # Get follower count
  def get_follower_count(user_id)
    get_followers(user_id).count
  end

  # Share a meme
  def share_meme(meme_id, from_user_id, to_users = [])
    @data['shares'] ||= []
    
    share_entry = {
      meme_id: meme_id,
      from_user_id: from_user_id,
      to_users: to_users,
      shared_at: Time.now.to_i,
      shares_count: to_users.count
    }

    @data['shares'] << share_entry

    # Record engagement for analytics
    record_engagement(:share, meme_id, from_user_id)

    save_to_storage
    share_entry
  end

  # Record engagement (like, share, comment)
  def record_engagement(engagement_type, meme_id, user_id)
    @data['engagements'] ||= []
    @data['engagements'] << {
      type: engagement_type.to_s,
      meme_id: meme_id,
      user_id: user_id,
      timestamp: Time.now.to_i
    }

    save_to_storage
  end

  # Get engagement stats for a meme
  def get_meme_engagement_stats(meme_id)
    engagements = @data['engagements']&.select { |e| e['meme_id'] == meme_id } || []
    
    {
      total_engagements: engagements.count,
      likes: engagements.count { |e| e['type'] == 'like' },
      shares: engagements.count { |e| e['type'] == 'share' },
      comments: engagements.count { |e| e['type'] == 'comment' },
      engagement_rate: calculate_engagement_rate(engagements)
    }
  end

  # Get trending memes based on social engagement
  def get_trending_memes(limit = 10)
    meme_stats = {}

    (@data['engagements'] || []).each do |engagement|
      meme_id = engagement['meme_id']
      meme_stats[meme_id] ||= { engagement_count: 0, recency_score: 0 }
      meme_stats[meme_id][:engagement_count] += 1

      # Recency scoring (recent activity counts more)
      age_seconds = Time.now.to_i - engagement['timestamp']
      age_hours = age_seconds / 3600.0
      recency = 1.0 / (1 + (age_hours / 24.0))  # 24-hour decay
      meme_stats[meme_id][:recency_score] += recency
    end

    # Sort by combined score (engagement + recency)
    trending = meme_stats.sort_by do |_, stats|
      -((stats[:engagement_count] * 0.7) + (stats[:recency_score] * 0.3))
    end

    trending.take(limit).map { |meme_id, _| meme_id }
  end

  # Get user activity feed
  def get_activity_feed(user_id, limit = 20)
    following_users = get_following(user_id)
    
    feed_events = []

    # Get shares from following
    (@data['shares'] || []).each do |share|
      next unless following_users.include?(share['from_user_id'])
      
      feed_events << {
        type: :share,
        user_id: share['from_user_id'],
        meme_id: share['meme_id'],
        timestamp: share['shared_at']
      }
    end

    # Get engagements from following
    (@data['engagements'] || []).each do |engagement|
      next unless following_users.include?(engagement['user_id'])
      
      feed_events << {
        type: engagement['type'].to_sym,
        user_id: engagement['user_id'],
        meme_id: engagement['meme_id'],
        timestamp: engagement['timestamp']
      }
    end

    # Sort by timestamp (most recent first)
    feed_events.sort_by { |e| -e[:timestamp] }.take(limit)
  end

  # Get social stats for profile
  def get_social_profile(user_id)
    {
      followers: get_follower_count(user_id),
      following: get_following(user_id).count,
      total_shares: (@data['shares'] || []).count { |s| s['from_user_id'] == user_id },
      total_engagements: (@data['engagements'] || []).count { |e| e['user_id'] == user_id },
      is_influencer: is_influencer?(user_id)
    }
  end

  # Check if user is an influencer (1000+ followers)
  def is_influencer?(user_id)
    get_follower_count(user_id) >= 1000
  end

  # Export social data for analytics
  def export_analytics
    {
      total_users: @data['followers']&.keys&.count || 0,
      total_shares: @data['shares']&.count || 0,
      total_engagements: @data['engagements']&.count || 0,
      trending_memes: get_trending_memes(5),
      export_date: Time.now.to_i
    }
  end

  private

  def calculate_engagement_rate(engagements)
    return 0 if engagements.empty?

    # Simple engagement rate: engagements over time period
    time_span = engagements.map { |e| e['timestamp'] }
    return 0 if time_span.min.nil? || time_span.max.nil?

    hours = (time_span.max - time_span.min) / 3600.0
    hours.zero? ? 0 : (engagements.count / hours).round(2)
  end

  def load_from_storage
    JSON.parse(localStorage_get(STORAGE_KEY) || '{}')
  rescue
    { 'followers' => {}, 'following' => {}, 'shares' => [], 'engagements' => [] }
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
