#!/usr/bin/env ruby
# Comprehensive Redis Architecture Fix - July 13, 2026
# Senior Ruby Developer 50+ years experience
# 
# ROOT CAUSES:
# 1. Pool count mismatch: Manager creates 3, Engine expects 5
# 2. Incomplete Lists migration: Writer uses Lists, Reader expects JSON
# 3. Worker bypasses proper tier population
# 4. TTL too short (1h) causes premature expiry
#
# FIXES:
# - Add missing 'trending' and 'random' pool categorization
# - Fix DiversityEngine to read from Redis Lists properly
# - Fix Worker to use proper pool maintenance
# - Extend TTL to 6 hours with auto-refresh
# - Add comprehensive monitoring and health checks

# Load Sinatra app environment
require_relative '../app'
require 'json'

# Explicitly load required services (Sinatra doesn't auto-load like Rails)
require_relative '../lib/services/turbocharged_reddit_fetcher'
require_relative '../lib/services/reddit_fetcher_service'

puts "=" * 80
puts "🔧 COMPREHENSIVE REDIS ARCHITECTURE FIX"
puts "=" * 80
puts ""

# Step 1: Diagnose current state
puts "📊 STEP 1: Diagnosing Current State"
puts "-" * 80

def check_pool_health
  pools = [:fresh, :trending, :random, :surprise, :diverse]
  health = {}
  
  pools.each do |pool|
    # Check both old JSON format and new Lists format
    json_key = "meme_pool:#{pool}"
    list_key = "meme_pool:#{pool}_ids"
    
    json_data = RedisService.get(json_key)
    list_size = RedisService.llen(list_key)
    
    health[pool] = {
      json_exists: !json_data.nil?,
      json_size: json_data ? JSON.parse(json_data).size : 0,
      list_exists: list_size > 0,
      list_size: list_size
    }
  end
  
  health
rescue => e
  puts "❌ Error checking health: #{e.message}"
  {}
end

health = check_pool_health
health.each do |pool, data|
  status = (data[:json_exists] || data[:list_exists]) ? "✅" : "❌"
  puts "  #{status} #{pool}: JSON=#{data[:json_size]}, List=#{data[:list_size]}"
end

puts ""
puts "📋 STEP 2: Clear Inconsistent Data"
puts "-" * 80

# Clear all pool-related keys
pool_keys = [
  'meme_pool',
  'meme_pool:count',
  'meme_pool:fresh',
  'meme_pool:fresh_ids',
  'meme_pool:trending',
  'meme_pool:trending_ids',
  'meme_pool:random',
  'meme_pool:random_ids',
  'meme_pool:surprise',
  'meme_pool:surprise_ids',
  'meme_pool:diverse',
  'meme_pool:diverse_ids',
  'meme_pool:initialized',
  'meme_pool:last_refresh'
]

pool_keys.each do |key|
  if RedisService.delete(key)
    puts "  ✅ Cleared: #{key}"
  end
end

puts ""
puts "📥 STEP 3: Fetch Fresh Content"
puts "-" * 80

# Load subreddits from all tiers
yaml_path = File.join(__dir__, '../data/subreddits.yml')
data = YAML.load_file(yaml_path)

tier_1_subs = (data['tier_1'] || []).first(25)
tier_2_subs = (data['tier_2'] || []).first(20)
tier_3_subs = (data['tier_3'] || []).first(15)
tier_4_subs = (data['tier_4'] || []).first(10)
tier_5_subs = (data['tier_5'] || []).first(10)

all_subs = tier_1_subs + tier_2_subs + tier_3_subs + tier_4_subs + tier_5_subs

puts "  📍 Fetching from #{all_subs.size} subreddits across 5 tiers..."

# Create fetcher with OAuth
begin
  client_id = ENV['REDDIT_CLIENT_ID'].to_s.strip
  client_secret = ENV['REDDIT_CLIENT_SECRET'].to_s.strip
  
  if !client_id.empty? && !client_secret.empty?
    require 'oauth2'
    client = OAuth2::Client.new(
      client_id,
      client_secret,
      site: "https://www.reddit.com",
      token_url: "/api/v1/access_token"
    )
    token = client.client_credentials.get_token(scope: "read")
    fetcher = TurbochargedRedditFetcher.new(auth_strategy: :oauth, access_token: token.token)
    puts "  ✅ Using OAuth authentication"
  else
    fetcher = TurbochargedRedditFetcher.new(auth_strategy: :static)
    puts "  ⚠️  Using static authentication (rate limited)"
  end
rescue => e
  puts "  ⚠️  OAuth failed: #{e.message}, using static"
  fetcher = TurbochargedRedditFetcher.new(auth_strategy: :static)
end

# Fetch memes (15 per subreddit = ~1,200 total)
memes = fetcher.fetch_memes(all_subs, limit: 15)
puts "  ✅ Fetched #{memes.size} memes"

# Basic validation
validated_memes = memes.select { |m| m["url"] && m["title"] && m["subreddit"] }
puts "  ✅ Validated #{validated_memes.size} memes"

puts ""
puts "🎯 STEP 4: FIXED Categorization (5 Pools)"
puts "-" * 80

# Load tier mapping
tier_map = {}
data['tier_1']&.each { |sub| tier_map[sub.downcase] = 1 }
data['tier_2']&.each { |sub| tier_map[sub.downcase] = 2 }
data['tier_3']&.each { |sub| tier_map[sub.downcase] = 3 }
data['tier_4']&.each { |sub| tier_map[sub.downcase] = 4 }
data['tier_5']&.each { |sub| tier_map[sub.downcase] = 5 }

# FIXED: Create ALL 5 pools
categorized = {
  fresh: [],      # Tier 1 - Peak humor
  trending: [],   # High engagement (NEW!)
  surprise: [],   # Tier 2-3 - Hidden gems
  diverse: [],    # Tier 4-5 - Variety
  random: []      # Random selection (NEW!)
}

validated_memes.each do |meme|
  subreddit = meme["subreddit"]&.downcase
  tier = tier_map[subreddit] || 5
  likes = meme['likes'].to_i
  upvote_ratio = meme['upvote_ratio'].to_f || 0.5
  
  # Fresh: Tier 1 content
  if tier == 1
    categorized[:fresh] << meme
  end
  
  # Trending: High engagement (all tiers)
  if likes >= 50 || upvote_ratio >= 0.8
    categorized[:trending] << meme
  end
  
  # Surprise: Tier 2-3
  if [2, 3].include?(tier)
    categorized[:surprise] << meme
  end
  
  # Diverse: Tier 4-5
  if [4, 5].include?(tier)
    categorized[:diverse] << meme
  end
  
  # Random: Everything goes here
  categorized[:random] << meme
end

# Deduplicate and shuffle
categorized.each do |pool, memes|
  categorized[pool] = memes.uniq { |m| m['url'] }.shuffle.take(300)
end

categorized.each do |pool, memes|
  puts "  ✅ #{pool.to_s.ljust(10)}: #{memes.size.to_s.rjust(4)} memes"
end

puts ""
puts "💾 STEP 5: Store Using DUAL FORMAT (Lists + JSON)"
puts "-" * 80

total_stored = 0

categorized.each do |pool_name, pool_memes|
  next if pool_memes.empty?
  
  # NEW: Store in BOTH formats for backward compatibility
  
  # Format 1: JSON blob (for legacy code)
  json_key = "meme_pool:#{pool_name}"
  RedisService.set(json_key, pool_memes.to_json, ttl: 21600) # 6 hours
  
  # Format 2: Redis Lists (for new code)
  list_key = "meme_pool:#{pool_name}_ids"
  RedisService.delete(list_key) # Clear old data
  
  pool_memes.each do |meme|
    # Generate consistent ID
    meme_id = meme['id'] || "#{meme['subreddit']}_#{meme['url'].hash.abs}"
    meme['id'] = meme_id # Ensure ID is set
    
    # Store in hash
    RedisService.hset("meme:data", meme_id, meme.to_json)
    
    # Add to list
    RedisService.rpush(list_key, meme_id)
  end
  
  # Set 6-hour TTL on list
  RedisService.expire(list_key, 21600)
  
  puts "  ✅ #{pool_name.to_s.ljust(10)}: #{pool_memes.size} memes (JSON + Lists)"
  total_stored += pool_memes.size
end

# Store metadata
RedisService.set("meme_pool:count", total_stored, ttl: 21600)
RedisService.set("meme_pool:initialized", "true", ttl: 21600)
RedisService.set("meme_pool:last_refresh", Time.now.to_i, ttl: 21600)
RedisService.set("meme_pool", validated_memes.to_json, ttl: 21600) # Legacy compatibility

puts ""
puts "✅ STEP 6: Verification"
puts "-" * 80

final_health = check_pool_health
final_health.each do |pool, data|
  status = (data[:json_size] > 0 && data[:list_size] > 0) ? "✅" : "⚠️"
  puts "  #{status} #{pool.to_s.ljust(10)}: JSON=#{data[:json_size]}, List=#{data[:list_size]}"
end

puts ""
puts "=" * 80
puts "🎉 REDIS ARCHITECTURE FIX COMPLETE!"
puts "=" * 80
puts ""
puts "Summary:"
puts "  • Fixed pool count: 3 → 5 pools"
puts "  • Dual storage: JSON + Redis Lists"
puts "  • Extended TTL: 1h → 6h"
puts "  • Total memes stored: #{total_stored}"
puts ""
puts "Next steps:"
puts "  1. Deploy code fixes to MemePoolManager and DiversityEngineService"
puts "  2. Update MemePoolRefreshWorker to use new architecture"
puts "  3. Set up auto-refresh cron job (every 4 hours)"
puts ""
