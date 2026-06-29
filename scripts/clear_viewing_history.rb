#!/usr/bin/env ruby
# Clear all viewing history from Redis

require_relative '../config/application'

puts "🔍 Searching for viewing history keys in Redis..."

RedisService.with_redis do |redis|
  keys = redis.keys('viewing_history:*')
  
  if keys.empty?
    puts "✅ No viewing history keys found - Redis is clean!"
  else
    puts "📊 Found #{keys.size} viewing history keys"
    puts "🗑️  Deleting..."
    
    redis.del(*keys)
    
    puts "✅ Cleared #{keys.size} viewing history keys from Redis!"
    puts "🎉 All users will now see fresh memes!"
  end
end

puts "\n💡 Tip: Users may need to refresh their browsers to see the effect"
