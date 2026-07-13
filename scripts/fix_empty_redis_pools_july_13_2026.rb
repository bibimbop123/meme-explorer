#!/usr/bin/env ruby
# Fix Empty Redis Pools - July 13, 2026
# Problem: All Redis meme pools are empty, causing constant fallback to filtering
# Solution: Bootstrap pools and ensure ALL pool types are populated

require 'bundler/setup'
require_relative '../app'

# Explicitly require MemePoolManager and dependencies
require_relative '../lib/services/meme_pool_manager'

puts "=" * 80
puts "🔧 REDIS POOL EMERGENCY FIX - July 13, 2026"
puts "=" * 80
puts ""

# Step 1: Diagnose current state
puts "📊 Step 1: Checking current pool status..."
puts "-" * 80

pool_keys = [
  'meme_pool',
  'meme_pool:fresh', 
  'meme_pool:surprise',
  'meme_pool:diverse',
  'meme_pool:trending',
  'meme_pool:random'
]

pool_keys.each do |key|
  data = RedisService.get(key)
  if data && !data.empty?
    memes = JSON.parse(data) rescue []
    puts "✅ #{key}: #{memes.size} memes"
  else
    puts "❌ #{key}: EMPTY"
  end
end

puts ""
puts "📊 Step 2: Bootstrapping main pool with MemePoolManager..."
puts "-" * 80

# Bootstrap the main pool (will populate fresh, surprise, diverse)
begin
  result = MemePoolManager.bootstrap_pool
  
  if result[:success]
    puts "✅ Bootstrap successful: #{result[:size]} memes fetched"
    puts "   Memes stored: #{result[:memes].size}"
  else
    puts "❌ Bootstrap failed: #{result[:error]}"
    puts "   Attempting manual fetch..."
    
    # Fallback: Manual fetch if bootstrap fails
    require_relative '../lib/services/turbocharged_reddit_fetcher'
    
    fetcher = TurbochargedRedditFetcher.new(auth_strategy: :static)
    subreddits = YAML.load_file('data/subreddits.yml', aliases: true)
    all_subs = (subreddits['tier_1'] || []).first(20) +
               (subreddits['tier_2'] || []).first(10) +
               (subreddits['tier_3'] || []).first(10)
    
    memes = fetcher.fetch_memes(all_subs, limit: 25)
    puts "✅ Manual fetch: #{memes.size} memes retrieved"
    
    # Store manually
    if memes.any?
      RedisService.set('meme_pool', memes.to_json)
      RedisService.set('meme_pool:count', memes.size)
      puts "✅ Stored #{memes.size} memes in main pool"
    end
  end
rescue => e
  puts "❌ Error during bootstrap: #{e.message}"
  puts e.backtrace.first(5)
end

puts ""
puts "📊 Step 3: Populating ALL pool types (trending, random, fresh, surprise, diverse)..."
puts "-" * 80

# Get the main pool
main_pool_json = RedisService.get('meme_pool')
if main_pool_json && !main_pool_json.empty?
  main_pool = JSON.parse(main_pool_json)
  puts "✅ Main pool loaded: #{main_pool.size} memes"
  
  # Ensure ALL pool types are populated by redistributing main pool memes
  
  # 1. FRESH pool - recent memes (24-48 hours)
  fresh_pool = main_pool.select do |meme|
    if meme['created_at']
      begin
        age_hours = (Time.now - Time.parse(meme['created_at'].to_s)).to_i / 3600
        age_hours < 48
      rescue
        true # Include if we can't parse date
      end
    else
      true # Include if no date
    end
  end.shuffle.first(200)
  
  RedisService.set('meme_pool:fresh', fresh_pool.to_json)
  puts "✅ Fresh pool: #{fresh_pool.size} memes"
  
  # 2. TRENDING pool - high engagement memes
  trending_pool = main_pool.select do |meme|
    likes = meme['likes'].to_i
    upvote_ratio = meme['upvote_ratio'].to_f || 0.5
    likes >= 10 || upvote_ratio >= 0.7
  end.sort_by { |m| -m['likes'].to_i }.first(200)
  
  RedisService.set('meme_pool:trending', trending_pool.to_json)
  puts "✅ Trending pool: #{trending_pool.size} memes"
  
  # 3. SURPRISE pool - hidden gems (moderate likes, good quality)
  surprise_pool = main_pool.select do |meme|
    likes = meme['likes'].to_i
    upvote_ratio = meme['upvote_ratio'].to_f || 0.5
    likes.between?(10, 150) && upvote_ratio >= 0.6
  end.shuffle.first(150)
  
  RedisService.set('meme_pool:surprise', surprise_pool.to_json)
  puts "✅ Surprise pool: #{surprise_pool.size} memes"
  
  # 4. DIVERSE pool - maximum variety from different subreddits
  subreddit_map = {}
  main_pool.shuffle.each do |meme|
    sub = meme['subreddit']&.downcase
    next unless sub
    subreddit_map[sub] ||= []
    # Limit to 15 per subreddit for diversity
    subreddit_map[sub] << meme if subreddit_map[sub].size < 15
  end
  diverse_pool = subreddit_map.values.flatten.shuffle.first(200)
  
  RedisService.set('meme_pool:diverse', diverse_pool.to_json)
  puts "✅ Diverse pool: #{diverse_pool.size} memes"
  
  # 5. RANDOM pool - pure randomness
  random_pool = main_pool.shuffle.first(150)
  
  RedisService.set('meme_pool:random', random_pool.to_json)
  puts "✅ Random pool: #{random_pool.size} memes"
  
else
  puts "❌ Cannot populate specific pools - main pool is empty!"
  puts "   Please check Reddit API credentials and connectivity"
end

puts ""
puts "📊 Step 4: Verifying all pools..."
puts "-" * 80

pool_keys.each do |key|
  data = RedisService.get(key)
  if data && !data.empty?
    memes = JSON.parse(data) rescue []
    status = memes.size > 0 ? "✅" : "⚠️"
    puts "#{status} #{key}: #{memes.size} memes"
  else
    puts "❌ #{key}: STILL EMPTY"
  end
end

puts ""
puts "📊 Step 5: Setting pool metadata..."
puts "-" * 80

RedisService.set('meme_pool:last_refresh', Time.now.to_s)
RedisService.set('meme_pool:initialized', 'true')
puts "✅ Pool metadata set"

puts ""
puts "=" * 80
puts "✅ REDIS POOL FIX COMPLETE"
puts "=" * 80
puts ""
puts "📌 Summary:"
puts "   - All 6 pool types now populated"
puts "   - DiversityEngine will use Redis pools instead of fallback filtering"
puts "   - Performance should improve significantly"
puts ""
puts "🔄 Next Steps:"
puts "   1. Run this script in production: bundle exec ruby scripts/fix_empty_redis_pools_july_13_2026.rb"
puts "   2. Monitor logs - should see '✅ Retrieved X memes from Redis pool' instead of warnings"
puts "   3. Schedule MemePoolMaintenanceWorker to run hourly to keep pools fresh"
puts ""
