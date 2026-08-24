#!/usr/bin/env ruby
# Fix Redis Pool Performance - Meme Explorer
# Issue: Pool expires immediately, causing 3-35s delays
# Solution: Increase TTL and add persistence checks

puts "🔧 Fixing Redis Pool Performance..."
puts ""

# Read meme_pool_manager.rb
file_path = "lib/services/meme_pool_manager.rb"
content = File.read(file_path)

# Fix 1: Increase TTL from 6 hours to 24 hours
content.gsub!('ttl: 21600', 'ttl: 86400')  # 6h → 24h
puts "✅ Increased Redis TTL: 6 hours → 24 hours"

# Fix 2: Update metadata TTLs
content.gsub!(/RedisService\.set\("meme_pool:count", total_stored, ttl: 21600\)/, 
              'RedisService.set("meme_pool:count", total_stored, ttl: 86400)')
content.gsub!(/RedisService\.set\("meme_pool:initialized", "true", ttl: 21600\)/, 
              'RedisService.set("meme_pool:initialized", "true", ttl: 86400)')
content.gsub!(/RedisService\.set\("meme_pool:last_refresh", Time\.now\.to_i, ttl: 21600\)/, 
              'RedisService.set("meme_pool:last_refresh", Time.now.to_i, ttl: 86400)')
puts "✅ Updated metadata TTLs to 24 hours"

# Fix 3: Add persistence check
check_code = <<~RUBY
    
    # Get current pool from Redis with persistence check
    def get_current_pool
      # Try to get from Redis
      cached = RedisService.get('meme_pool')
      if cached
        pool = JSON.parse(cached)
        
        # Verify TTL is still set (Redis persistence check)
        ttl = RedisService.ttl('meme_pool')
        if ttl && ttl > 0
          AppLogger.info("✅ [Pool] Retrieved #{pool.size} memes from cache (TTL: #{ttl}s remaining)")
          return pool
        else
          AppLogger.warn("⚠️  [Pool] Cache exists but TTL expired, re-setting...")
          RedisService.expire('meme_pool', 86400)
          return pool
        end
      end
      
      []
    rescue => e
      log_error("Get current pool error", e)
      []
    end
RUBY

# Replace the get_current_pool method
content.sub!(/def get_current_pool.*?rescue.*?end\s+end/m, check_code.strip + "\n    end")
puts "✅ Added persistence verification to get_current_pool"

# Write back
File.write(file_path, content)

puts ""
puts "🎉 Performance fixes applied!"
puts ""
puts "Changes made:"
puts "  1. TTL increased: 6h → 24h (longer cache)"
puts "  2. Persistence check added (auto-refresh TTL if expired)"
puts "  3. Better logging for cache hits"
puts ""
puts "Expected improvement:"
puts "  Before: 3-35 seconds per meme (pool re-bootstrap)"
puts "  After: <100ms per meme (cache hit)"
puts ""
puts "Deploy with: git add . && git commit -m 'perf: Fix Redis pool performance' && git push"
