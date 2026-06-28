# routes/seo_routes.rb
# SEO-specific routes: sitemap.xml, robots.txt, etc.
#
# These routes help search engines discover and index your content

module Routes
  module Seo
    def self.registered(app)
      
      # ============================================
      # ROBOTS.TXT
      # ============================================
      # Tells search engines what they can and cannot crawl
      app.get "/robots.txt" do
        content_type "text/plain"
        
        base_url = "#{request.scheme}://#{request.host_with_port}"
        
        <<~ROBOTS
          # Meme Explorer - Robots.txt
          # Allow all ethical search engines to crawl our content
          
          User-agent: *
          Allow: /
          Allow: /trending
          Allow: /random
          Allow: /leaderboard
          Allow: /search
          
          # Disallow sensitive/dynamic areas
          Disallow: /admin
          Disallow: /api/
          Disallow: /logout
          Disallow: /login
          Disallow: /signup
          Disallow: /profile
          
          # Crawl rate (be gentle)
          Crawl-delay: 1
          
          # Sitemap location
          Sitemap: #{base_url}/sitemap.xml
          
          # Popular search engine specific rules
          User-agent: Googlebot
          Allow: /
          Crawl-delay: 0.5
          
          User-agent: Bingbot
          Allow: /
          Crawl-delay: 1
          
          # Block bad bots
          User-agent: AhrefsBot
          Crawl-delay: 10
          
          User-agent: SemrushBot
          Crawl-delay: 10
        ROBOTS
      end
      
      # ============================================
      # SITEMAP.XML
      # ============================================
      # Helps search engines discover all pages on your site
      app.get "/sitemap.xml" do
        content_type "application/xml"
        
        base_url = "#{request.scheme}://#{request.host_with_port}"
        now = Time.now.utc.strftime("%Y-%m-%d")
        
        # Define priority and change frequency for different page types
        pages = [
          # High priority pages (updated frequently)
          { path: "/", priority: "1.0", changefreq: "hourly", lastmod: now },
          { path: "/trending", priority: "0.9", changefreq: "hourly", lastmod: now },
          { path: "/random", priority: "0.8", changefreq: "always", lastmod: now },
          { path: "/leaderboard", priority: "0.7", changefreq: "daily", lastmod: now },
          { path: "/search", priority: "0.6", changefreq: "weekly", lastmod: now },
          
          # Static/less frequently updated pages
          { path: "/metrics", priority: "0.5", changefreq: "daily", lastmod: now }
        ]
        
        # Add top subreddits as separate pages (if you have category routes)
        begin
          subreddits_file = File.join(settings.root, "data", "subreddits.yml")
          if File.exist?(subreddits_file)
            subreddits_data = YAML.load_file(subreddits_file, aliases: true)
            
            # Extract subreddits from nested structure (tier_1, tier_2, etc.)
            top_subreddits = []
            if subreddits_data.is_a?(Hash)
              # Get from 'popular' key if it exists, or flatten all tiers
              if subreddits_data['popular']
                top_subreddits = subreddits_data['popular'].first(10)
              else
                # Flatten all tiers
                subreddits_data.each do |key, value|
                  if value.is_a?(Array)
                    top_subreddits.concat(value)
                  end
                end
                top_subreddits = top_subreddits.first(10)
              end
            elsif subreddits_data.is_a?(Array)
              top_subreddits = subreddits_data.first(10)
            end
            
            top_subreddits.each do |sub|
              next unless sub.is_a?(String)
              pages << {
                path: "/category/#{sub.downcase}",
                priority: "0.6",
                changefreq: "daily",
                lastmod: now
              }
            end
          end
        rescue => e
          # Silently continue if subreddits can't be loaded
          AppLogger.warn("⚠️  Could not load subreddits for sitemap: #{e.message}")
        end
        
        # Build XML sitemap
        xml = []
        xml << '<?xml version="1.0" encoding="UTF-8"?>'
        xml << '<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">'
        
        pages.each do |page|
          xml << "  <url>"
          xml << "    <loc>#{base_url}#{page[:path]}</loc>"
          xml << "    <lastmod>#{page[:lastmod]}</lastmod>"
          xml << "    <changefreq>#{page[:changefreq]}</changefreq>"
          xml << "    <priority>#{page[:priority]}</priority>"
          xml << "  </url>"
        end
        
        xml << "</urlset>"
        
        xml.join("\n")
      end
      
      # ============================================
      # HUMANS.TXT
      # ============================================
      # A fun file that credits the team behind the website
      app.get "/humans.txt" do
        content_type "text/plain"
        
        <<~HUMANS
          /* TEAM */
          
          Developer: Meme Explorer Team
          Site: https://github.com/bibimbop123/meme-explorer
          Location: Internet
          
          /* THANKS */
          
          Reddit API
          Tattoo Annie from The Simpsons
          All meme creators and communities
          
          /* SITE */
          
          Last update: #{Time.now.strftime("%Y-%m-%d")}
          Language: English
          Doctype: HTML5
          IDE: Visual Studio Code
          Framework: Sinatra (Ruby)
          Standards: HTML5, CSS3, ES6+
          Components: PostgreSQL, Redis, Sidekiq
          Software: Ruby, JavaScript, ERB
        HUMANS
      end
      
      # ============================================
      # SECURITY.TXT
      # ============================================
      # Provides security researchers with contact information
      app.get "/.well-known/security.txt" do
        content_type "text/plain"
        
        <<~SECURITY
          Contact: mailto:security@meme-explorer.com
          Expires: #{(Time.now + (365 * 24 * 60 * 60)).utc.strftime("%Y-%m-%dT%H:%M:%S.000Z")}
          Preferred-Languages: en
          Canonical: #{request.base_url}/.well-known/security.txt
          
          # If you discover a security vulnerability, please report it to us!
          # We appreciate responsible disclosure.
        SECURITY
      end
      
      # ============================================
      # ADS.TXT (for AdSense)
      # ============================================
      # Authorized Digital Sellers declaration for programmatic advertising
      app.get "/ads.txt" do
        content_type "text/plain"
        
        # Only serve if Google AdSense is configured
        if ENV['GOOGLE_ADSENSE_CLIENT']
          publisher_id = ENV['GOOGLE_ADSENSE_CLIENT'].gsub('ca-pub-', '')
          
          <<~ADSTXT
            # Authorized Digital Sellers for Meme Explorer
            # Google AdSense
            google.com, pub-#{publisher_id}, DIRECT, f08c47fec0942fa0
          ADSTXT
        else
          status 404
          "# AdSense not configured"
        end
      end
      
      # ============================================
      # MANIFEST.JSON enhancement endpoint
      # ============================================
      # Dynamic PWA manifest with proper metadata
      app.get "/manifest.json" do
        content_type "application/json"
        
        base_url = "#{request.scheme}://#{request.host_with_port}"
        
        manifest = {
          name: "Meme Explorer",
          short_name: "Memes",
          description: "Discover the best memes from Reddit! Trending content, AI recommendations, and endless entertainment.",
          start_url: "/",
          display: "standalone",
          background_color: "#fefefe",
          theme_color: "#e52e71",
          orientation: "any",
          scope: "/",
          icons: [
            {
              src: "#{base_url}/images/favicon.png",
              sizes: "192x192",
              type: "image/png",
              purpose: "any maskable"
            },
            {
              src: "#{base_url}/images/favicon.png",
              sizes: "512x512",
              type: "image/png",
              purpose: "any maskable"
            }
          ],
          categories: ["entertainment", "social", "lifestyle"],
          lang: "en-US",
          dir: "ltr",
          screenshots: [
            {
              src: "#{base_url}/images/meme-placeholder.svg",
              sizes: "600x600",
              type: "image/svg+xml"
            }
          ]
        }
        
        JSON.pretty_generate(manifest)
      end
      
      # ============================================
      # OPENSEARCH.XML
      # ============================================
      # Allows browsers to add site as search engine
      app.get "/opensearch.xml" do
        content_type "application/opensearchdescription+xml"
        
        base_url = "#{request.scheme}://#{request.host_with_port}"
        
        <<~OPENSEARCH
          <?xml version="1.0" encoding="UTF-8"?>
          <OpenSearchDescription xmlns="http://a9.com/-/spec/opensearch/1.1/">
            <ShortName>Meme Explorer</ShortName>
            <Description>Search for memes on Meme Explorer</Description>
            <Tags>memes reddit funny humor</Tags>
            <Contact>admin@meme-explorer.com</Contact>
            <Url type="text/html" template="#{base_url}/search?q={searchTerms}"/>
            <Url type="application/x-suggestions+json" template="#{base_url}/api/search-suggestions?q={searchTerms}"/>
            <Image height="16" width="16" type="image/png">#{base_url}/images/favicon.png</Image>
            <InputEncoding>UTF-8</InputEncoding>
            <SearchForm>#{base_url}/search</SearchForm>
          </OpenSearchDescription>
        OPENSEARCH
      end
      
    end
  end
end
