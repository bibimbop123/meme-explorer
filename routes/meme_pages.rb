# Individual meme landing pages for SEO
# Each popular meme gets its own page for search ranking

class MemeExplorer < Sinatra::Base
  # Individual meme page (SEO landing page)
  get '/memes/:meme_id' do
    @meme_id = params[:meme_id]
    
    # Try to find meme by ID or slug
    begin
      @meme = DB.execute("
        SELECT * FROM meme_stats 
        WHERE url LIKE ? 
        ORDER BY (likes * 2 + views) DESC 
        LIMIT 1
      ", ["%#{@meme_id}%"]).first
      
      # If no meme found, get a random popular one
      @meme ||= DB.execute("
        SELECT * FROM meme_stats 
        ORDER BY (likes * 2 + views) DESC 
        LIMIT 1
      ").first
      
      # Get related memes (same subreddit)
      if @meme
        @related_memes = DB.execute("
          SELECT * FROM meme_stats 
          WHERE subreddit = ? AND url != ? 
          ORDER BY (likes * 2 + views) DESC 
          LIMIT 10
        ", [@meme['subreddit'], @meme['url']])
      end
      
      # SEO metadata
      @page_title = @meme ? "#{@meme['title']} | Meme Explorer" : "Meme Explorer"
      @page_description = @meme ? "#{@meme['title']} - Trending meme from r/#{@meme['subreddit']}. #{@meme['views']} views, #{@meme['likes']} likes." : "Discover funny memes"
      @og_image = @meme ? @meme['url'] : nil
      
      erb :'meme_page'
    rescue => e
      puts "⚠️ Error loading meme page: #{e.message}"
      redirect '/random'
    end
  end
  
  # Meme category pages for SEO
  get '/memes/category/:category' do
    @category = params[:category].downcase
    @page = (params[:page] || 1).to_i
    @per_page = 20
    @offset = (@page - 1) * @per_page
    
    begin
      # Get memes from this category (subreddit)
      @memes = DB.execute("
        SELECT * FROM meme_stats 
        WHERE LOWER(subreddit) = ? 
        ORDER BY (likes * 2 + views) DESC 
        LIMIT ? OFFSET ?
      ", [@category, @per_page, @offset])
      
      # Get total count for pagination
      @total = DB.execute("
        SELECT COUNT(*) as count FROM meme_stats 
        WHERE LOWER(subreddit) = ?
      ", [@category]).first['count']
      
      @total_pages = (@total.to_f / @per_page).ceil
      
      # SEO metadata
      @page_title = "Best #{@category.capitalize} Memes | Meme Explorer"
      @page_description = "Discover the funniest #{@category} memes. #{@total} memes and counting!"
      
      erb :'meme_category'
    rescue => e
      puts "⚠️ Error loading category page: #{e.message}"
      redirect '/trending'
    end
  end
  
  # Popular meme formats (for SEO)
  get '/meme-formats' do
    @page_title = "Popular Meme Formats | Meme Explorer"
    @page_description = "Browse all popular meme formats and templates. Find the perfect meme format for any situation!"
    
    # Get top subreddits as "formats"
    @formats = DB.execute("
      SELECT subreddit, COUNT(*) as count, SUM(likes) as total_likes 
      FROM meme_stats 
      GROUP BY subreddit 
      ORDER BY total_likes DESC 
      LIMIT 50
    ").map do |row|
      {
        name: row['subreddit'],
        count: row['count'],
        likes: row['total_likes'],
        slug: row['subreddit'].downcase
      }
    end rescue []
    
    erb :'meme_formats'
  end
  
end
