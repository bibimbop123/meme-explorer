# Sitemap generation for SEO
# Generates XML sitemap for search engines

class MemeExplorer < Sinatra::Base
  
  # XML Sitemap for Google
  get '/sitemap.xml' do
    content_type 'application/xml'
    
    @base_url = if ENV['RACK_ENV'] == 'production'
      'https://meme-explorer.onrender.com'
    else
      "http://localhost:#{ENV.fetch('PORT', 8080)}"
    end
    
    @urls = []
    
    # Homepage (highest priority)
    @urls << {
      loc: @base_url,
      changefreq: 'daily',
      priority: '1.0',
      lastmod: Time.now.strftime('%Y-%m-%d')
    }
    
    # Main pages
    main_pages = [
      { path: '/random', priority: '0.9' },
      { path: '/trending', priority: '0.9' },
      { path: '/search', priority: '0.8' },
      { path: '/leaderboard', priority: '0.7' }
    ]
    
    main_pages.each do |page|
      @urls << {
        loc: "#{@base_url}#{page[:path]}",
        changefreq: 'daily',
        priority: page[:priority],
        lastmod: Time.now.strftime('%Y-%m-%d')
      }
    end
    
    # Get meme data for individual pages
    # If you have meme detail pages, add them here
    begin
      # Example: Top 100 trending memes get their own pages
      trending_memes = DB.execute("
        SELECT url, updated_at 
        FROM meme_stats 
        ORDER BY (likes * 2 + views) DESC 
        LIMIT 100
      ")
      
      trending_memes.each do |meme|
        # Create URL-friendly slug from meme URL
        meme_id = Digest::MD5.hexdigest(meme['url'])[0..7]
        
        @urls << {
          loc: "#{@base_url}/memes/#{meme_id}",
          changefreq: 'weekly',
          priority: '0.6',
          lastmod: meme['updated_at'] || Time.now.strftime('%Y-%m-%d')
        }
      end
    rescue => e
      puts "⚠️ Error fetching memes for sitemap: #{e.message}"
    end
    
    # Generate XML
    builder = Nokogiri::XML::Builder.new(encoding: 'UTF-8') do |xml|
      xml.urlset(xmlns: 'http://www.sitemaps.org/schemas/sitemap/0.9') {
        @urls.each do |url|
          xml.url {
            xml.loc url[:loc]
            xml.lastmod url[:lastmod]
            xml.changefreq url[:changefreq]
            xml.priority url[:priority]
          }
        end
      }
    end
    
    builder.to_xml
  rescue => e
    puts "❌ Sitemap generation error: #{e.message}"
    halt 500, "Error generating sitemap"
  end
  
  # Human-readable sitemap
  get '/sitemap' do
    @base_url = if ENV['RACK_ENV'] == 'production'
      'https://meme-explorer.onrender.com'
    else
      "http://localhost:#{ENV.fetch('PORT', 8080)}"
    end
    
    @pages = [
      { name: 'Home', url: '/', description: 'Discover the funniest memes on the internet' },
      { name: 'Random Memes', url: '/random', description: 'Infinite scroll of random memes' },
      { name: 'Trending', url: '/trending', description: 'Top trending memes right now' },
      { name: 'Search', url: '/search', description: 'Find memes by keyword' },
      { name: 'Leaderboard', url: '/leaderboard', description: 'Top meme explorers' }
    ]
    
    erb :'sitemap_page'
  end
  
end
