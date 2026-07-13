#!/usr/bin/env ruby
# IMMEDIATE HOTFIX: Populate Redis pools to fix repetition
# Senior Ruby Dev - 50+ years experience
# July 13, 2026

require 'bundler/setup'
require 'redis'
require 'json'
require 'net/http'
require 'uri'

puts "🚨 IMMEDIATE REPETITION HOTFIX"
puts "=" * 80

# Direct Redis connection
REDIS_URL = ENV['REDIS_URL'] || 'redis://localhost:6379'
redis = Redis.new(url: REDIS_URL)

puts "\n✅ Connected to Redis: #{REDIS_URL}"

# Test subreddits (proven to work)
SUBREDDITS = %w[
  memes dankmemes me_irl wholesomememes AdviceAnimals terriblefacebookmemes
  ComedyCemetery okbuddyretard comedyheaven antimeme bonehurtingjuice
  PrequelMemes HistoryMemes ProgrammerHumor trippinthroughtime fakehistoryporn
]

# Fetch memes from Reddit
def fetch_memes_simple(subreddits, limit_per_sub = 10)
  memes = []
  
  subreddits.each do |sub|
    begin
      url = "https://www.reddit.com/r/#{sub}/hot.json?limit=#{limit_per_sub}"
      uri = URI(url)
      
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true
      http.read_timeout = 10
      
      request = Net::HTTP::Get.new(uri)
      request['User-Agent'] = 'MemeExplorer/1.0'
      
      response = http.request(request)
      
      if response.code == '200'
        data = JSON.parse(response.body)
        posts = data.dig('data', 'children') || []
        
        posts.each do |post|
          meme_data = post['data']
          next unless meme_data
          
          # Only image posts
          url = meme_data['url']
          next unless url && (url.end_with?('.jpg', '.png', '.gif') || url.include?('i.redd.it'))
          
          memes << {
            id: meme_data['id'],
            title: meme_data['title'],
            url: url,
            subreddit: meme_data['subreddit'],
            ups: meme_data['ups'] || 0,
            created_utc: meme_data['created_utc'] || Time.now.to_i
          }
        end
        
        print "✓"
      else
        print "✗"
      end
    rescue => e
      print "!"
    end
    
    sleep 0.5  # Rate limiting
  end
  
  puts "\n✅ Fetched #{memes.size} memes from #{subreddits.size} subreddits"
  memes
end

# Categorize memes into pools
def categorize_memes(memes)
  now = Time.now.to_i
  
  fresh = memes.select { |m| (now - m[:created_utc]) < 86400 }  # < 24 hours
  trending = memes.select { |m| m[:ups] >= 100 }
  surprise = memes.select { |m| m[:ups].between?(50, 500) }
  diverse = memes.select { |m| m[:ups] < 50 }
  random_pool = memes.shuffle
  
  {
    fresh: fresh.any? ? fresh : memes.shuffle.take(20),
    trending: trending.any? ? trending : memes.shuffle.take(30),
    surprise: surprise.any? ? surprise : memes.shuffle.take(25),
    diverse: diverse.any? ? diverse : memes.shuffle.take(20),
    random: random_pool
  }
end

# Store pools directly in Redis
def store_pools(redis, pools)
  pools.each do |pool_name, memes|
    # Convert to JSON format
    memes_json = memes.map { |m| m.to_json }
    
    # Clear old data
    redis.del("meme_pool:#{pool_name}")
    redis.del("meme_pool:#{pool_name}_ids")
    
    # Store as JSON blob (legacy format)
    redis.set("meme_pool:#{pool_name}", memes.to_json)
    
    # Store as Redis List (new format)
    if memes.any?
      redis.rpush("meme_pool:#{pool_name}_ids", memes.map { |m| m[:id] })
      
      # Store full meme data in hashes
      memes.each do |meme|
        redis.hset("meme:#{meme[:id]}", meme.transform_keys(&:to_s))
      end
    end
    
    # Set 6-hour TTL
    redis.expire("meme_pool:#{pool_name}", 21600)
    redis.expire("meme_pool:#{pool_name}_ids", 21600)
    
    puts "✅ #{pool_name.to_s.ljust(10)} : #{memes.size} memes (JSON + Lists)"
  end
  
  # Set last refresh timestamp
  redis.set("meme_pool:last_refresh", Time.now.to_s)
end

# EXECUTE HOTFIX
puts "\n📥 Fetching fresh memes..."
memes = fetch_memes_simple(SUBREDDITS, 15)

if memes.size < 20
  puts "\n⚠️  WARNING: Only fetched #{memes.size} memes (expected 100+)"
  puts "   This may indicate Reddit API issues or rate limiting"
  puts "   Continuing with what we have..."
end

puts "\n🎯 Categorizing into 5 pools..."
pools = categorize_memes(memes)

puts "\n💾 Storing in Redis..."
store_pools(redis, pools)

puts "\n✅ Verifying storage..."
pools.each_key do |pool_name|
  json_data = redis.get("meme_pool:#{pool_name}")
  json_count = json_data ? JSON.parse(json_data).size : 0
  
  list_count = redis.llen("meme_pool:#{pool_name}_ids")
  ttl = redis.ttl("meme_pool:#{pool_name}")
  ttl_hours = ttl > 0 ? (ttl / 3600.0).round(1) : 0
  
  status = (json_count > 0 || list_count > 0) ? "✅" : "❌"
  puts "#{status} #{pool_name.to_s.ljust(10)} : JSON=#{json_count}, List=#{list_count}, TTL=#{ttl_hours}h"
end

puts "\n" + "=" * 80
puts "🎉 HOTFIX COMPLETE!"
puts "=" * 80
puts "\nNext steps:"
puts "1. Test the /random endpoint - should show different memes"
puts "2. Clear your browser cookies to reset session"
puts "3. If still seeing repetitions, run this script again"
puts "\nTo run again: bundle exec ruby scripts/immediate_repetition_hotfix_july_13.rb"
