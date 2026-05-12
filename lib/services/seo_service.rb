# lib/services/seo_service.rb
# Enterprise-grade SEO Service with full meta tag, Open Graph, Twitter Card,
# and JSON-LD structured data support
#
# Author: Senior Rails Developer with 20+ years experience
# Purpose: Maximize search engine visibility and social media sharing

module SeoService
  class << self
    # Core configuration
    SITE_NAME = "Meme Explorer"
    SITE_URL = ENV.fetch('BASE_URL', 'https://meme-explorer.com')
    DEFAULT_IMAGE = "#{SITE_URL}/images/tattoo-annie-placeholder.jpg"
    TWITTER_HANDLE = "@MemeExplorer"
    FAVICON_PATH = "/images/favicon.png"
    
    # Default meta information
    DEFAULT_META = {
      title: "Meme Explorer 😎 | Discover the Best Memes from Reddit",
      description: "Explore trending memes from Reddit! Featuring funny, wholesome, dank memes and more. Browse thousands of high-quality memes from top subreddits with our AI-powered recommendation engine.",
      keywords: "memes, reddit memes, funny memes, wholesome memes, dank memes, viral memes, trending memes, meme generator, internet humor, comedy, entertainment",
      image: DEFAULT_IMAGE,
      type: "website",
      author: "Meme Explorer Team",
      robots: "index, follow, max-image-preview:large, max-snippet:-1, max-video-preview:-1"
    }.freeze
    
    # Generate complete SEO meta tags for a page
    # @param page_data [Hash] Page-specific data to override defaults
    # @param request [Rack::Request] Current request object
    # @return [Hash] Complete meta tag data
    def generate_meta_tags(page_data = {}, request = nil)
      base_url = request ? "#{request.scheme}://#{request.host_with_port}" : SITE_URL
      path = request&.path || "/"
      full_url = "#{base_url}#{path}"
      
      # Merge page data with defaults
      meta = DEFAULT_META.merge(page_data)
      
      # Ensure image is absolute URL
      meta[:image] = absolute_url(meta[:image], base_url)
      
      # Build comprehensive meta tag hash
      {
        # Basic meta tags
        title: meta[:title],
        description: meta[:description],
        keywords: meta[:keywords],
        author: meta[:author],
        robots: meta[:robots],
        canonical: full_url,
        
        # Open Graph meta tags (Facebook, LinkedIn, etc.)
        og: {
          type: meta[:type],
          url: full_url,
          title: meta[:title],
          description: meta[:description],
          image: meta[:image],
          image_secure_url: meta[:image].gsub('http:', 'https:'),
          image_type: image_type(meta[:image]),
          image_width: meta[:image_width] || "1200",
          image_height: meta[:image_height] || "630",
          image_alt: meta[:image_alt] || meta[:title],
          site_name: SITE_NAME,
          locale: meta[:locale] || "en_US"
        },
        
        # Twitter Card meta tags
        twitter: {
          card: meta[:twitter_card] || "summary_large_image",
          url: full_url,
          title: truncate(meta[:title], 70),
          description: truncate(meta[:description], 200),
          image: meta[:image],
          image_alt: meta[:image_alt] || meta[:title],
          creator: TWITTER_HANDLE,
          site: TWITTER_HANDLE
        },
        
        # Additional meta tags
        theme_color: meta[:theme_color] || "#e52e71",
        apple_mobile_web_app_capable: "yes",
        apple_mobile_web_app_status_bar_style: "black-translucent",
        mobile_web_app_capable: "yes"
      }
    end
    
    # Generate JSON-LD structured data for rich snippets
    # @param type [Symbol] Type of structured data (:website, :meme, :article, :breadcrumbs, etc.)
    # @param data [Hash] Data for the structured content
    # @param request [Rack::Request] Current request object
    # @return [String] JSON-LD script tag
    def generate_json_ld(type, data = {}, request = nil)
      base_url = request ? "#{request.scheme}://#{request.host_with_port}" : SITE_URL
      
      structured_data = case type
      when :website
        generate_website_schema(base_url, data)
      when :meme
        generate_meme_schema(base_url, data)
      when :organization
        generate_organization_schema(base_url, data)
      when :breadcrumbs
        generate_breadcrumbs_schema(base_url, data)
      when :web_page
        generate_web_page_schema(base_url, data)
      when :search_action
        generate_search_action_schema(base_url, data)
      else
        nil
      end
      
      return nil unless structured_data
      
      # Return as script tag
      %Q(<script type="application/ld+json">\n#{JSON.pretty_generate(structured_data)}\n</script>)
    end
    
    # Generate multiple JSON-LD schemas at once
    def generate_multiple_json_ld(schemas = [], request = nil)
      schemas.map do |schema_type, schema_data|
        generate_json_ld(schema_type, schema_data, request)
      end.compact.join("\n")
    end
    
    # Page-specific meta tag generators
    
    def home_page_meta(request = nil)
      generate_meta_tags({
        title: "Meme Explorer 😎 | Best Reddit Memes & Viral Content",
        description: "Discover the funniest memes from Reddit! AI-powered meme recommendations, trending content, and endless entertainment. Browse r/memes, r/dankmemes, r/wholesomememes and more.",
        keywords: "best memes, reddit memes 2026, viral memes, funny content, trending memes, meme explorer, dank memes, wholesome memes, reddit humor",
        type: "website",
        twitter_card: "summary_large_image"
      }, request)
    end
    
    def trending_page_meta(request = nil)
      generate_meta_tags({
        title: "Trending Memes 🔥 | What's Hot on Meme Explorer",
        description: "See what's trending now! The hottest and most popular memes from Reddit, updated in real-time. Don't miss today's viral content.",
        keywords: "trending memes, hot memes, viral memes today, popular memes, meme trends 2026",
        type: "website"
      }, request)
    end
    
    def random_page_meta(request = nil)
      generate_meta_tags({
        title: "Random Meme 🎲 | Surprise Me with Memes",
        description: "Get a random meme from our curated collection! Endless entertainment with surprise memes from top Reddit communities.",
        keywords: "random meme, surprise meme, meme generator, random reddit meme",
        type: "website"
      }, request)
    end
    
    def meme_detail_meta(meme, request = nil)
      return generate_meta_tags({}, request) unless meme
      
      title = "#{meme['title']} | Meme Explorer"
      subreddit = meme['subreddit'] || 'memes'
      
      generate_meta_tags({
        title: truncate(title, 60),
        description: "Check out this hilarious meme from r/#{subreddit}! #{meme['title']}",
        keywords: "#{subreddit} meme, funny #{subreddit}, reddit #{subreddit}, #{meme['title']}",
        type: "article",
        image: meme['url'] || meme['file'] || DEFAULT_IMAGE,
        image_alt: meme['title'],
        twitter_card: "summary_large_image"
      }, request)
    end
    
    def leaderboard_page_meta(request = nil)
      generate_meta_tags({
        title: "Leaderboard 🏆 | Top Meme Explorers",
        description: "See who's dominating the Meme Explorer leaderboard! Compete with others, earn XP, and climb the ranks.",
        keywords: "meme leaderboard, top users, meme competition, rankings, gamification",
        type: "website"
      }, request)
    end
    
    def search_page_meta(query = nil, request = nil)
      if query && !query.empty?
        generate_meta_tags({
          title: "Search Results for '#{query}' | Meme Explorer",
          description: "Find memes matching '#{query}'. Search through thousands of funny memes from Reddit.",
          keywords: "#{query} memes, search memes, find memes, #{query}",
          type: "website",
          robots: "noindex, follow" # Don't index search results
        }, request)
      else
        generate_meta_tags({
          title: "Search Memes 🔍 | Find Your Perfect Meme",
          description: "Search through thousands of memes from Reddit. Find exactly what you're looking for!",
          keywords: "search memes, find memes, meme search engine",
          type: "website"
        }, request)
      end
    end
    
    def profile_page_meta(username = nil, request = nil)
      if username
        generate_meta_tags({
          title: "#{username}'s Profile | Meme Explorer",
          description: "Check out #{username}'s meme activity, stats, and achievements on Meme Explorer.",
          keywords: "user profile, meme stats, #{username}",
          type: "profile",
          robots: "noindex, follow" # Don't index user profiles
        }, request)
      else
        generate_meta_tags({
          title: "Your Profile | Meme Explorer",
          description: "View your meme stats, achievements, and activity on Meme Explorer.",
          type: "profile",
          robots: "noindex, follow"
        }, request)
      end
    end
    
    private
    
    # Schema.org structured data generators
    
    def generate_website_schema(base_url, data)
      {
        "@context": "https://schema.org",
        "@type": "WebSite",
        "name": SITE_NAME,
        "url": base_url,
        "description": DEFAULT_META[:description],
        "potentialAction": {
          "@type": "SearchAction",
          "target": {
            "@type": "EntryPoint",
            "urlTemplate": "#{base_url}/search?q={search_term_string}"
          },
          "query-input": "required name=search_term_string"
        },
        "inLanguage": "en-US",
        "publisher": {
          "@type": "Organization",
          "name": SITE_NAME,
          "logo": {
            "@type": "ImageObject",
            "url": absolute_url(FAVICON_PATH, base_url)
          }
        }
      }
    end
    
    def generate_organization_schema(base_url, data)
      {
        "@context": "https://schema.org",
        "@type": "Organization",
        "name": SITE_NAME,
        "url": base_url,
        "logo": absolute_url(FAVICON_PATH, base_url),
        "description": DEFAULT_META[:description],
        "sameAs": [
          # Add social media profiles here
          "https://twitter.com/MemeExplorer"
        ]
      }
    end
    
    def generate_meme_schema(base_url, data)
      return nil unless data[:meme]
      
      meme = data[:meme]
      {
        "@context": "https://schema.org",
        "@type": "CreativeWork",
        "name": meme['title'],
        "description": meme['title'],
        "image": meme['url'] || meme['file'],
        "url": "#{base_url}#{data[:path]}",
        "creator": {
          "@type": "Organization",
          "name": "Reddit - r/#{meme['subreddit']}"
        },
        "datePublished": meme['created_at'] || Time.now.iso8601,
        "inLanguage": "en-US",
        "isFamilyFriendly": true,
        "genre": "Humor"
      }
    end
    
    def generate_breadcrumbs_schema(base_url, data)
      return nil unless data[:breadcrumbs]
      
      items = data[:breadcrumbs].each_with_index.map do |crumb, index|
        {
          "@type": "ListItem",
          "position": index + 1,
          "name": crumb[:name],
          "item": "#{base_url}#{crumb[:path]}"
        }
      end
      
      {
        "@context": "https://schema.org",
        "@type": "BreadcrumbList",
        "itemListElement": items
      }
    end
    
    def generate_web_page_schema(base_url, data)
      {
        "@context": "https://schema.org",
        "@type": "WebPage",
        "name": data[:title] || DEFAULT_META[:title],
        "description": data[:description] || DEFAULT_META[:description],
        "url": "#{base_url}#{data[:path]}",
        "inLanguage": "en-US",
        "isPartOf": {
          "@type": "WebSite",
          "name": SITE_NAME,
          "url": base_url
        }
      }
    end
    
    def generate_search_action_schema(base_url, data)
      {
        "@context": "https://schema.org",
        "@type": "WebSite",
        "url": base_url,
        "potentialAction": {
          "@type": "SearchAction",
          "target": "#{base_url}/search?q={search_term_string}",
          "query-input": "required name=search_term_string"
        }
      }
    end
    
    # Utility methods
    
    def absolute_url(url, base_url = SITE_URL)
      return url if url =~ /^https?:\/\//
      "#{base_url}#{url}"
    end
    
    def truncate(text, length)
      return text if text.length <= length
      "#{text[0...length-3]}..."
    end
    
    def image_type(url)
      ext = File.extname(url).downcase
      case ext
      when '.jpg', '.jpeg' then 'image/jpeg'
      when '.png' then 'image/png'
      when '.gif' then 'image/gif'
      when '.webp' then 'image/webp'
      else 'image/jpeg'
      end
    end
  end
end
