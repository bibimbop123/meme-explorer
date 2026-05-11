# Simplified TrendingService - uses API memes from cache
class TrendingServiceSimple
  class << self
    def trending_memes(time_window: '24h', sort_by: 'trending', limit: 20, cursor: nil)
      begin
        # Get all memes from cache
        all_memes = get_all_cache_memes(time_window, sort_by)
        
        # Fallback to database if cache is empty
        if all_memes.empty?
          puts "⚠️ [TRENDING] Cache empty, trying database"
          all_memes = get_db_memes(time_window, sort_by, 100)
        end
        
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
      rescue => e
        puts "❌ [TRENDING SERVICE] Error: #{e.message}"
        puts "   Backtrace: #{e.backtrace.first(3).join("\n   ")}"
        # Return empty result on error
        {
          memes: [],
          pagination: { has_more: false, next_cursor: nil, total: 0 }
        }
      end
    end
    
    private
    
    def get_all_cache_memes(time_window, sort_by)
      # Get API memes from cache - use consistent access pattern
      cache_memes = nil
      
      if defined?(::MemeExplorer) && defined?(::MemeExplorer::MEME_CACHE)
        begin
          cache_memes = ::MemeExplorer::MEME_CACHE.get(:memes)
        rescue => e
          puts "⚠️ [TRENDING] Cache access error: #{e.message}"
        end
      end
      
      cache_memes ||= []
      
      # Ensure we have an array
      unless cache_memes.is_a?(Array)
        puts "⚠️ [TRENDING] Cache memes is not an array: #{cache_memes.class}"
        cache_memes = []
      end
      
      # Apply sorting
      sorted_memes = case sort_by
      when 'latest'
        cache_memes.reverse  # Assuming cache is ordered, reverse for latest
      when 'most_liked'
        cache_memes.sort_by { |m| -(m['likes'] || 0).to_i }
      when 'rising'
        cache_memes.shuffle(random: Random.new(time_window.hash + 1))
      else # 'trending' - default
        cache_memes.shuffle(random: Random.new(time_window.hash))
      end
      
      # Convert ALL memes to API format (pagination handled in main method)
      result = sorted_memes.map do |m|
        next nil unless m.is_a?(Hash)
        
        url = m['url'] || m['file']
        next nil unless url  # Skip memes without URLs
        
        {
          id: url,
          title: m['title'] || 'Untitled Meme',
          subreddit: m['subreddit'] || 'local',
          likes: (m['likes'] || 0).to_i,
          views: (m['views'] || 0).to_i,
          url: url,
          image_url: url,
          created_at: (m['created_at'] || Time.now).to_s,
          trending_score: calculate_simple_score(m),
          badge: determine_badge(m)
        }
      end
      
      result.compact.select { |m| m[:url] && !m[:url].empty? }
    end
    
    def calculate_simple_score(meme)
      likes = (meme['likes'] || 0).to_i
      views = (meme['views'] || 0).to_i
      (likes * 2.0) + (views * 0.1)
    end
    
    def determine_badge(meme)
      likes = (meme['likes'] || 0).to_i
      if likes > 100
        'trending_now'
      elsif likes > 50
        'hot'
      else
        nil
      end
    end
    
    def get_db_memes(time_window, sort_by, limit)
      # Access database
      db = defined?(::DB) ? ::DB : (defined?(::MemeExplorer::DB) ? ::MemeExplorer::DB : nil)
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
      
      # Query database with proper error handling
      begin
        # Use ORDER BY with proper scoring
        order_clause = case sort_by
        when 'latest'
          'updated_at DESC'
        when 'most_liked'
          'likes DESC'
        else
          '(likes * 2 + views) DESC'
        end
        
        rows = db.execute(
          "SELECT * FROM meme_stats WHERE datetime(updated_at) >= datetime(?) ORDER BY #{order_clause} LIMIT ?",
          [cutoff_time.strftime('%Y-%m-%d %H:%M:%S'), limit]
        )
        
        puts "✅ [TRENDING] Found #{rows.size} memes from database"
        
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
            badge: determine_badge(row)
          }
        end
      rescue SQLite3::Exception => e
        puts "⚠️ [TRENDING] SQLite error: #{e.message}"
        []
      rescue => e
        puts "⚠️ [TRENDING] Database error: #{e.class} - #{e.message}"
        []
      end
    end
  end
end
