# InlineRedditFetcher - Lightweight alias to RedditFetcherService
# This service was temporarily removed during audit but is required for meme fetching
# Restored as thin wrapper to maintain backward compatibility

require_relative 'reddit_fetcher_service'

class InlineRedditFetcher
  class << self
    # Fetch memes with authentication
    def fetch_authenticated(access_token, subreddits, limit: 25)
      fetcher = RedditFetcherService.new(auth_strategy: :oauth, access_token: access_token)
      fetcher.fetch_memes(subreddits, limit: limit)
    end
    
    # Fetch memes without authentication (static)
    def fetch_static(subreddits, limit: 100)
      fetcher = RedditFetcherService.new(auth_strategy: :static)
      fetcher.fetch_memes(subreddits, limit: limit)
    end
    
    # Generic fetch (detects auth automatically)
    def fetch(subreddits, limit: 25)
      fetch_static(subreddits, limit: limit)
    end
    
    private
    
    # Extract image URL from post data (delegated to helper)
    def extract_image_url(post_data)
      # This is handled by RedditFetcherService internally
      post_data['url']
    end
    
    # Extract gallery images (delegated to helper)
    def extract_gallery_images(post_data)
      # This is handled by RedditFetcherService internally
      post_data['gallery_images'] || []
    end
  end
end
