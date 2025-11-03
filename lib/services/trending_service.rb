require 'redis'

class TrendingService
  REDIS = Redis.new(url: ENV['REDIS_URL'] || 'redis://localhost:6379/0')
  CACHE_TTL = 5 * 60
  DECAY_HALF_LIFE = 7 * 24 * 60 * 60
  
  LIKES_WEIGHT = 1.0
  VIEWS_WEIGHT = 0.1
  COMMENTS_WEIGHT = 0.5
  
  class << self
    def calculate_score(meme)
      age_seconds = (Time.current - meme.created_at).to_i
      decay_factor = Math.exp(-Math.log(2) * age_seconds / DECAY_HALF_LIFE)
      
      likes_score = (meme.likes || 0) * LIKES_WEIGHT * decay_factor
      views_score = (meme.views || 0) * VIEWS_WEIGHT
      comments_score = (meme.comments_count || 0) * COMMENTS_WEIGHT * decay_factor
      
      likes_score + views_score + comments_score
    end
    
    def trending_memes(time_window: '24h', sort_by: 'trending', limit: 20, cursor: nil)
      cache_key = "trending:#{time_window}:#{sort_by}"
      cached_result = REDIS.get(cache_key) rescue nil
      
      if cached_result.present?
        memes = JSON.parse(cached_result)
        return paginate_results(memes, limit, cursor)
      end
      
      cutoff_time = time_cutoff(time_window)
      memes = Meme.where('created_at >= ?', cutoff_time).to_a
      
      memes_with_scores = memes.map do |meme|
        {
          id: meme.id,
          title: meme.title,
          subreddit: meme.subreddit,
          likes: meme.likes || 0,
          views: meme.views || 0,
          created_at: meme.created_at.iso8601,
          trending_score: calculate_score(meme),
          badge: determine_badge(meme)
        }
      end
      
      sorted_memes = sort_memes(memes_with_scores, sort_by)
      REDIS.setex(cache_key, CACHE_TTL, sorted_memes.to_json) rescue nil
      
      paginate_results(sorted_memes, limit, cursor)
    end
    
    def invalidate_cache
      keys = REDIS.keys('trending:*') rescue []
      keys.each { |key| REDIS.del(key) } if keys.any?
    end
    
    private
    
    def time_cutoff(time_window)
      case time_window
      when '1h'
        1.hour.ago
      when '24h'
        24.hours.ago
      when '7d'
        7.days.ago
      else
        30.days.ago
      end
    end
    
    def sort_memes(memes, sort_by)
      case sort_by
      when 'trending'
        memes.sort_by { |m| -m[:trending_score] }
      when 'latest'
        memes.sort_by { |m| -Time.parse(m[:created_at]).to_i }
      when 'most_liked'
        memes.sort_by { |m| -m[:likes] }
      when 'rising'
        memes.sort_by { |m| -(m[:likes].to_f / [1, (Time.current - Time.parse(m[:created_at])).to_i / 3600.0].max) }
      else
        memes.sort_by { |m| -m[:trending_score] }
      end
    end
    
    def determine_badge(meme)
      if meme[:trending_score] > 500
        'trending_now'
      elsif meme[:likes] > 100
        'hot'
      else
        nil
      end
    end
    
    def paginate_results(memes, limit, cursor)
      start_index = cursor.present? ? cursor.to_i : 0
      paginated = memes[start_index...start_index + limit]
      next_cursor = (start_index + limit < memes.length) ? (start_index + limit).to_s : nil
      
      {
        memes: paginated || [],
        pagination: {
          has_more: next_cursor.present?,
          next_cursor: next_cursor,
          total: memes.length
        }
      }
    end
  end
end
