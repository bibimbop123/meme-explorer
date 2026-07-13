#!/usr/bin/env ruby
# Diagnose Redis Pools - July 13, 2026
# Check what's actually in Redis and why pools appear empty

require 'bundler/setup'
require_relative '../app'

puts "=" * 80
puts "🔍 REDIS POOL DIAGNOSTICS - July 13, 2026"
puts "=" * 80
puts ""

# Check all pool keys
pool_keys = [
  'meme_pool',
  'meme_pool:count',
  'meme_pool:fresh',
  'meme_pool:trending',
  'meme_pool:random',
  'meme_pool:surprise',
  'meme_pool:diverse',
  'meme_pool:initialized',
  'meme_pool:last_refresh'
]

puts "📊 Redis Keys Status:"
puts "-" * 80
pool_keys.each do |key|
  value = RedisService.get(key)
  if value && !value.empty?
    if key.include?(':count') || key == 'meme_pool:initialized'
      puts "✅ #{key}: #{value}"
    elsif key == 'meme_pool:last_refresh'
      puts "✅ #{key}: #{value}"
    else
      begin
        parsed = JSON.parse(value)
        puts "✅ #{key}: #{parsed.size} memes (#{value.bytesize} bytes)"
      rescue
        puts "⚠️  #{key}: #{value.size} chars (not JSON)"
      end
    end
  else
    puts "❌ #{key}: EMPTY or NIL"
  end
end

puts ""
puts "📊 Detailed Pool Analysis:"
puts "-" * 80

# Check main pool
main_pool_json = RedisService.get('meme_pool')
if main_pool_json && !main_pool_json.empty?
  main_pool = JSON.parse(main_pool_json)
  puts "Main Pool: #{main_pool.size} memes"
  
  # Show sample
  if main_pool.any?
    sample = main_pool.first
    puts "  Sample meme:"
    puts "    - Title: #{sample['title']}"
    puts "    - Subreddit: #{sample['subreddit']}"
    puts "    - URL: #{sample['url']}"
    puts "    - Likes: #{sample['likes']}"
    puts "    - Has created_at: #{sample['created_at'] ? 'Yes' : 'No'}"
  end
  
  # Check subreddit distribution
  subs = main_pool.map { |m| m['subreddit'] }.compact
  puts "\n  Subreddit distribution:"
  subs.group_by(&:itself).transform_values(&:count).sort_by { |k, v| -v }.first(10).each do |sub, count|
    puts "    - #{sub}: #{count} memes"
  end
else
  puts "❌ Main pool is empty!"
end

puts ""
puts "🔍 Redis Connection Test:"
puts "-" * 80
begin
  # Try a simple set/get
  test_key = "test:#{Time.now.to_i}"
  test_value = "test_value_#{rand(1000)}"
  
  RedisService.set(test_key, test_value, ttl: 10)
  retrieved = RedisService.get(test_key)
  
  if retrieved == test_value
    puts "✅ Redis read/write working correctly"
    RedisService.del(test_key)
  else
    puts "❌ Redis read/write FAILED"
    puts "   Set: #{test_value}"
    puts "   Got: #{retrieved}"
  end
rescue => e
  puts "❌ Redis connection error: #{e.message}"
end

puts ""
puts "=" * 80
puts "Diagnosis complete"
puts "=" * 80
