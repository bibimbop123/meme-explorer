# Simplified TrendingService - uses API memes from cache
class TrendingServiceSimple
  class << self
    def trending_memes(time_window: '24h', sort_by: 'trending', limit: 20, cursor: nil)
      # Get all memes from cache
      all_memes = get_all_cache_memes(time_window, sort_by)
      
      # Calculate pagination
      start_index = (cursor && !cursor.to_s.strip.empty?) ? cursor.to_i : 0
      paginated_memes = all_memes[start_index, limit] || []
      next_cursor = (start_index + limit < all_memes.length) ? (start_index + limit).to_s : nil
      
      # Return formatted response
      {
        memes: paginated_memes,
        pagination: {
          has_more: !next_cursor.nil?,
          next_cursor: next_cursor,
          total: all_memes.length
        }
      }
    end
    
    private
    
    def get_all_cache_memes(time_window, sort_by)
      # Get API memes from cache
      cache_memes = defined?(::MemeExplorer) ? ::MemeExplorer::MEME_CACHE.get(:memes) : nil
      cache_memes ||= []
      
      # Shuffle for variety if sorting by trending (deterministic per time window)
      if sort_by == 'trending'
        cache_memes = cache_memes.shuffle(random: Random.new(time_window.hash))
      end
      
      # Convert ALL memes to API format (pagination handled in main method)
      result = cache_memes.map do |m|
        {
          id: m['url'] || m['file'],
          title: m['title'] || 'Untitled',
          subreddit: m['subreddit'] || 'local',
          likes: (m['likes'] || 0).to_i,
          views: 0,
          url: m['url'] || m['file'],
          image_url: m['url'] || m['file'],
          created_at: Time.now.iso8601,
          trending_score: 1.0,
          badge: nil
        }
      end
      
      result.compact.select { |m| m[:url] }
    end
    
    def get_db_memes(time_window, sort_by, limit)
      # Access database
      db = defined?(::DB) ? ::DB : nil
      return [] unless db
      
      # Calculate time cutoff
      cutoff_time = case time_window
      when '1h'
        Time.now - 3600
      when '24h'
        Time.now - (24 * 3600)
      when '7d'
        Time.now - (7 * 24 * 3600)
      else
        Time.now - (30 * 24 * 3600)
      end
      
      # Query database
      begin
        rows = db.execute(
          "SELECT * FROM meme_stats WHERE datetime(updated_at) >= datetime(?) ORDER BY (likes * 2 + views) DESC LIMIT ?",
          [cutoff_time.strftime('%Y-%m-%d %H:%M:%S'), limit]
        )
        
        # Convert to API format
        rows.map do |row|
          {
            id: row['url'],
            title: row['title'] || 'Untitled',
            subreddit: row['subreddit'] || 'unknown',
            likes: (row['likes'] || 0).to_i,
            views: (row['views'] || 0).to_i,
            url: row['url'],
            image_url: row['url'],
            created_at: row['updated_at'] || Time.now.iso8601,
            trending_score: ((row['likes'] || 0).to_i * 2 + (row['views'] || 0).to_i).to_f,
            badge: nil
          }
        end
      rescue => e
        puts "⚠️ [TRENDING] Database query error: #{e.message}"
        []
      end
    end
  end
end
