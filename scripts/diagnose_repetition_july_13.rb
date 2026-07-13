#!/usr/bin/env ruby
# Diagnose Meme Repetition Issue - July 13, 2026

require_relative '../config/environment'

puts "🔍 DIAGNOSING MEME REPETITION ISSUE"
puts "=" * 60

# Check 1: Redis Connection
puts "\n1️⃣ Checking Redis connection..."
begin
  RedisService.ping
  puts "✅ Redis connected"
rescue => e
  puts "❌ Redis connection FAILED: #{e.message}"
  exit 1
end

# Check 2: Pool Availability
puts "\n2️⃣ Checking meme pools..."
pools = [:fresh, :trending, :random, :surprise, :diverse]

pools.each do |pool|
  # Check JSON format
  json_data = RedisService.get("meme_pool:#{pool}")
  json_count = json_data ? JSON.parse(json_data).size : 0
  
  # Check Lists format
  list_count = RedisService.llen("meme_pool:#{pool}_ids")
  
  # Check TTL
  ttl = RedisService.ttl("meme_pool:#{pool}")
  ttl_hours = ttl > 0 ? (ttl / 3600.0).round(1) : 0
  
  status = (json_count > 0 || list_count > 0) ? "✅" : "❌"
  puts "#{status} #{pool.to_s.ljust(10)} | JSON: #{json_count.to_s.rjust(3)} | Lists: #{list_count.to_s.rjust(3)} | TTL: #{ttl_hours}h"
end

# Check 3: Total memes in cache
puts "\n3️⃣ Checking meme cache..."
all_keys = RedisService.keys("api_memes:*")
total_memes = all_keys.size
puts "Total cached memes: #{total_memes}"

if total_memes < 100
  puts "⚠️  WARNING: Very few memes cached! Should have 500+"
end

# Check 4: Viewing History
puts "\n4️⃣ Checking viewing history (sample session)..."
history_keys = RedisService.keys("viewing_history:*")
puts "Active sessions with history: #{history_keys.size}"

if history_keys.any?
  sample_key = history_keys.first
  sample_count = RedisService.zcard(sample_key)
  puts "Sample session has seen: #{sample_count} memes"
end

# Check 5: Worker Status
puts "\n5️⃣ Checking background workers..."
begin
  # Check if Sidekiq is running
  stats = Sidekiq::Stats.new
  puts "Sidekiq status:"
  puts "  - Processed: #{stats.processed}"
  puts "  - Failed: #{stats.failed}"
  puts "  - Enqueued: #{stats.enqueued}"
  puts "  - Workers: #{stats.workers_size}"
rescue => e
  puts "⚠️  Could not check Sidekiq: #{e.message}"
end

# Check 6: Recent pool refresh
puts "\n6️⃣ Checking last pool refresh..."
last_refresh = RedisService.get("meme_pool:last_refresh")
if last_refresh
  last_time = Time.parse(last_refresh)
  hours_ago = ((Time.now - last_time) / 3600).round(1)
  puts "Last refresh: #{last_time} (#{hours_ago} hours ago)"
  
  if hours_ago > 6
    puts "⚠️  WARNING: Pools haven't been refreshed in #{hours_ago} hours!"
  end
else
  puts "❌ No refresh timestamp found - pools may have never been initialized"
end

# DIAGNOSIS SUMMARY
puts "\n" + "=" * 60
puts "📊 DIAGNOSIS SUMMARY"
puts "=" * 60

empty_pools = pools.select do |pool|
  json_count = RedisService.get("meme_pool:#{pool}") ? JSON.parse(RedisService.get("meme_pool:#{pool}")).size : 0
  list_count = RedisService.llen("meme_pool:#{pool}_ids")
  json_count == 0 && list_count == 0
end

if empty_pools.any?
  puts "\n❌ ISSUE FOUND: Empty pools detected"
  puts "Empty pools: #{empty_pools.join(', ')}"
  puts "\n🔧 RECOMMENDED FIX:"
  puts "   Run: bundle exec ruby scripts/comprehensive_redis_fix_july_13_2026.rb"
elsif total_memes < 100
  puts "\n❌ ISSUE FOUND: Insufficient memes in cache"
  puts "Only #{total_memes} memes cached (need 500+)"
  puts "\n🔧 RECOMMENDED FIX:"
  puts "   Run: bundle exec ruby scripts/comprehensive_redis_fix_july_13_2026.rb"
else
  puts "\n✅ Pools appear healthy"
  puts "Total memes across all pools: #{pools.sum { |p| RedisService.llen("meme_pool:#{p}_ids") }}"
  
  puts "\n🤔 If you're still seeing repetitions, the issue might be:"
  puts "   1. Small session history (check viewing_history:YOUR_SESSION_ID)"
  puts "   2. Diversity engine not filtering properly"
  puts "   3. Frontend caching issue"
end

puts "\n" + "=" * 60
puts "✅ Diagnosis complete!"
puts "=" * 60
