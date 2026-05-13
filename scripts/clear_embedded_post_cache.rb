#!/usr/bin/env ruby
# Clear API meme cache after implementing embedded post filters
# Run this after deploying the embedded post filter to ensure clean cache

require 'redis'

puts "🧹 Clearing API meme cache to apply embedded post filters..."

begin
  # Try to connect to Redis
  redis_url = ENV.fetch('REDIS_URL', 'redis://localhost:6379/0')
  
  if redis_url.empty?
    puts "⚠️  No REDIS_URL configured, cache clearing skipped"
    puts "✅ Memory cache will auto-refresh on next API fetch"
    exit 0
  end
  
  redis = Redis.new(url: redis_url)
  redis.ping
  
  # Clear the API meme cache keys
  keys_to_clear = [
    'cache:api_memes:latest',
    'cache:api_memes:timestamp',
    'cache:api_memes:lock'
  ]
  
  cleared_count = 0
  keys_to_clear.each do |key|
    if redis.del(key) > 0
      puts "✅ Cleared: #{key}"
      cleared_count += 1
    else
      puts "ℹ️  Key not found: #{key}"
    end
  end
  
  puts ""
  puts "🎉 Cache cleared successfully!"
  puts "📊 Cleared #{cleared_count} cache keys"
  puts "🔄 New memes will be fetched with embedded post filters active"
  puts ""
  puts "Next steps:"
  puts "  1. The cache will auto-refresh within 1 hour"
  puts "  2. Or restart your server to trigger immediate refresh"
  puts "  3. Embedded posts (YouTube, Twitter, etc.) will now be filtered out"
  
rescue Redis::CannotConnectError => e
  puts "⚠️  Could not connect to Redis: #{e.message}"
  puts "ℹ️  If using memory cache, restart the server to apply filters"
rescue => e
  puts "❌ Error clearing cache: #{e.class} - #{e.message}"
  exit 1
end
