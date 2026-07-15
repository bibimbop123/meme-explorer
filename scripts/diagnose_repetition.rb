#!/usr/bin/env ruby
# Quick diagnostic for meme repetition issues

require_relative '../app'

puts "🔍 DIAGNOSING MEME REPETITION ISSUE..."
puts "=" * 60

# 1. Check Redis connection
puts "\n1️⃣ REDIS CONNECTION:"
if defined?(REDIS) && REDIS
  begin
    REDIS.ping
    puts "   ✅ Redis is connected and responding"
    
    # Check for existing history keys
    keys = REDIS.keys("meme_history:*")
    puts "   📊 Found #{keys.size} session history keys"
    
    if keys.any?
      sample_key = keys.first
      history = JSON.parse(REDIS.get(sample_key) || '[]')
      puts "   📝 Sample session has #{history.size} memes in history"
    end
  rescue => e
    puts "   ❌ Redis error: #{e.message}"
    puts "   💡 Solution: Start Redis with 'redis-server'"
  end
else
  puts "   ❌ Redis is NOT defined or connected"
  puts "   💡 Solution: Start Redis with 'redis-server'"
end

# 2. Check meme pool size
puts "\n2️⃣ MEME POOL SIZE:"
begin
  pool_size = MemeExplorer::App::MEME_CACHE[:memes]&.size || 0
  puts "   📦 Current meme pool: #{pool_size} memes"
  
  if pool_size < 50
    puts "   ⚠️  Pool is too small! Need at least 100+ memes for variety"
    puts "   💡 Solution: Refresh meme cache or fetch more from Reddit"
  elsif pool_size < 200
    puts "   ⚙️  Pool is okay but could be larger for better variety"
  else
    puts "   ✅ Pool size is good"
  end
rescue => e
  puts "   ❌ Error checking pool: #{e.message}"
end

# 3. Check if diversity engine is working
puts "\n3️⃣ DIVERSITY ENGINE:"
begin
  require_relative '../lib/services/diversity_engine_service'
  puts "   ✅ DiversityEngineService loaded"
  
  # Test selection
  test_id = "test_#{Time.now.to_i}"
  pool = MemeExplorer::App::MEME_CACHE[:memes] || []
  
  if pool.any?
    selected = MemeExplorer::DiversityEngineService.select_diverse_meme(
      pool,
      session_id: test_id,
      preferences: {}
    )
    
    if selected
      puts "   ✅ Successfully selected a meme"
      puts "   🎯 Pool: #{selected['diversity_pool']}" if selected['diversity_pool']
    else
      puts "   ❌ Selection returned nil"
    end
  end
rescue => e
  puts "   ❌ Error: #{e.message}"
  puts "   #{e.backtrace.first(3).join("\n   ")}"
end

puts "\n" + "=" * 60
puts "DIAGNOSIS COMPLETE"
puts "=" * 60

puts "\n📋 QUICK FIXES:"
puts "1. Start Redis: redis-server"
puts "2. Refresh meme cache: Clear browser cache and reload"
puts "3. If still repeating: Clear Redis with 'redis-cli FLUSHDB'"
puts ""
