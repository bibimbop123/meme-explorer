# Collaborative Filtering Service - Phase 2
# "Users who liked this also liked..." recommendations
# Created: June 3, 2026

class CollaborativeFilteringService
  MIN_COMMON_LIKES = 3  # Minimum overlap to consider users similar
  MAX_SIMILAR_USERS = 10
  CACHE_TTL = 1800  # 30 minutes
  
  class << self
    # Find users with similar taste
    def find_similar_users(user_id, limit: MAX_SIMILAR_USERS)
      return [] unless user_id && defined?(DB)
      
      # Check cache first
      cache_key = "similar_users:#{user_id}"
      if defined?(RedisService)
        cached = RedisService.get(cache_key)
        return JSON.parse(cached) if cached
      end
      
      # Get user's liked memes
      user_likes = get_user_likes(user_id)
      return [] if user_likes.size < 5  # Need minimum history
      
      # Find users with overlapping likes
      similar = DB.execute(
        "SELECT ulm.user_id, COUNT(*) as overlap
         FROM user_liked_memes ulm
         WHERE ulm.meme_url IN (?)
         AND ulm.user_id != ?
         GROUP BY ulm.user_id
         HAVING COUNT(*) >= ?
         ORDER BY overlap DESC
         LIMIT ?",
        [user_likes, user_id, MIN_COMMON_LIKES, limit]
      )
      
      # Cache results
      if defined?(RedisService)
        RedisService.setex(cache_key, CACHE_TTL, similar.to_json)
      end
      
      similar
    rescue => e
      log_error("Find similar users error for user #{user_id}", e)
      []
    end
    
    # Get personalized recommendations based on similar users
    def get_recommendations(user_id, limit: 20)
      return [] unless user_id
      
      # Check cache first
      cache_key = "recommendations:#{user_id}"
      if defined?(RedisService)
        cached = RedisService.get(cache_key)
        return JSON.parse(cached) if cached
      end
      
      # Find similar users
      similar_users = find_similar_users(user_id)
      return [] if similar_users.empty?
      
      # Get user's already-liked memes (to exclude)
      user_likes = get_user_likes(user_id)
      
      # Get memes liked by similar users
      similar_user_ids = similar_users.map { |u| u['user_id'] }
      
      recommendations = DB.execute(
        "SELECT m.url, m.title, m.subreddit, m.quality_score,
                COUNT(*) as recommendation_score
         FROM user_liked_memes ulm
         JOIN meme_stats m ON ulm.meme_url = m.url
         WHERE ulm.user_id IN (?)
         AND ulm.meme_url NOT IN (?)
         GROUP BY m.url, m.title, m.subreddit, m.quality_score
         ORDER BY recommendation_score DESC, m.quality_score DESC
         LIMIT ?",
        [similar_user_ids, user_likes.empty? ? [''] : user_likes, limit]
      )
      
      # Cache results
      if defined?(RedisService)
        RedisService.setex(cache_key, CACHE_TTL, recommendations.to_json)
      end
      
      recommendations
    rescue => e
      log_error("Get recommendations error for user #{user_id}", e)
      []
    end
    
    # Get collaborative score for a meme (how recommended it is)
    def collaborative_score(meme_url, user_id)
      return 0 unless user_id && meme_url
      
      similar_users = find_similar_users(user_id)
      return 0 if similar_users.empty?
      
      similar_user_ids = similar_users.map { |u| u['user_id'] }
      
      # Count how many similar users liked this meme
      result = DB.execute(
        "SELECT COUNT(*) as count
         FROM user_liked_memes
         WHERE user_id IN (?)
         AND meme_url = ?",
        [similar_user_ids, meme_url]
      ).first
      
      result ? result['count'].to_i : 0
    rescue => e
      log_error("Collaborative score error", e)
      0
    end
    
    # Boost memes array with collaborative recommendations
    def boost_recommended(memes, user_id)
      return memes unless user_id
      
      recommendations = get_recommendations(user_id, limit: 50)
      recommended_urls = recommendations.map { |r| r['url'] }.to_set
      
      # Separate into recommended and non-recommended
      recommended = memes.select { |m| recommended_urls.include?(m['url']) }
      others = memes.reject { |m| recommended_urls.include?(m['url']) }
      
      # Interleave: 2 recommended, 3 others
      result = []
      while recommended.any? || others.any?
        result.concat(recommended.shift(2))
        result.concat(others.shift(3))
      end
      
      result.compact
    rescue => e
      log_error("Boost recommended error", e)
      memes
    end
    
    # Get taste profile summary for a user
    def taste_profile(user_id)
      return {} unless user_id && defined?(DB)
      
      # Top subreddits
      top_subreddits = DB.execute(
        "SELECT m.subreddit, COUNT(*) as count
         FROM user_liked_memes ulm
         JOIN meme_stats m ON ulm.meme_url = m.url
         WHERE ulm.user_id = ?
         GROUP BY m.subreddit
         ORDER BY count DESC
         LIMIT 5",
        [user_id]
      )
      
      # Similar users count
      similar_users = find_similar_users(user_id)
      
      # Recommendation stats
      recommendations = get_recommendations(user_id, limit: 100)
      
      {
        top_subreddits: top_subreddits,
        similar_users_count: similar_users.size,
        available_recommendations: recommendations.size,
        total_likes: get_user_likes(user_id).size
      }
    rescue => e
      log_error("Taste profile error for user #{user_id}", e)
      {}
    end
    
    private
    
    # Get all memes liked by a user
    def get_user_likes(user_id)
      return [] unless defined?(DB)
      
      result = DB.execute(
        "SELECT meme_url FROM user_liked_memes WHERE user_id = ?",
        [user_id]
      )
      
      result.map { |r| r['meme_url'] }
    rescue => e
      log_error("Get user likes error for user #{user_id}", e)
      []
    end
    
    # Centralized error logging
    def log_error(context, error)
      message = error.is_a?(String) ? error : error.message
      puts "⚠️  [CollaborativeFiltering] #{context}: #{message}"
      
      if defined?(Sentry) && error.is_a?(Exception)
        Sentry.capture_exception(error, extra: { context: context })
      end
    end
  end
end
