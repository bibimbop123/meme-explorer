# Redis Lists Migration - Fix LRU Eviction Issue
**Date:** July 13, 2026  
**Issue:** Redis allkeys-lru with 25MB limit evicts JSON blobs immediately  
**Solution:** Store meme IDs in Lists, full memes in Hashes

## Root Cause
```
maxmemory: 25MB
maxmemory_policy: allkeys-lru
lazyfreed_objects: 572  ← Active eviction!
```

When MemePoolManager stores 50 memes as JSON (5MB), Redis immediately evicts them due to LRU policy.

## Solution Architecture

### Before (Current - Broken)
```ruby
# Stores 5MB JSON blob - gets evicted immediately
RedisService.set("meme_pool:fresh", memes.to_json)
```

### After (Lists - Works)
```ruby
# Store IDs in List (50 IDs × 50 bytes = 2.5KB)
memes.each do |meme|
  RedisService.hset("meme:#{meme['id']}", meme.to_json)  # 10KB each
  RedisService.rpush("meme_pool:fresh_ids", meme['id'])   # Just ID
end
RedisService.expire("meme_pool:fresh_ids", 3600)
```

**Why This Works:**
- **Lists**: Only store small IDs (~2.5KB for 50 memes)
- **Hashes**: Individual memes less likely to trigger LRU
- **Total**: 2.5KB list + (50 × 10KB) = 502KB vs 5MB blob
- **LRU Impact**: Smaller keys less likely to be evicted

## Implementation Steps

### Step 1: Add Redis List Methods to RedisService

Add these methods after line 88 in `lib/services/redis_service.rb`:

```ruby
# Push value to end of Redis list
# @param key [String] Redis list key
# @param value [String|Array] Value(s) to push
# @return [Integer] New list length
def rpush(key, *values)
  return 0 unless redis_available?
  
  REDIS_POOL.with do |redis|
    redis.rpush(key, *values)
  end
rescue => e
  handle_error(e, operation: 'rpush', key: key)
  0
end

# Get range of values from Redis list
# @param key [String] Redis list key  
# @param start [Integer] Start index (default 0)
# @param stop [Integer] Stop index (default -1 = all)
# @return [Array<String>] List values
def lrange(key, start = 0, stop = -1)
  return [] unless redis_available?
  
  REDIS_POOL.with do |redis|
    redis.lrange(key, start, stop)
  end
rescue => e
  handle_error(e, operation: 'lrange', key: key)
  []
end

# Get list length
# @param key [String] Redis list key
# @return [Integer] List length
def llen(key)
  return 0 unless redis_available?
  
  REDIS_POOL.with do |redis|
    redis.llen(key)
  end
rescue => e
  handle_error(e, operation: 'llen', key: key)
  0
end

# Set hash field
# @param key [String] Redis hash key
# @param field [String] Hash field name
# @param value [String] Value to store
# @return [Boolean] Success status
def hset(key, field, value)
  return false unless redis_available?
  
  REDIS_POOL.with do |redis|
    redis.hset(key, field, value)
    true
  end
rescue => e
  handle_error(e, operation: 'hset', key: key)
  false
end

# Get hash field
# @param key [String] Redis hash key
# @param field [String] Hash field name
# @return [String|nil] Field value
def hget(key, field)
  return nil unless redis_available?
  
  REDIS_POOL.with do |redis|
    redis.hget(key, field)
  end
rescue => e
  handle_error(e, operation: 'hget', key: key)
  nil
end

# Set expiration on key
# @param key [String] Redis key
# @param seconds [Integer] TTL in seconds
# @return [Boolean] Success status
def expire(key, seconds)
  return false unless redis_available?
  
  REDIS_POOL.with do |redis|
    redis.expire(key, seconds)
    true
  end
rescue => e
  handle_error(e, operation: 'expire', key: key)
  false
end
```

### Step 2: Update MemePoolManager Storage

Find `store_in_pool` method around line 298 in `lib/services/meme_pool_manager.rb` and replace with:

```ruby
# Store memes using Redis Lists (July 13, 2026 - LRU Fix)
def store_in_pool(memes)
  return 0 if memes.empty?
  
  # Categorize memes by tier
  categorized = categorize_by_tier(memes)
  
  total_stored = 0
  categorized.each do |pool_name, pool_memes|
    next if pool_memes.empty?
    
    # Store each meme individually in hash
    pool_memes.each do |meme|
      meme_id = meme['id'] || "#{meme['subreddit']}_#{Time.now.to_i}_#{rand(1000)}"
      RedisService.hset("meme:data", meme_id, meme.to_json)
    end
    
    # Store IDs in list
    list_key = "meme_pool:#{pool_name}_ids"
    RedisService.delete(list_key)  # Clear old
    meme_ids = pool_memes.map { |m| m['id'] || "#{m['subreddit']}_#{Time.now.to_i}" }
    RedisService.rpush(list_key, *meme_ids)
    RedisService.expire(list_key, 3600)  # 1 hour TTL
    
    AppLogger.info("   ✅ Stored #{pool_memes.size} memes in '#{pool_name}' pool (total: #{pool_memes.size})")
    total_stored += pool_memes.size
  end
  
  # Update metadata
  RedisService.set("meme_pool:count", total_stored, ttl: 3600)
  RedisService.set("meme_pool:initialized", "true", ttl: 3600)
  RedisService.set("meme_pool:last_refresh", Time.now.to_i, ttl: 3600)
  
  total_stored
rescue => e
  log_error("Store in pool error", e)
  0
end
```

### Step 3: Update get_tier_pool Method

Around line 287, replace `get_tier_pool`:

```ruby
# Get memes from a specific tier pool (July 13, 2026 - Lists)
def get_tier_pool(pool_name)
  list_key = "meme_pool:#{pool_name}_ids"
  meme_ids = RedisService.lrange(list_key, 0, -1)
  return [] if meme_ids.empty?
  
  # Fetch full meme data for each ID
  memes = meme_ids.map do |meme_id|
    json = RedisService.hget("meme:data", meme_id)
    JSON.parse(json) if json
  end.compact
  
  memes
rescue => e
  AppLogger.error("⚠️  Failed to get tier pool '#{pool_name}': #{e.message}")
  []
end
```

### Step 4: Update DiversityEngine Retrieval

In `lib/services/diversity_engine_service_v2.rb`, find the pool retrieval logic and update it to use the new list-based system. The changes should be minimal since it calls `get_tier_pool` which we've already updated.

## Testing

### 1. Deploy Changes
```bash
git add lib/services/redis_service.rb lib/services/meme_pool_manager.rb
git commit -m "Migrate to Redis Lists to fix LRU eviction"
git push origin main
```

### 2. Wait for Render Deploy (~60s)

### 3. Test in Production
```bash
# In production shell:
bundle exec ruby scripts/fix_empty_redis_pools_july_13_2026.rb
bundle exec ruby scripts/diagnose_redis_pools_july_13.rb
```

### Expected Output
```
✅ Redis read/write WORKING
✅ meme_pool:fresh_ids: 50 IDs
✅ meme_pool:surprise_ids: 45 IDs  
✅ meme_pool:diverse_ids: 18 IDs
✅ No more empty pool warnings!
```

## Benefits

1. **Fixes Eviction**: Small Lists (2.5KB) vs large blobs (5MB)
2. **Better Performance**: Individual meme fetches faster
3. **More Reliable**: Less likely to hit LRU threshold
4. **Scalable**: Can add more memes without hitting limit

## Rollback Plan

If issues arise:
```bash
git revert HEAD
git push origin main
```

The fallback filtering system will continue to work as before.

## Memory Impact

**Before:** 
- 1 key × 5MB = 5MB (evicted immediately)

**After:**
- 1 List × 2.5KB = 2.5KB
- 50 Hashes × 10KB = 500KB  
- **Total: 502KB** (fits in 25MB limit comfortably)

## Conclusion

This migration solves the Redis LRU eviction problem by using smaller, distributed data structures instead of monolithic JSON blobs. The pools will now persist in Redis and eliminate the constant fallback warnings.
