# Link Post Filtering in Random Meme Feature

## Overview
The meme explorer already filters out link posts (text posts with just URLs) at multiple levels to ensure only actual image/video content is shown.

## 🎯 Where Filtering Happens

### 1. **API Fetch Level** (`lib/services/api_cache_service.rb`)

#### A. Crosspost Filtering (Lines 297-298, 409-410)
```ruby
# Skip crossposts - we want original content only
next if post_data['is_crosspost'] || post_data['crosspost_parent']
```

#### B. URL Validation in `extract_image_url` (Lines 475-504)
```ruby
# CRITICAL: Reject subreddit URLs
return nil if url.match?(/^\/r\/[^\/]+\/?$/)
return nil if url.match?(/reddit\.com\/r\/[^\/]+\/?$/)

# Accept only actual image URLs
if url.match?(/\.(jpg|jpeg|png|gif|webp)(\?|$)/i)
  return url
end

# Accept known image hosting domains
if url.match?(/^https?:\/\/(i\.redd\.it|i\.imgur\.com|preview\.redd\.it)/i)
  return url
end
```

#### C. Quality Filter in `validate_and_filter_quality_memes` (Lines 558-561)
```ruby
# CRITICAL: Reject subreddit paths
next false if url.match?(/^\/r\/[^\/]+\/?$/)
next false if url.match?(/reddit\.com\/r\/[^\/]+\/?$/)
next false if url.include?('/r/') && url.include?('/comments/')

# Must be actual media URL
is_media = url.match?(/\.(jpg|jpeg|png|gif|webp|mp4|webm)(\?|$)/i) ||
           url.match?(/^https?:\/\/(i\.redd\.it|i\.imgur\.com|preview\.redd\.it|v\.redd\.it)/)
next false unless is_media
```

### 2. **Selection Level** (`lib/services/random_selector_service.rb`)

#### A. Crosspost Filtering (Lines 667-672)
```ruby
def filter_crossposts(memes)
  memes.reject do |meme|
    meme['is_crosspost'] || meme['crosspost_parent'] || meme['crosspost_parent_list']
  end
end
```

#### B. Media Quality Scoring (Line 220)
```ruby
# CRITICAL: Reject Reddit post URLs (these show fallback images)
return 0.0 if url_lower.include?('/r/') && url_lower.include?('/comments/')
```

## 🔧 How to Strengthen Filtering

If you're still seeing link posts, you can add additional filters:

### Option 1: Filter by Post Hint
Add this to the API fetch in `api_cache_service.rb` around line 300:

```ruby
# Skip text/link posts - only accept image/video content
post_hint = post_data['post_hint']
next unless ['image', 'hosted:video', 'rich:video'].include?(post_hint)
```

### Option 2: Check for Self-Posts
Add this check in the same location:

```ruby
# Skip self posts (text posts)
next if post_data['is_self'] == true
```

### Option 3: Verify Domain
Add this after line 300 in `api_cache_service.rb`:

```ruby
# Only accept posts from trusted media domains
domain = post_data['domain']
trusted_domains = ['i.redd.it', 'i.imgur.com', 'imgur.com', 'gfycat.com', 'v.redd.it']
next unless trusted_domains.any? { |d| domain&.include?(d) }
```

### Option 4: Stricter Media URL Validation
Replace the `extract_image_url` method check to be even stricter:

```ruby
def extract_image_url(post_data)
  url = post_data['url']
  return nil unless url
  
  # STRICT: Only accept direct media URLs from trusted sources
  return nil unless url.match?(/^https?:\/\/(i\.redd\.it|i\.imgur\.com|preview\.redd\.it|v\.redd\.it)/)
  
  # OR has media file extension
  return url if url.match?(/\.(jpg|jpeg|png|gif|webp|mp4|webm)(\?|$)/i)
  
  # Try preview as fallback
  preview = post_data.dig('preview', 'images', 0, 'source', 'url')
  preview&.gsub('&amp;', '&') if preview
end
```

## 🐛 Debugging Link Posts

If link posts are still appearing, check:

### 1. **Check Redis Cache**
The cache might contain old data with link posts:

```ruby
# In Rails console or script
redis = Redis.new(url: ENV['REDIS_URL'])
redis.del('cache:api_memes:latest')
redis.del('cache:api_memes:timestamp')
```

### 2. **Check Memory Cache**
Restart the server to clear in-memory cache:

```bash
# Kill and restart
pkill -f puma
bundle exec puma -C config/puma.rb
```

### 3. **Test Individual Post**
Add logging to see what's being filtered:

```ruby
# In api_cache_service.rb after line 407
puts "[DEBUG] Post: #{post_data['title']}"
puts "[DEBUG] URL: #{post_data['url']}"
puts "[DEBUG] Domain: #{post_data['domain']}"
puts "[DEBUG] Post Hint: #{post_data['post_hint']}"
puts "[DEBUG] Is Self: #{post_data['is_self']}"
```

## 📊 Current Filter Stats

Based on the current implementation:
- ✅ **Crossposts**: Filtered
- ✅ **Reddit comment URLs**: Filtered  
- ✅ **Subreddit links**: Filtered
- ✅ **Non-media URLs**: Filtered
- ✅ **Low quality posts**: Filtered (< 50 upvotes, < 0.7 ratio)

## 🎯 Recommended Action

If you're seeing link posts in production:

1. **Clear the cache** (it may contain old data)
2. **Add the post_hint filter** (Option 1 above) - most reliable
3. **Monitor for 24 hours** to see if new fetches are clean
4. **Add logging** to identify which posts are slipping through

## Example Implementation

Here's the complete filter to add in `fetch_reddit_memes_authenticated` and `fetch_reddit_memes_unauthenticated`:

```ruby
# Add after line 297 (authenticated) and line 407 (unauthenticated)

# Skip crossposts
next if post_data['is_crosspost'] || post_data['crosspost_parent']

# Skip text/self posts
next if post_data['is_self'] == true

# Only accept image/video content
post_hint = post_data['post_hint']
next unless ['image', 'hosted:video', 'rich:video'].include?(post_hint)

# Verify domain is a media host
domain = post_data['domain']
trusted_domains = ['i.redd.it', 'i.imgur.com', 'imgur.com', 'gfycat.com', 'v.redd.it', 'redgifs.com']
next unless trusted_domains.any? { |d| domain&.include?(d) }
```

This will ensure **zero link posts** make it into the random meme pool.
