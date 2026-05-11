require 'redis'
require 'active_support/core_ext/time'

class TrendingService
  REDIS = begin
    Redis.new(url: ENV['REDIS_URL'] || 'redis://localhost:6379/0')
  rescue => e
    puts "⚠️ TrendingService: Redis unavailable - #{e.message}"
    nil
  end
  
  CACHE_TTL = 5 * 60
  DECAY_HALF_LIFE = 7 * 24 * 60 * 60
  
  LIKES_WEIGHT = 1.0
  VIEWS_WEIGHT = 0.1
  COMMENTS_WEIGHT = 0.5
  HUMOR_BOOST = 2.0
  RELATIONSHIP_BOOST = 3.0
  
  class << self
    def calculate_score(meme)
      # Handle both hash and row objects
      created_at = meme.is_a?(Hash) ? parse_time(meme['created_at'] || meme['updated_at']) : parse_time(meme['updated_at'])
      created_at ||= Time.now - (7 * 24 * 60 * 60) # Default to 7 days ago if no timestamp
      
      age_seconds = (Time.now - created_at).to_i
      decay_factor = Math.exp(-Math.log(2) * age_seconds / DECAY_HALF_LIFE)
      
      likes = get_value(meme, 'likes')
      views = get_value(meme, 'views')
      
      likes_score = likes * LIKES_WEIGHT * decay_factor
      views_score = views * VIEWS_WEIGHT
      
      # HUMOR & RELATIONSHIP BOOST
      content_boost = calculate_content_boost(meme)
      
      (likes_score + views_score) * content_boost
    end
    
    def get_value(meme, key)
      value = meme.is_a?(Hash) ? meme[key] : meme[key]
      (value || 0).to_i
    end
    
    def parse_time(time_str)
      return nil if time_str.nil? || time_str.to_s.strip.empty?
      Time.parse(time_str.to_s) rescue nil
    end
    
    def calculate_content_boost(meme)
      boost = 1.0
      title = (get_value(meme, 'title') || "").to_s.downcase
      subreddit = (get_value(meme, 'subreddit') || "").to_s.downcase
      
      # Relationship keywords
      relationship_keywords = ['boyfriend', 'girlfriend', 'dating', 'relationship', 'couples', 
                               'partner', 'wife', 'husband', 'marriage', 'ex', 'tinder', 
                               'crush', 'breakup', 'single', 'taken']
      boost += RELATIONSHIP_BOOST if relationship_keywords.any? { |kw| title.include?(kw) }
      
      # Humor keywords
      humor_keywords = ['funny', 'lol', 'hilarious', 'meme', 'savage', 'relatable', 
                        'mood', 'pov', 'when she', 'when he', 'be like']
      boost += HUMOR_BOOST if humor_keywords.any? { |kw| title.include?(kw) }
      
      # Subreddit boost
      priority_subs = ['funny', 'memes', 'dankmemes', 'relationships', 'relationship_memes',
                       'relationshipmemes', 'dating', 'tinder', 'me_irl', 'adviceanimals']
      boost += HUMOR_BOOST if priority_subs.include?(subreddit)
      
      boost
    end
    
    def trending_memes(time_window: '24h', sort_by: 'trending', limit: 20, cursor: nil)
      cache_key = "trending:#{time_window}:#{sort_by}"
      
      if REDIS
        cached_result = REDIS.get(cache_key) rescue nil
        if cached_result && !cached_result.empty?
          memes = JSON.parse(cached_result) rescue nil
          return paginate_results(memes, limit, cursor) if memes
        end
      end
      
      cutoff_time = time_cutoff(time_window)
      
      # Query meme_stats table directly
      memes = DB.execute(
        "SELECT * FROM meme_stats WHERE datetime(updated_at) >= datetime(?) ORDER BY updated_at DESC",
        [cutoff_time.strftime('%Y-%m-%d %H:%M:%S')]
      ) rescue []
      
      memes_with_scores = memes.map do |meme|
        {
          id: meme['url'],
          title: meme['title'] || 'Untitled',
          subreddit: meme['subreddit'] || 'local',
          likes: (meme['likes'] || 0).to_i,
          views: (meme['views'] || 0).to_i,
          url: meme['url'],
          image_url: meme['url'],
          created_at: (meme['updated_at'] || Time.now.iso8601),
          trending_score: calculate_score(meme),
          badge: determine_badge(meme)
        }
      end
      
      sorted_memes = sort_memes(memes_with_scores, sort_by)
      
      if REDIS
        REDIS.setex(cache_key, CACHE_TTL, sorted_memes.to_json) rescue nil
      end
      
      paginate_results(sorted_memes, limit, cursor)
    end
    
    def invalidate_cache
      return unless REDIS
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
        memes.sort_by { |m| -(parse_time(m[:created_at]) || Time.now).to_i }
      when 'most_liked'
        memes.sort_by { |m| -m[:likes] }
      when 'rising'
        memes.sort_by do |m|
          time_created = parse_time(m[:created_at]) || (Time.now - 86400)
          hours_old = [(Time.now - time_created).to_i / 3600.0, 1].max
          -(m[:likes].to_f / hours_old)
        end
      else
        memes.sort_by { |m| -m[:trending_score] }
      end
    end
    
    def determine_badge(meme)
      score = meme.is_a?(Hash) ? meme[:trending_score] : calculate_score(meme)
      likes = meme.is_a?(Hash) ? meme[:likes] : get_value(meme, 'likes')
      
      if score && score > 500
        'trending_now'
      elsif likes && likes > 100
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
