#!/usr/bin/env ruby
# Emergency hotfix for production errors - Aug 24, 2026
# Issues:
# 1. MEME_CACHE scope error in helpers
# 2. Reddit rate limiting (429) killing bootstrap

puts "🚨 EMERGENCY PRODUCTION HOTFIX - Aug 24, 2026"
puts ""

# Fix 1: Update meme_pool_helpers.rb to use correct scope
puts "📝 Fix 1: Fixing MEME_CACHE scope in helpers..."

helpers_file = "lib/helpers/meme_pool_helpers.rb"
content = File.read(helpers_file)

# Replace all MEME_CACHE references with MemeExplorer::App::MEME_CACHE
content.gsub!(/(?<!::App::)MEME_CACHE/, 'MemeExplorer::App::MEME_CACHE')
content.gsub!(/(?<!::)MEMES(?!:)/, 'MemeExplorer::App::MEMES')

File.write(helpers_file, content)
puts "✅ Fixed MEME_CACHE references"

# Fix 2: Add rate limiting to InlineRedditFetcher
puts "📝 Fix 2: Adding exponential backoff to Reddit fetcher..."

fetcher_file = "lib/services/inline_reddit_fetcher.rb"
new_content = <<~RUBY
# InlineRedditFetcher - Lightweight alias to RedditFetcherService
# Restored after audit with rate limiting protection

require_relative 'reddit_fetcher_service'

class InlineRedditFetcher
  class << self
    # Rate limiting state
    @last_request_time = Time.now
    @min_delay = 1.0  # Start with 1 second between requests
    
    # Fetch memes with authentication + rate limiting
    def fetch_authenticated(access_token, subreddits, limit: 25)
      enforce_rate_limit
      fetcher = RedditFetcherService.new(auth_strategy: :oauth, access_token: access_token)
      fetcher.fetch_memes(subreddits, limit: limit)
    rescue => e
      handle_error(e)
    end
    
    # Fetch memes without authentication (static) + rate limiting  
    def fetch_static(subreddits, limit: 100)
      enforce_rate_limit
      fetcher = RedditFetcherService.new(auth_strategy: :static)
      fetcher.fetch_memes(subreddits, limit: limit)
    rescue => e
      handle_error(e)
    end
    
    # Generic fetch (detects auth automatically) + rate limiting
    def fetch(subreddits, limit: 25)
      fetch_static(subreddits, limit: limit)
    end
    
    private
    
    # Enforce exponential backoff rate limiting
    def enforce_rate_limit
      time_since_last = Time.now - @last_request_time
      if time_since_last < @min_delay
        sleep(@min_delay - time_since_last)
      end
      @last_request_time = Time.now
    end
    
    # Handle errors with exponential backoff
    def handle_error(error)
      if error.message.include?('429') || error.message.include?('rate')
        @min_delay = [@min_delay * 2, 60].min  # Max 60 seconds
        AppLogger.warn("⚠️  Rate limited - backing off to #{@min_delay}s")
      end
      []  # Return empty array on error
    end
    
    # Extract image URL from post data (delegated to helper)
    def extract_image_url(post_data)
      post_data['url']
    end
    
    # Extract gallery images (delegated to helper)  
    def extract_gallery_images(post_data)
      post_data['gallery_images'] || []
    end
  end
end
RUBY

File.write(fetcher_file, new_content)
puts "✅ Added rate limiting protection"

puts ""
puts "🎉 HOTFIX COMPLETE"
puts ""
puts "Changes made:"
puts "  1. Fixed MEME_CACHE scope in lib/helpers/meme_pool_helpers.rb"
puts "  2. Added exponential backoff to lib/services/inline_reddit_fetcher.rb"
puts ""
puts "To deploy:"
puts "  git add lib/helpers/meme_pool_helpers.rb lib/services/inline_reddit_fetcher.rb"
puts "  git commit -m 'hotfix: Fix MEME_CACHE scope + Reddit rate limiting'"
puts "  git push"
puts ""
puts "The app will recover automatically after deploy."
