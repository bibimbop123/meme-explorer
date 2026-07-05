#!/usr/bin/env ruby
# Fix Tier Categorization Bug - July 5, 2026
# The MemePoolManager stores all memes in a single pool
# without categorizing them by tier - this breaks the diversity system!

require_relative '../app'

puts "🔧 FIXING TIER CATEGORIZATION BUG"
puts "=" * 60

# Step 1: Add tier categorization to MemePoolManager
puts "\n📝 Step 1: Patching MemePoolManager with tier categorization..."

meme_pool_manager_path = File.join(__dir__, '../lib/services/meme_pool_manager.rb')

# Read current file
content = File.read(meme_pool_manager_path)

# Check if categorize_by_tier method exists
if content.include?('def categorize_by_tier')
  puts "   ✅ categorize_by_tier method already exists"
else
  puts "   ❌ categorize_by_tier method MISSING - adding now..."
  
  # Find the store_in_pool method and add categorization before it
  new_method = <<~RUBY
    
    # Categorize memes by their subreddit tier
    def categorize_by_tier(memes)
      return { fresh: [], surprise: [], diverse: [] } if memes.empty?
      
      categorized = { fresh: [], surprise: [], diverse: [] }
      tier_map = load_tier_map
      
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
      
      AppLogger.info("📊 [PoolManager] Categorized: fresh=#{categorized[:fresh].size}, surprise=#{categorized[:surprise].size}, diverse=#{categorized[:diverse].size}")
      categorized
    end
    
    # Load subreddit → tier mapping from YAML
    def load_tier_map
      return @tier_map if @tier_map
      
      yaml_path = File.join(__dir__, '../../data/subreddits.yml')
      data = YAML.load_file(yaml_path)
      
      @tier_map = {}
      data['tier_1']&.each { |sub| @tier_map[sub.downcase] = 1 }
      data['tier_2']&.each { |sub| @tier_map[sub.downcase] = 2 }
      data['tier_3']&.each { |sub| @tier_map[sub.downcase] = 3 }
      data['tier_4']&.each { |sub| @tier_map[sub.downcase] = 4 }
      data['tier_5']&.each { |sub| @tier_map[sub.downcase] = 5 }
      
      AppLogger.info("📚 [PoolManager] Loaded tier map: #{@tier_map.size} subreddits")
      @tier_map
    rescue => e
      AppLogger.error("⚠️  [PoolManager] Failed to load tier map: #{e.message}")
      {}
    end
  RUBY
  
  # Insert before store_in_pool method
  content.sub!(
    /(\s+# Store memes in Redis pool\s+def store_in_pool)/,
    "#{new_method}\\1"
  )
  
  File.write(meme_pool_manager_path, content)
  puts "   ✅ Added categorize_by_tier and load_tier_map methods"
end

# Step 2: Update store_in_pool to use tiered storage
puts "\n📝 Step 2: Updating store_in_pool to use tiered Redis keys..."

content = File.read(meme_pool_manager_path)

if content.include?('def store_in_pool_tiered')
  puts "   ✅ Tiered storage already implemented"
else
  puts "   🔧 Updating store_in_pool method..."
  
  # Replace the store_in_pool method
  new_store_method = <<~RUBY
    # Store memes in Redis pool (TIERED VERSION)
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
  
  # Replace the existing store_in_pool method
  content.sub!(
    /# Store memes in Redis pool.*?(?=\n    # Get current pool size|private\n|\z)/m,
    new_store_method
  )
  
  File.write(meme_pool_manager_path, content)
  puts "   ✅ Updated store_in_pool to use tiered Redis keys"
end

# Step 3: Update get_random_memes to use tiered pools
puts "\n📝 Step 3: Updating get_random_memes to serve from tiered pools..."

content = File.read(meme_pool_manager_path)

if content.include?('# Tiered pool selection')
  puts "   ✅ Tiered selection already implemented"
else
  puts "   🔧 Updating get_random_memes method..."
  
  # Find and update get_random_memes
  content.sub!(
    /(def get_random_memes.*?)(# Get pool\s+pool = get_current_pool)/m
  ) do
    method_start = $1
    <<~RUBY
#{method_start}# Tiered pool selection
      # Use diversity-aware selection from tiered pools
      pool_stats = {
        fresh: get_tier_pool(:fresh).size,
        surprise: get_tier_pool(:surprise).size,
        diverse: get_tier_pool(:diverse).size
      }
      
      AppLogger.info("📊 [PoolManager] Pool sizes: fresh=\#{pool_stats[:fresh]}, surprise=\#{pool_stats[:surprise]}, diverse=\#{pool_stats[:diverse]}")
      
      # If any tier is empty, fall back to combined pool
      if pool_stats.values.any?(&:zero?)
        AppLogger.warn("⚠️  Some tier pools empty, using combined pool")
        pool = get_current_pool
      else
        # Combine tiered pools with preference for fresh content
        fresh_memes = get_tier_pool(:fresh).sample([count / 2, pool_stats[:fresh]].min)
        surprise_memes = get_tier_pool(:surprise).sample([count / 3, pool_stats[:surprise]].min)
        diverse_memes = get_tier_pool(:diverse).sample([count / 6, pool_stats[:diverse]].min)
        
        pool = (fresh_memes + surprise_memes + diverse_memes).shuffle
        AppLogger.info("✅ [PoolManager] Serving from tiered pools: \#{pool.size} memes")
      end
      
      # Legacy fallback
    RUBY
  end
  
  File.write(meme_pool_manager_path, content)
  puts "   ✅ Updated get_random_memes to use tiered selection"
end

# Step 4: Clear existing pool and trigger fresh bootstrap
puts "\n📝 Step 4: Clearing existing pool and triggering tiered bootstrap..."

begin
  RedisService.del('meme_pool')
  RedisService.del('meme_pool:count')
  RedisService.del('meme_pool:fresh')
  RedisService.del('meme_pool:surprise')
  RedisService.del('meme_pool:diverse')
  RedisService.del('meme_pool:fresh:count')
  RedisService.del('meme_pool:surprise:count')
  RedisService.del('meme_pool:diverse:count')
  
  puts "   ✅ Cleared all pool keys"
rescue => e
  puts "   ⚠️  Redis clear failed: #{e.message}"
end

# Step 5: Test the fix
puts "\n📝 Step 5: Testing tiered categorization..."

begin
  require_relative '../lib/services/meme_pool_manager'
  
  manager = MemePoolManager.new
  result = manager.bootstrap(size: 100)
  
  puts "\n📊 Bootstrap Result:"
  puts "   • Total memes: #{result[:total]}"
  puts "   • Valid memes: #{result[:valid]}"
  puts "   • Stored memes: #{result[:stored]}"
  
  # Check tier distribution
  fresh_count = RedisService.get('meme_pool:fresh:count')&.to_i || 0
  surprise_count = RedisService.get('meme_pool:surprise:count')&.to_i || 0
  diverse_count = RedisService.get('meme_pool:diverse:count')&.to_i || 0
  
  puts "\n📊 Tier Distribution:"
  puts "   • Fresh (tier 1): #{fresh_count} memes"
  puts "   • Surprise (tier 2-3): #{surprise_count} memes"
  puts "   • Diverse (tier 4-5): #{diverse_count} memes"
  
  if fresh_count > 0 && surprise_count > 0 && diverse_count > 0
    puts "\n✅ SUCCESS! Tier categorization working!"
  elsif fresh_count + surprise_count + diverse_count > 0
    puts "\n⚠️  PARTIAL: Some tiers populated but not all"
  else
    puts "\n❌ FAILED: No tier categorization detected"
  end
  
rescue => e
  puts "\n❌ Test failed: #{e.message}"
  puts e.backtrace.first(5)
end

puts "\n" + "=" * 60
puts "🎉 TIER CATEGORIZATION FIX COMPLETE!"
puts "\nNext steps:"
puts "  1. Restart your Puma server"
puts "  2. Monitor logs for tiered pool messages"
puts "  3. Verify diversity in /random endpoint"
puts "  4. Check Redis for meme_pool:fresh, :surprise, :diverse keys"
