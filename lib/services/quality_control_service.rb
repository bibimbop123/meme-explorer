# Quality Control Service
# Phase 4: Never show a bad meme again

class QualityControlService
  class << self
    # Quality gate - reject low-quality memes
    def passes_quality_gate?(meme)
      return false unless meme.is_a?(Hash)
      
      config = AlgorithmConfigService.quality_config
      
      # Check upvote ratio
      upvote_ratio = meme['upvote_ratio'] || meme['ratio'] || 1.0
      return false if upvote_ratio < config['min_upvote_ratio']
      
      # Check age (penalize very old content)
      if meme['created_at']
        begin
          age_days = (Time.now - Time.parse(meme['created_at'].to_s)) / 86400
          return false if age_days > 365  # No memes older than 1 year
        rescue
          # If date parsing fails, allow it
        end
        
        # Check minimum engagement
        likes = meme['likes'].to_i
        comments = meme['comments'].to_i
        return false if likes < 50 && comments < 10
        
        # Check for NSFW/quarantined content (if flagged)
        return false if meme['over_18'] == true && !allow_nsfw?
        return false if meme['quarantine'] == true
        
        true
      end
      
      # Get valid media URL with fallback chain
      def get_valid_media_url(meme)
        primary_url = meme['url']
        
        # Try primary URL first (with cache)
        return primary_url if url_is_valid?(primary_url)
        
        # Try preview images
        if meme['preview']
          preview_urls = extract_preview_images(meme['preview'])
          preview_urls.each do |url|
            return url if url_is_valid?(url)
          end
        end
        
        # Try thumbnail
        if meme['thumbnail'] && meme['thumbnail'] != 'self' && meme['thumbnail'] != 'default'
          return meme['thumbnail'] if url_is_valid?(meme['thumbnail'])
        end
        
        # Last resort: category-appropriate placeholder
        get_category_fallback(meme)
      end
      
      # Filter pool to only quality memes
      def filter_quality_pool(pool)
        return [] unless pool.is_a?(Array)
        
        pool.select { |meme| passes_quality_gate?(meme) }
      end
      
      # Check if URL is valid (with caching)
      def url_is_valid?(url)
        return false unless url.is_a?(String) && url.start_with?('http')
        
        # Check cache first
        cache_key = "url_valid:#{Digest::MD5.hexdigest(url)}"
        
        if defined?(REDIS) && REDIS
          begin
            cached = REDIS.get(cache_key)
            return cached == '1' if cached
          rescue
            # Continue to validation
          end
        end
        
        # Validate URL
        is_valid = validate_url(url)
        
        # Cache result (1 hour for valid, 10 min for invalid)
        if defined?(REDIS) && REDIS
          begin
            ttl = is_valid ? 3600 : 600
            REDIS.setex(cache_key, ttl, is_valid ? '1' : '0')
          rescue
            # Continue
          end
        end
        
        is_valid
      end
      
      private
      
      def allow_nsfw?
        # Check if NSFW content is allowed (from config or settings)
        ENV['ALLOW_NSFW'] == 'true' || false
      end
      
      def extract_preview_images(preview_data)
        urls = []
        
        if preview_data.is_a?(Hash) && preview_data['images']
          preview_data['images'].each do |image|
            if image['source'] && image['source']['url']
              urls << image['source']['url']
            end
            
            if image['resolutions']
              image['resolutions'].each do |res|
                urls << res['url'] if res['url']
              end
            end
          end
        end
        
        urls.uniq.compact
      end
      
      def validate_url(url)
        # Basic URL structure validation
        return false unless url =~ /\A#{URI::DEFAULT_PARSER.make_regexp(['http', 'https'])}\z/
        
        # Check if it's a known bad domain
        bad_domains = ['removed.reddit.com', 'deleted.reddit.com']
        uri = URI.parse(url)
        return false if bad_domains.include?(uri.host)
        
        # For now, assume URLs are valid
        # In production, you might want to do HEAD requests
        true
      rescue URI::InvalidURIError
        false
      end
      
      def get_category_fallback(meme)
        subreddit = meme['subreddit'] || 'memes'
        
        # Category-based fallbacks
        category_fallbacks = {
          'funny' => '/images/fallback-funny.jpg',
          'wholesome' => '/images/fallback-wholesome.jpg',
          'dank' => '/images/fallback-dank.jpg',
          'gaming' => '/images/fallback-gaming.jpg',
          'anime' => '/images/fallback-anime.jpg'
        }
        
        # Try to categorize subreddit
        category = categorize_subreddit(subreddit)
        category_fallbacks[category] || '/images/fallback-default.jpg'
      end
      
      def categorize_subreddit(subreddit)
        subreddit = subreddit.to_s.downcase.gsub(/^r\//, '')
        
        case subreddit
        when /funny|humor|joke/
          'funny'
        when /wholesome|aww|happy/
          'wholesome'
        when /dank|edgy|dark/
          'dank'
        when /gaming|gamer/
          'gaming'
        when /anime|manga|weeb/
          'anime'
        else
          'default'
        end
      end
    end
  end
end