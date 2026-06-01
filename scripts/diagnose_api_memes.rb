#!/usr/bin/env ruby
# Diagnostic script to check why API memes aren't loading

require_relative '../app'

puts "🔍 API Meme Diagnostic Script"
puts "=" * 60

# Check 1: Reddit credentials
puts "\n1️⃣ Checking Reddit API credentials..."
client_id = ENV['REDDIT_CLIENT_ID'].to_s.strip
client_secret = ENV['REDDIT_CLIENT_SECRET'].to_s.strip

if client_id.empty? || client_secret.empty?
  puts "❌ REDDIT_CLIENT_ID: #{client_id.empty? ? 'NOT SET' : 'SET'}"
  puts "❌ REDDIT_CLIENT_SECRET: #{client_secret.empty? ? 'NOT SET' : 'SET'}"
  puts "\n⚠️  API memes won't work without Reddit credentials!"
else
  puts "✅ Reddit credentials are configured"
end

# Check 2: Test the method call
puts "\n2️⃣ Testing MemeExplorer::App.fetch_reddit_memes_authenticated..."
begin
  require 'oauth2'
  client = OAuth2::Client.new(
    client_id,
    client_secret,
    site: "https://www.reddit.com",
    authorize_url: "/api/v1/authorize",
    token_url: "/api/v1/access_token"
  )
  
  token = client.client_credentials.get_token(scope: "read")
  puts "✅ Got OAuth token"
  
  subreddits = YAML.load_file("data/subreddits.yml")["popular"].sample(3)
  puts "   Testing with subreddits: #{subreddits.join(', ')}"
  
  api_memes = MemeExplorer::App.fetch_reddit_memes_authenticated(token.token, subreddits, 10)
  puts "✅ Fetched #{api_memes.size} API memes"
  
  if api_memes.any?
    puts "\n   Sample meme:"
    meme = api_memes.first
    puts "   Title: #{meme['title']}"
    puts "   Subreddit: #{meme['subreddit']}"
    puts "   URL: #{meme['url']}"
  end
rescue => e
  puts "❌ Error: #{e.class}: #{e.message}"
  puts "   #{e.backtrace.first(3).join("\n   ")}"
end

# Check 3: Check current cache
puts "\n3️⃣ Checking current meme cache..."
cache_memes = MemeExplorer::MEME_CACHE.get(:memes) || []
puts "   Total memes in cache: #{cache_memes.size}"

api_count = cache_memes.count { |m| m["url"] && !m["url"].start_with?("/") }
local_count = cache_memes.count { |m| m["file"] || (m["url"] && m["url"].start_with?("/")) }

puts "   API memes: #{api_count}"
puts "   Local memes: #{local_count}"

if api_count == 0
  puts "\n❌ NO API MEMES IN CACHE"
  puts "   This explains why you only see 'local' memes!"
end

# Check 4: Last refresh time
puts "\n4️⃣ Checking last cache refresh..."
last_refresh = MemeExplorer::MEME_CACHE.get(:last_refresh)
if last_refresh
  puts "   Last refresh: #{last_refresh}"
  age = (Time.now - last_refresh).to_i
  puts "   Age: #{age} seconds ago"
else
  puts "   ❌ Cache has never been refreshed"
end

puts "\n" + "=" * 60
puts "✅ Diagnostic complete!"
