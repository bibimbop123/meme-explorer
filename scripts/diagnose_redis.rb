#!/usr/bin/env ruby
# Redis Diagnosis Script - Find why memes are repeating

# Load the full app environment
require_relative '../app'

# Ensure we have REDIS_POOL and RedisService
unless defined?(REDIS_POOL)
  puts "❌ REDIS_POOL not defined. Redis might not be configured."
  exit 1
end

puts "🔍 REDIS DIAGNOSTIC TOOL"
puts "=" * 80

# Check Redis connectivity
puts "\n1️⃣  REDIS CONNECTION STATUS"
puts "-" * 80
begin
  if RedisService.ping
    puts "✅ Redis is connected and responding"
    stats = RedisService.stats
    puts "   Memory used: #{stats[:used_memory]}"
    puts "   Connected clients: #{stats[:connected_clients]}"
    puts "   Hit rate: #{stats[:hit_rate]}%"
    puts "   Pool size: #{stats[:pool_size]}"
    puts "   Pool available: #{stats[:pool_available]}"
  else
    puts "❌ Redis is not responding to PING"
    exit 1
  end
rescue => e
  puts "❌ Redis connection failed: #{e.message}"
  puts "   #{e.backtrace.first}"
  exit 1
end

# Check for duplicate viewing history systems
puts "\n2️⃣  VIEWING HISTORY ANALYSIS"
puts "-" * 80

viewing_history_keys = []
meme_history_keys = []
diversity_pool_keys = []
recent_subreddit_keys = []

RedisService.with_redis do |redis|
  # Scan for all keys (use SCAN for production safety)
  cursor = "0"
  loop do
    cursor, keys = redis.scan(cursor, match: "*", count: 1000)
    
    keys.each do |key|
      case key
      when /^viewing_history:/
        viewing_history_keys << key
      when /^meme_history:/
        meme_history_keys << key
      when /^diversity:pools:/
        diversity_pool_keys << key
      when /^recent_subreddits:/
        recent_subreddit_keys << key
      end
    end
    
    break if cursor == "0"
  end
end

puts "Found key patterns:"
puts "  📊 viewing_history:* (ViewingHistoryService) - #{viewing_history_keys.size} keys"
puts "  📊 meme_history:* (DiversityEngineV2) - #{meme_history_keys.size} keys"
puts "  📊 diversity:pools:* (Pool tracking) - #{diversity_pool_keys.size} keys"
puts "  📊 recent_subreddits:* (Subreddit tracking) - #{recent_subreddit_keys.size} keys"

# THE PROBLEM: Two different history systems!
if viewing_history_keys.any? && meme_history_keys.any?
  puts "\n⚠️  CRITICAL ISSUE DETECTED!"
  puts "=" * 80
  puts "🐛 TWO SEPARATE VIEWING HISTORY SYSTEMS FOUND!"
  puts ""
  puts "This causes meme repetition because:"
  puts "  1. ViewingHistoryService tracks: viewing_history:{visitor_id}"
  puts "  2. DiversityEngineV2 tracks: meme_history:{session_id}"
  puts "  3. They don't communicate with each other!"
  puts ""
  puts "When visitor_id ≠ session_id, the diversity engine has empty history"
  puts "and shows the same memes over and over."
  puts "=" * 80
end

# Sample viewing history data
puts "\n3️⃣  SAMPLE DATA INSPECTION"
puts "-" * 80

if viewing_history_keys.any?
  sample_key = viewing_history_keys.first
  puts "\nViewingHistoryService (#{sample_key}):"
  
  RedisService.with_redis do |redis|
    count = redis.zcard(sample_key)
    ttl = redis.ttl(sample_key)
    sample_data = redis.zrange(sample_key, 0, 4, with_scores: true)
    
    puts "  Count: #{count} memes"
    puts "  TTL: #{ttl} seconds (#{(ttl / 60.0).round(1)} minutes)"
    puts "  Sample entries:"
    sample_data.each do |meme_id, timestamp|
      time = Time.at(timestamp.to_i)
      puts "    - #{meme_id[0..60]} (seen: #{time.strftime('%H:%M:%S')})"
    end
  end
end

if meme_history_keys.any?
  sample_key = meme_history_keys.first
  puts "\nDiversityEngineV2 (#{sample_key}):"
  
  RedisService.with_redis do |redis|
    ttl = redis.ttl(sample_key)
    data = redis.get(sample_key)
    
    if data
      history = JSON.parse(data)
      puts "  Count: #{history.size} memes"
      puts "  TTL: #{ttl} seconds (#{(ttl / 60.0).round(1)} minutes)"
      puts "  Sample entries:"
      history.take(5).each do |meme_id|
        puts "    - #{meme_id[0..60]}"
      end
    else
      puts "  (empty or expired)"
    end
  end
end

# Check for session/visitor ID mismatch
puts "\n4️⃣  SESSION vs VISITOR ID ANALYSIS"
puts "-" * 80

viewer_ids = viewing_history_keys.map { |k| k.split(':').last }.uniq
session_ids = meme_history_keys.map { |k| k.split(':').last }.uniq

puts "Unique visitor IDs in viewing_history: #{viewer_ids.size}"
puts "Unique session IDs in meme_history: #{session_ids.size}"

# Check for overlaps
matching_ids = viewer_ids & session_ids
puts "\nMatching IDs between systems: #{matching_ids.size}"

if matching_ids.empty? && viewer_ids.any? && session_ids.any?
  puts "\n⚠️  NO OVERLAP DETECTED!"
  puts "The two systems are using completely different identifiers!"
  puts ""
  puts "Sample visitor IDs: #{viewer_ids.take(3).join(', ')}"
  puts "Sample session IDs: #{session_ids.take(3).join(', ')}"
end

# Check TTL consistency
puts "\n5️⃣  TTL ANALYSIS"
puts "-" * 80

RedisService.with_redis do |redis|
  viewing_ttls = viewing_history_keys.take(5).map { |k| redis.ttl(k) }
  meme_ttls = meme_history_keys.take(5).map { |k| redis.ttl(k) }
  
  if viewing_ttls.any?
    avg_viewing_ttl = viewing_ttls.sum / viewing_ttls.size
    puts "ViewingHistoryService average TTL: #{avg_viewing_ttl}s (#{(avg_viewing_ttl / 60.0).round(1)} min)"
    puts "  Expected: 7200s (2 hours)"
  end
  
  if meme_ttls.any?
    avg_meme_ttl = meme_ttls.sum / meme_ttls.size
    puts "DiversityEngineV2 average TTL: #{avg_meme_ttl}s (#{(avg_meme_ttl / 60.0).round(1)} min)"
    puts "  Expected: 7200s (2 hours)"
  end
end

# Check for stale/expired keys
puts "\n6️⃣  KEY EXPIRY STATUS"
puts "-" * 80

RedisService.with_redis do |redis|
  expired_viewing = viewing_history_keys.count { |k| redis.ttl(k) <= 0 }
  expired_meme = meme_history_keys.count { |k| redis.ttl(k) <= 0 }
  
  puts "Expired viewing_history keys: #{expired_viewing} / #{viewing_history_keys.size}"
  puts "Expired meme_history keys: #{expired_meme} / #{meme_history_keys.size}"
  
  if expired_viewing > 0 || expired_meme > 0
    puts "\n⚠️  Some keys are expired but not cleaned up"
  end
end

# Recommendations
puts "\n7️⃣  RECOMMENDATIONS"
puts "=" * 80

recommendations = []

if viewing_history_keys.any? && meme_history_keys.any?
  recommendations << "🔧 UNIFY the two viewing history systems into one"
  recommendations << "🔧 Use a consistent identifier (visitor_id OR session_id, not both)"
  recommendations << "🔧 Have DiversityEngineV2 use ViewingHistoryService instead of direct Redis"
end

if matching_ids.empty? && viewer_ids.any? && session_ids.any?
  recommendations << "🔧 Session IDs and Visitor IDs are mismatched - this is the ROOT CAUSE"
  recommendations << "🔧 Either sync the IDs or migrate to a single tracking system"
end

recommendations << "🔧 Consider using RedisService wrapper instead of direct REDIS access"
recommendations << "🔧 Add monitoring to alert when viewing history is empty"

if recommendations.any?
  recommendations.each { |r| puts r }
else
  puts "✅ No critical issues detected"
end

# Memory usage breakdown
puts "\n8️⃣  REDIS MEMORY BREAKDOWN"
puts "-" * 80

RedisService.with_redis do |redis|
  total_keys = redis.dbsize
  puts "Total keys in database: #{total_keys}"
  
  # Sample memory usage
  sample_keys = [
    viewing_history_keys.first,
    meme_history_keys.first,
    diversity_pool_keys.first
  ].compact
  
  sample_keys.each do |key|
    begin
      memory = redis.memory('usage', key)
      type = redis.type(key)
      puts "  #{key}: #{memory} bytes (type: #{type})"
    rescue => e
      puts "  #{key}: (error getting memory: #{e.message})"
    end
  end
end

puts "\n" + "=" * 80
puts "✅ Diagnostic complete!"
puts "=" * 80
