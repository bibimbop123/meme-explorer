#!/usr/bin/env ruby
# Redis Cache Inspector - Shows what memes are cached in production

require 'bundler/setup'
require_relative '../lib/services/redis_service'

puts "🔍 REDIS CACHE INSPECTION"
puts "=" * 60

begin
  redis = RedisService.client
  
  # Test connection
  redis.ping
  puts "✅ Connected to Redis"
  puts ""
  
  # Check meme pools
  pools = ['fresh', 'trending', 'surprise', 'diverse', 'random']
  total_memes = 0
  
  puts "📊 MEME POOLS:"
  puts "-" * 60
  
  pools.each do |pool|
    # Check both JSON storage and list storage
    json_key = "pool:#{pool}"
    list_key = "pool:#{pool}:ids"
    
    json_exists = redis.exists(json_key) > 0
    list_count = redis.llen(list_key)
    
    if json_exists || list_count > 0
      # Try to get actual count from JSON
      if json_exists
        json_data = redis.get(json_key)
        begin
          memes = JSON.parse(json_data) rescue []
          count = memes.is_a?(Array) ? memes.length : 0
        rescue
          count = list_count
        end
      else
        count = list_count
      end
      
      total_memes += count
      status = count > 0 ? "✅" : "⚠️ "
      puts "#{status} #{pool.ljust(15)}: #{count.to_s.rjust(4)} memes"
    else
      puts "❌ #{pool.ljust(15)}:    0 memes (empty)"
    end
  end
  
  puts "-" * 60
  puts "📈 TOTAL CACHED: #{total_memes} memes"
  puts ""
  
  # Check for any other meme-related keys
  puts "🔑 OTHER REDIS KEYS:"
  puts "-" * 60
  
  all_keys = redis.keys('*meme*')
  other_keys = all_keys.reject { |k| k.start_with?('pool:') }
  
  if other_keys.any?
    other_keys.first(10).each do |key|
      type = redis.type(key)
      ttl = redis.ttl(key)
      ttl_str = ttl == -1 ? "no expiry" : "#{ttl}s TTL"
      puts "  #{key} (#{type}, #{ttl_str})"
    end
    puts "  ... and #{other_keys.length - 10} more" if other_keys.length > 10
  else
    puts "  No other meme-related keys found"
  end
  
  puts ""
  puts "=" * 60
  
  # Recommendations
  if total_memes == 0
    puts "❌ PROBLEM: No memes cached!"
    puts "   Solution: Wait for Reddit rate limit to clear (30-60 min)"
    puts "   OR create new Reddit OAuth app with fresh credentials"
  elsif total_memes < 100
    puts "⚠️  WARNING: Low cache (#{total_memes} memes)"
    puts "   Recommendation: Let bootstrap run to fill pools"
  elsif total_memes < 500
    puts "✅ GOOD: Decent cache (#{total_memes} memes)"
    puts "   App can serve users from this cache"
  else
    puts "🎉 EXCELLENT: Well-stocked cache (#{total_memes} memes)"
    puts "   App is in great shape!"
  end
  
rescue => e
  puts "❌ ERROR: #{e.message}"
  puts "   Make sure Redis is running and accessible"
  puts "   (This script works on Render production)"
end
