#!/usr/bin/env ruby
# Force fresh pool bootstrap with new 240+ subreddit configuration

require 'redis'
require 'json'

puts "🔧 FORCING FRESH POOL BOOTSTRAP"
puts "=" * 60

# Connect to Redis
redis_url = ENV['REDIS_URL'] || ENV['REDIS_TLS_URL'] || 'redis://localhost:6379'
redis = Redis.new(url: redis_url)

puts "\n📊 BEFORE CLEAR:"
begin
  pool_data = redis.get('meme_pool')
  if pool_data
    pool = JSON.parse(pool_data)
    puts "  • Pool size: #{pool['memes']&.size || 0} memes"
    puts "  • Unseen: #{pool['unseen']&.size || 0}"
    puts "  • Seen: #{pool['seen']&.size || 0}"
  else
    puts "  • No pool found in Redis"
  end
rescue => e
  puts "  • Error reading pool: #{e.message}"
end

puts "\n🗑️  CLEARING OLD POOL FROM REDIS..."
keys_cleared = 0

# Clear all pool-related keys
[
  'meme_pool',
  'meme_pool:fresh',
  'meme_pool:surprise',
  'meme_pool:last_bootstrap',
  'meme_pool:stats'
].each do |key|
  if redis.exists?(key)
    redis.del(key)
    keys_cleared += 1
    puts "  ✅ Cleared: #{key}"
  end
end

puts "\n✅ Cleared #{keys_cleared} Redis keys"

puts "\n🎯 NEXT REQUEST BEHAVIOR:"
puts "  1. User hits /random endpoint"
puts "  2. MemePoolManager finds empty pool"
puts "  3. Triggers bootstrap with NEW 240+ subreddit config"
puts "  4. TurboFetcher loads from ALL tiers"
puts "  5. Pool size: 400-600 memes!"

puts "\n📈 EXPECTED LOGS (watch production):"
puts "  ⚠️  [PoolManager] Pool empty, bootstrapping with 500 memes..."
puts "  [TurboFetcher] 🚀 Turbo fetch starting: 240 subreddits, limit: 20"
puts "  📊 [Bootstrap] Fetched: 400+, Validated: 400+, Stored: 400+"
puts "  📊 Pool stats: 450 total, 450 unseen (0 seen)"

puts "\n✅ Script complete! Next /random request will trigger fresh bootstrap."
puts "=" * 60
