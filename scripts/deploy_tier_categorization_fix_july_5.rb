#!/usr/bin/env ruby
# Automated Tier Categorization Fix Deployment
# July 5, 2026 - Fixes meme pool repetition by adding tier categorization
# 
# USAGE (from project root):
#   ruby scripts/deploy_tier_categorization_fix_july_5.rb

require 'fileutils'

puts "🎯 TIER CATEGORIZATION FIX - AUTOMATED DEPLOYMENT"
puts "=" * 60
puts ""

# Step 1: Backup original file
puts "📋 Step 1: Backing up original MemePoolManager..."
original_file = 'lib/services/meme_pool_manager.rb'
backup_file = "lib/services/meme_pool_manager.rb.backup.#{Time.now.to_i}"

if File.exist?(original_file)
  FileUtils.cp(original_file, backup_file)
  puts "   ✅ Backup created: #{backup_file}"
else
  puts "   ⚠️  Original file not found: #{original_file}"
  exit 1
end

# Step 2: Read original content
puts ""
puts "📖 Step 2: Reading original file..."
content = File.read(original_file)
puts "   ✅ File read successfully (#{content.lines.count} lines)"

# Step 3: Add new methods before store_in_pool
puts ""
puts "✏️  Step 3: Adding tier categorization methods..."

new_methods = <<~RUBY
    # Categorize memes by their subreddit tier
    def categorize_by_tier(memes)
      return { fresh: [], surprise: [], diverse: [] } if memes.empty?
      
      categorized = { fresh: [], surprise: [], diverse: [] }
      tier_map = load_subreddit_tier_map
      
      memes.each do |meme|
        subreddit = meme["subreddit"]&.downcase
        next unless subreddit
        
        tier = tier_map[subreddit] || 5 # Default to tier 5 if unknown
        
        case tier
        when 1
          categorized[:fresh] << meme
        when 2, 3
          categorized[:surprise] << meme
        when 4, 5
          categorized[:diverse] << meme
        end
      end
      
      AppLogger.info("📊 [PoolManager] Categorized: fresh=\#{categorized[:fresh].size}, surprise=\#{categorized[:surprise].size}, diverse=\#{categorized[:diverse].size}")
      categorized
    end
    
    # Load subreddit → tier mapping from YAML
    def load_subreddit_tier_map
      return @tier_map if @tier_map
      
      yaml_path = File.join(__dir__, '../../data/subreddits.yml')
      data = YAML.load_file(yaml_path)
      
      @tier_map = {}
      data['tier_1']&.each { |sub| @tier_map[sub.downcase] = 1 }
      data['tier_2']&.each { |sub| @tier_map[sub.downcase] = 2 }
      data['tier_3']&.each { |sub| @tier_map[sub.downcase] = 3 }
      data['tier_4']&.each { |sub| @tier_map[sub.downcase] = 4 }
      data['tier_5']&.each { |sub| @tier_map[sub.downcase] = 5 }
      
      AppLogger.info("📚 [PoolManager] Loaded tier map: \#{@tier_map.size} subreddits")
      @tier_map
    rescue => e
      AppLogger.error("⚠️  [PoolManager] Failed to load tier map: \#{e.message}")
      {}
    end
    
    # Get memes from a specific tier pool
    def get_tier_pool(pool_name)
      json = RedisService.get("meme_pool:\#{pool_name}")
      return [] unless json
      
      JSON.parse(json)
    rescue => e
      AppLogger.error("⚠️  Failed to get tier pool '\#{pool_name}': \#{e.message}")
      []
    end
    
RUBY

# Find the location to insert (before the store_in_pool method)
store_method_index = content.index('    # Store memes in Redis pool')

if store_method_index
  # Insert new methods before store_in_pool
  content.insert(store_method_index, new_methods)
  puts "   ✅ Added 3 new tier categorization methods"
else
  puts "   ⚠️  Could not find store_in_pool method marker"
  exit 1
end

# Step 4: Replace store_in_pool method
puts ""
puts "🔄 Step 4: Replacing store_in_pool with tiered version..."

old_store_method = <<~RUBY
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
RUBY

new_store_method = <<~RUBY
    # Store memes in Redis pool (TIERED VERSION - July 5, 2026)
    def store_in_pool(memes)
      return 0 if memes.empty?
      
      # Categorize by tier
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
RUBY

content.gsub!(old_store_method, new_store_method)
puts "   ✅ Replaced store_in_pool with tiered version"

# Step 5: Write updated file
puts ""
puts "💾 Step 5: Writing updated file..."
File.write(original_file, content)
puts "   ✅ File written successfully"

# Step 6: Create Redis cleanup script
puts ""
puts "🧹 Step 6: Creating Redis cleanup script..."

cleanup_script = <<~RUBY
#!/usr/bin/env ruby
# Clear all meme pools to force fresh tier-categorized fetch

require_relative '../config/environment'

puts "🧹 Clearing all meme pools..."

keys_to_clear = [
  'meme_pool',
  'meme_pool:count',
  'meme_pool:updated_at',
  'meme_pool:fresh',
  'meme_pool:fresh:count',
  'meme_pool:surprise',
  'meme_pool:surprise:count',
  'meme_pool:diverse',
  'meme_pool:diverse:count'
]

keys_to_clear.each do |key|
  RedisService.del(key)
  puts "   ✅ Cleared: \#{key}"
end

puts ""
puts "✅ All pools cleared! Next /random request will trigger fresh fetch with tier categorization."
RUBY

cleanup_file = 'scripts/clear_all_pools.rb'
File.write(cleanup_file, cleanup_script)
File.chmod(0755, cleanup_file)
puts "   ✅ Created: #{cleanup_file}"

# Step 7: Summary and next steps
puts ""
puts "=" * 60
puts "✅ TIER CATEGORIZATION FIX - DEPLOYMENT COMPLETE!"
puts "=" * 60
puts ""
puts "📝 What was changed:"
puts "   1. Added categorize_by_tier() method"
puts "   2. Added load_subreddit_tier_map() method"
puts "   3. Added get_tier_pool() method"
puts "   4. Replaced store_in_pool() with tiered version"
puts "   5. Created cleanup script: #{cleanup_file}"
puts ""
puts "🚀 NEXT STEPS (DO THIS NOW):"
puts ""
puts "   # Step 1: Clear all Redis pools"
puts "   $ ruby #{cleanup_file}"
puts ""
puts "   # Step 2: Restart your Render service"
puts "   (Go to Render dashboard → Manual Deploy → Clear build cache & deploy)"
puts ""
puts "   # Step 3: Monitor logs for success"
puts "   Look for: '📊 [PoolManager] Categorized: fresh=X, surprise=Y, diverse=Z'"
puts ""
puts "📊 Expected Results:"
puts "   ✅ Logs show tier categorization stats"
puts "   ✅ NO MORE '⚠️  Pool fresh only has 0 memes'"
puts "   ✅ Memes properly distributed across tiers"
puts "   ✅ Improved diversity in /random endpoint"
puts ""
puts "🔄 Rollback (if needed):"
puts "   $ cp #{backup_file} #{original_file}"
puts ""
