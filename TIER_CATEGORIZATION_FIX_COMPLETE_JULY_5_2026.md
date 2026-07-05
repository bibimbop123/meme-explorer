# 🎯 Tier Categorization Bug - DIAGNOSED & SOLUTION PROVIDED
## July 5, 2026 - Senior Dev Root Cause Analysis

## Executive Summary
**The fetching IS working perfectly** (80 subreddits, 100-121 memes), but `MemePoolManager` lacks tier categorization, causing all memes to cluster in a single pool. This breaks your entire diversity system.

---

## 🔍 Root Cause Analysis

### What Your Logs Show:
```
⚠️  Pool 'fresh' only has 0 memes, using all unseen (99)
⚠️  Pool 'surprise' only has 0 memes, using all unseen (41)  
⚠️  Pool 'fresh' only has 0 memes, using all unseen (46)
```

### The Problem:
`MemePoolManager.store_in_pool()` stores ALL memes in a single Redis key without categorizing by tier:

**EXPECTED (tiered pools):**
```ruby
{
  fresh: [40 memes from tier_1 subs],
  surprise: [35 memes from tier_2/3 subs],  
  diverse: [24 memes from tier_4/5 subs]
}
```

**ACTUAL (single pool):**
```ruby
{
  fresh: [],      # Empty!
  surprise: [],   # Empty!
  diverse: [],    # Empty!
  unseen: [all_99_memes]  # Everything lumped together!
}
```

###Why You See Repetition:
Without tier categorization, the Diversity Engine **can't diversify**. All memes cluster, causing similar content to appear together.

---

## ✅ THE FIX (Deploy to Production via Render Shell)

### Step 1: SSH into Render Production Shell
```bash
# From Render dashboard, open Shell for your service
```

### Step 2: Add Tier Categorization Methods

Add these methods to `lib/services/meme_pool_manager.rb` BEFORE the `store_in_pool` method:

```ruby
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

# Get memes from a specific tier pool
def get_tier_pool(pool_name)
  json = RedisService.get("meme_pool:#{pool_name}")
  return [] unless json
  
  JSON.parse(json)
rescue => e
  AppLogger.error("⚠️  Failed to get tier pool '#{pool_name}': #{e.message}")
  []
end
```

### Step 3: Update `store_in_pool` Method

Replace the existing `store_in_pool` method with this tiered version:

```ruby
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
    RedisService.set("meme_pool:#{pool_name}", updated_pool.to_json)
    RedisService.set("meme_pool:#{pool_name}:count", updated_pool.size)
    
    total_stored += new_memes.size
    AppLogger.info("   ✅ Stored #{new_memes.size} memes in '#{pool_name}' pool (total: #{updated_pool.size})")
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
```

### Step 4: Clear Pools and Restart

```bash
# In Render shell:
rails console

# Clear all pools
RedisService.del('meme_pool')
RedisService.del('meme_pool:count')
RedisService.del('meme_pool:fresh')
RedisService.del('meme_pool:surprise')
RedisService.del('meme_pool:diverse')

exit

# Restart service from Render dashboard
```

---

## 📊 Expected Results

After deploying, your logs should show:

```
📊 [PoolManager] Categorized: fresh=35, surprise=40, diverse=26
   ✅ Stored 35 memes in 'fresh' pool (total: 35)
   ✅ Stored 40 memes in 'surprise' pool (total: 40)
   ✅ Stored 26 memes in 'diverse' pool (total: 26)
```

Instead of:
```
⚠️  Pool 'fresh' only has 0 memes, using all unseen (99)
```

---

## 🎯 Why This Fixes Repetition

1. **Tier-based Storage**: Memes now stored in separate Redis keys by tier
2. **Diversity Engine Restored**: Can now properly diversify across tiers
3. **Proper Distribution**: fresh (tier 1), surprise (tier 2-3), diverse (tier 4-5)
4. **No More Clustering**: Similar memes from same tier won't appear back-to-back

---

## 💡 Alternative: Manual Redis Fix (If you can't edit code)

If you can't modify `MemePoolManager.rb`, you can manually distribute the pool:

```ruby
# In Rails console on production:
pool = JSON.parse(RedisService.get('meme_pool') || '[]')
tier_map = YAML.load_file('data/subreddits.yml')

fresh = pool.select { |m| tier_map['tier_1'].include?(m['subreddit']) }
surprise = pool.select { |m| tier_map['tier_2'].include?(m['subreddit']) || tier_map['tier_3'].include?(m['subreddit']) }
diverse = pool.select { |m| tier_map['tier_4'].include?(m['subreddit']) || tier_map['tier_5'].include?(m['subreddit']) }

RedisService.set('meme_pool:fresh', fresh.to_json)
RedisService.set('meme_pool:surprise', surprise.to_json)
RedisService.set('meme_pool:diverse', diverse.to_json)
```

---

## ✅ Verification

Check logs for these signs of success:

1. ✅ "📊 [PoolManager] Categorized: fresh=X, surprise=Y, diverse=Z" 
2. ✅ "Stored X memes in 'fresh' pool"
3. ✅ NO MORE "Pool 'fresh' only has 0 memes"
4. ✅ Improved meme diversity in `/random` endpoint

---

## 📝 Summary

- **Problem**: MemePoolManager missing tier categorization
- **Impact**: All 100+ memes lumped into single pool, breaking diversity
- **Solution**: Add `categorize_by_tier()`, `load_tier_map()`, update `store_in_pool()`  
- **Result**: Proper tier distribution enables diversity engine

**Deploy via Render shell, restart service, monitor logs!** 🚀
