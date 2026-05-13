#!/usr/bin/env ruby
# Clear cache to remove link posts that slipped through old filters

require 'redis'
require 'json'

puts "🧹 Clearing meme cache to remove link posts..."

# Clear Redis cache
begin
  redis_url = ENV.fetch('REDIS_URL', 'redis://localhost:6379/0')
  
  if redis_url && !redis_url.empty?
    redis = Redis.new(url: redis_url)
    redis.ping
    
    puts "✅ Connected to Redis: #{redis_url}"
    
    # Clear API meme cache
    deleted_count = 0
    
    if redis.del('cache:api_memes:latest') > 0
      deleted_count += 1
      puts "   ✓ Deleted: cache:api_memes:latest"
    end
    
    if redis.del('cache:api_memes:timestamp') > 0
      deleted_count += 1
      puts "   ✓ Deleted: cache:api_memes:timestamp"
    end
    
    if redis.del('cache:api_memes:lock') > 0
      deleted_count += 1
      puts "   ✓ Deleted: cache:api_memes:lock"
    end
    
    puts "\n✅ Cleared #{deleted_count} Redis cache keys"
    puts "   Next fetch will use new strict filters!"
    
  else
    puts "⚠️  No REDIS_URL configured - skipping Redis cache"
  end
rescue Redis::CannotConnectError => e
  puts "⚠️  Could not connect to Redis: #{e.message}"
  puts "   Cache will be cleared when server restarts"
rescue => e
  puts "⚠️  Redis error: #{e.message}"
  puts "   Cache will be cleared when server restarts"
end

puts "\n📝 Instructions:"
puts "   1. Restart your server to clear in-memory cache:"
puts "      pkill -f puma && bundle exec puma -C config/puma.rb"
puts "\n   2. The next meme fetch will use the new strict filters"
puts "   3. Only image/video posts from trusted domains will be cached"
puts "\n✨ Link posts will now be completely filtered out!"
