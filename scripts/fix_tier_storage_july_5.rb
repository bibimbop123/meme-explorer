#!/usr/bin/env ruby
# Fix Tier Storage - July 5, 2026
# Update store_in_pool to actually use the tier categorization methods

require 'fileutils'

puts "🔧 FIXING TIER STORAGE IN MEME_POOL_MANAGER"
puts "=" * 60

file_path = 'lib/services/meme_pool_manager.rb'
backup_path = "#{file_path}.backup.#{Time.now.to_i}"

# Backup original file
FileUtils.cp(file_path, backup_path)
puts "✅ Backed up original to: #{backup_path}"

# Read the file
content = File.read(file_path)

# The old store_in_pool method (lines 312-335)
old_method = <<~OLD
    # Store memes in Redis pool
    def store_in_pool(memes)
      return 0 if memes.empty?
      
      # Get current pool
      current_pool = get_current_pool
      
      # Add new memes (avoid duplicates by URL)
      existing_urls = current_pool.map { |m| m["url"] }.to_set
      new_memes = memes.reject { |m| existing_urls.include?(m["url"]) }
      
      # Update pool
      updated_pool = current_pool + new_memes
      
      # Store in Redis
      RedisService.set('meme_pool', updated_pool.to_json)
      RedisService.set('meme_pool:count', updated_pool.size)
      RedisService.set('meme_pool:updated_at', Time.now.to_s)
      
      new_memes.size
    rescue => e
      log_error("Store in pool error", e)
      0
    end
OLD

# The new tiered store_in_pool method
new_method = <<~NEW
    # Store memes in Redis pool (TIERED VERSION - July 5, 2026)
    def store_in_pool(memes)
      return 0 if memes.empty?
      
      # Categorize by tier FIRST
      categorized = categorize_by_tier(memes)
      
      total_stored = 0
      
      # Store each tier separately
      [:fresh, :surprise, :diverse].each do |pool_name|
        tier_memes = categorized[pool_name]
        next if tier_memes.empty?
        
        # Get current tier pool
        current_pool = get_tier_pool(pool_name)
        
        # Add new memes (avoid duplicates by URL)
        existing_urls = current_pool.map { |m| m["url"] }.to_set
        new_memes = tier_memes.reject { |m| existing_urls.include?(m["url"]) }
        
        # Update pool
        updated_pool = current_pool + new_memes
        
        # Store in Redis with tier-specific key
        RedisService.set("meme_pool:\#{pool_name}", updated_pool.to_json)
        RedisService.set("meme_pool:\#{pool_name}:count", updated_pool.size)
        
        total_stored += new_memes.size
        AppLogger.info("   ✅ Stored \#{new_memes.size} memes in '\#{pool_name}' pool (total: \#{updated_pool.size})")
      end
      
      # Also maintain legacy single pool for backward compatibility
      all_memes = categorized[:fresh] + categorized[:surprise] + categorized[:diverse]
      current_pool = get_current_pool
      existing_urls = current_pool.map { |m| m["url"] }.to_set
      new_memes = all_memes.reject { |m| existing_urls.include?(m["url"]) }
      updated_pool = current_pool + new_memes
      
      RedisService.set('meme_pool', updated_pool.to_json)
      RedisService.set('meme_pool:count', updated_pool.size)
      RedisService.set('meme_pool:updated_at', Time.now.to_s)
      
      total_stored
    rescue => e
      log_error("Store in pool error", e)
      0
    end
NEW

# Replace the method
if content.include?("# Store memes in Redis pool\n    def store_in_pool(memes)")
  new_content = content.gsub(old_method.strip, new_method.strip)
  
  if new_content != content
    File.write(file_path, new_content)
    puts "✅ Updated store_in_pool method to use tier categorization"
    puts ""
    puts "📊 Changes made:"
    puts "   • Now calls categorize_by_tier(memes) first"
    puts "   • Stores memes in tier-specific Redis keys:"
    puts "     - meme_pool:fresh (tier_1)"
    puts "     - meme_pool:surprise (tier_2/3)"
    puts "     - meme_pool:diverse (tier_4/5)"
    puts "   • Maintains backward compatibility with legacy 'meme_pool' key"
  else
    puts "⚠️  Warning: Content didn't change as expected"
  end
else
  puts "❌ Could not find store_in_pool method to replace"
  puts "The file may have been modified. Check manually."
  exit 1
end

puts ""
puts "=" * 60
puts "✅ Fix complete! Now deploy to production:"
puts ""
puts "1. Commit changes:"
puts "   git add lib/services/meme_pool_manager.rb"
puts "   git commit -m 'Fix tier categorization in store_in_pool'"
puts "   git push origin main"
puts ""
puts "2. Render will auto-deploy in ~2-3 minutes"
puts ""
puts "3. Monitor logs for:"
puts "   '📊 [PoolManager] Categorized: fresh=X, surprise=Y, diverse=Z'"
puts "   '✅ Stored X memes in \\'fresh\\' pool'"
puts ""
puts "4. Verify tier pools are populated (run diagnose script again)"
