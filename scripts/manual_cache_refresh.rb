#!/usr/bin/env ruby
# Manual Cache Refresh Script - Diagnose and Fix API Meme Issue

require_relative '../app'

puts "🔍 DIAGNOSTIC: Manual Cache Refresh"
puts "=" * 60

# Step 1: Check Reddit credentials
puts "\n1️⃣ Checking Reddit API credentials..."
client_id = ENV['REDDIT_CLIENT_ID'].to_s.strip
client_secret = ENV['REDDIT_CLIENT_SECRET'].to_s.strip

if client_id.empty? || client_secret.empty?
  puts "❌ ISSUE FOUND: Reddit API credentials not set!"
  puts "   - REDDIT_CLIENT_ID: #{client_id.empty? ? 'NOT SET' : 'SET'}"
  puts "   - REDDIT_CLIENT_SECRET: #{client_secret.empty? ? 'NOT SET' : 'SET'}"
  puts "\n💡 SOLUTION: Set these environment variables in your .env file"
  puts "   Get credentials from: https://www.reddit.com/prefs/apps"
else
  puts "✅ Reddit credentials are configured"
end

# Step 2: Load local memes
puts "\n2️⃣ Loading local memes as fallback..."
local_memes = begin
  yaml_data = YAML.load_file("data/memes.yml")
  if yaml_data.is_a?(Hash)
    yaml_data.values.flatten.compact
  else
    yaml_data || []
  end
rescue => e
  puts "❌ Failed to load local memes: #{e.message}"
  []
end
puts "✅ Loaded #{local_memes.size} local memes"

# Step 3: Use RedditFetcherService (OPTIMIZED for maximum memes!)
puts "\n3️⃣ Attempting Reddit API fetch with RedditFetcherService..."
api_memes = []
all_subreddits = YAML.load_file("data/subreddits.yml")["popular"]

if !client_id.empty? && !client_secret.empty?
  begin
    require 'oauth2'
    
    client = OAuth2::Client.new(
      client_id,
      client_secret,
      site: "https://www.reddit.com",
      authorize_url: "/api/v1/authorize",
      token_url: "/api/v1/access_token"
    )
    
    puts "   Requesting access token..."
    token = client.client_credentials.get_token(scope: "read")
    puts "   ✅ Got access token"
    
    puts "   Fetching memes using RedditFetcherService (OAuth - 12 subreddits × 50 posts)..."
    fetcher = RedditFetcherService.new(auth_strategy: :oauth, access_token: token.token)
    api_memes = fetcher.fetch_memes(all_subreddits, limit: 50)
    puts "   ✅ Fetched #{api_memes.size} memes from Reddit API (OAuth)"
    
  rescue => e
    puts "   ⚠️ OAuth fetch failed: #{e.message}"
    puts "   Falling back to unauthenticated fetch..."
  end
end

# Step 4: Try unauthenticated fetch if OAuth failed
if api_memes.empty?
  puts "\n4️⃣ Attempting unauthenticated API fetch with RedditFetcherService..."
  begin
    puts "   Fetching memes (Static - 25 subreddits × 50 posts)..."
    fetcher = RedditFetcherService.new(auth_strategy: :static)
    api_memes = fetcher.fetch_memes(all_subreddits, limit: 50)
    puts "✅ Fetched #{api_memes.size} memes from Reddit API (unauthenticated)"
  rescue => e
    puts "❌ Unauthenticated fetch failed: #{e.message}"
    puts e.backtrace.first(3).join("\n")
  end
end

# Step 5: Update cache
puts "\n5️⃣ Updating MEME_CACHE..."
if api_memes.empty?
  puts "⚠️ No API memes fetched - using local memes only"
  MemeExplorer::App::MEME_CACHE.set(:memes, local_memes.shuffle)
  puts "✅ Cache updated with #{local_memes.size} local memes"
else
  all_memes = (api_memes + local_memes).uniq { |m| m["url"] || m["file"] }
  MemeExplorer::App::MEME_CACHE.set(:memes, all_memes.shuffle)
  puts "✅ Cache updated with #{api_memes.size} API + #{local_memes.size} local = #{all_memes.size} total memes"
end

MemeExplorer::App::MEME_CACHE.set(:last_refresh, Time.now)

# Step 6: Verify cache
puts "\n6️⃣ Verifying cache contents..."
cached_memes = MemeExplorer::App::MEME_CACHE.get(:memes) || []
api_count = cached_memes.count { |m| m["url"] && !m["url"].start_with?("/") }
local_count = cached_memes.count { |m| m["file"] || (m["url"] && m["url"].start_with?("/")) }

puts "   Total cached: #{cached_memes.size}"
puts "   API memes: #{api_count}"
puts "   Local memes: #{local_count}"

if api_count == 0
  puts "\n❌ PROBLEM: No API memes in cache!"
  puts "\n🔧 TROUBLESHOOTING STEPS:"
  puts "   1. Make sure Reddit API credentials are set in .env"
  puts "   2. Check that you can reach reddit.com (not blocked)"
  puts "   3. Try running this script again"
  puts "   4. If it still fails, there may be a Reddit API rate limit"
else
  puts "\n✅ SUCCESS: Cache contains API memes!"
end

# Step 7: Show sample memes
puts "\n7️⃣ Sample memes in cache:"
cached_memes.first(3).each_with_index do |meme, i|
  source = if meme["url"] && !meme["url"].start_with?("/")
    "API (#{meme['subreddit']})"
  else
    "LOCAL"
  end
  puts "   #{i+1}. [#{source}] #{meme['title']}"
end

puts "\n" + "=" * 60
puts "✅ Manual cache refresh complete!"
puts "💡 Restart your server to use the updated cache"
