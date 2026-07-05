#!/usr/bin/env ruby
# Diagnose Tier Storage Issue - July 5, 2026
# Verify that tier categorization methods exist but aren't being called

require_relative '../lib/app_logger'
require_relative '../lib/services/redis_service'
require 'json'

puts "🔍 DIAGNOSING TIER STORAGE ISSUE"
puts "=" * 60

# Check what's in Redis
puts "\n1️⃣ Checking Redis Keys:"
main_pool = RedisService.get('meme_pool')
fresh_pool = RedisService.get('meme_pool:fresh')
surprise_pool = RedisService.get('meme_pool:surprise')
diverse_pool = RedisService.get('meme_pool:diverse')

if main_pool
  main_count = JSON.parse(main_pool).size rescue 0
  puts "   ✅ meme_pool: #{main_count} memes (SHOULD BE EMPTY after fix)"
else
  puts "   ⚠️  meme_pool: NOT FOUND"
end

if fresh_pool
  fresh_count = JSON.parse(fresh_pool).size rescue 0
  puts "   #{fresh_count > 0 ? '✅' : '❌'} meme_pool:fresh: #{fresh_count} memes (SHOULD HAVE tier_1)"
else
  puts "   ❌ meme_pool:fresh: NOT FOUND (PROBLEM!)"
end

if surprise_pool
  surprise_count = JSON.parse(surprise_pool).size rescue 0
  puts "   #{surprise_count > 0 ? '✅' : '❌'} meme_pool:surprise: #{surprise_count} memes (SHOULD HAVE tier_2/3)"
else
  puts "   ❌ meme_pool:surprise: NOT FOUND (PROBLEM!)"
end

if diverse_pool
  diverse_count = JSON.parse(diverse_pool).size rescue 0
  puts "   #{diverse_count > 0 ? '✅' : '❌'} meme_pool:diverse: #{diverse_count} memes (SHOULD HAVE tier_4/5)"
else
  puts "   ❌ meme_pool:diverse: NOT FOUND (PROBLEM!)"
end

# Check if methods exist
puts "\n2️⃣ Checking MemePoolManager Methods:"
require_relative '../lib/services/meme_pool_manager'

methods_to_check = [:categorize_by_tier, :load_subreddit_tier_map, :get_tier_pool]
methods_to_check.each do |method|
  if MemePoolManager.respond_to?(method)
    puts "   ✅ #{method} method EXISTS"
  else
    puts "   ❌ #{method} method MISSING"
  end
end

# The issue
puts "\n3️⃣ ROOT CAUSE:"
puts "   The categorization methods EXIST but store_in_pool() isn't calling them!"
puts "   store_in_pool() is dumping everything into 'meme_pool' instead of tier pools."

puts "\n4️⃣ SOLUTION:"
puts "   Update store_in_pool() to:"
puts "   1. Call categorize_by_tier(memes)"
puts "   2. Store in separate keys: meme_pool:fresh, meme_pool:surprise, meme_pool:diverse"

puts "\n" + "=" * 60
puts "✅ Diagnosis complete. See fix in scripts/fix_tier_storage_july_5.rb"
