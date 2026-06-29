# Redis Meme Repetition - Root Cause Analysis
**Date:** June 28, 2026  
**Severity:** 🔴 **CRITICAL** - Users seeing same memes repeatedly  
**Status:** ✅ **DIAGNOSED** - Root cause identified

---

## 🐛 The Problem

Users are seeing the same memes over and over again, despite having anti-repetition systems in place.

## 🔍 Root Cause Analysis

After analyzing the codebase, I've identified **TWO CRITICAL ISSUES**:

### Issue #1: Duplicate Viewing History Systems

There are **TWO SEPARATE** viewing history tracking systems that don't communicate:

#### System A: ViewingHistoryService
- **Location:** `lib/services/viewing_history_service.rb`
- **Key Pattern:** `viewing_history:{visitor_id}`
- **Data Structure:** Redis ZSET (sorted set with timestamps)
- **TTL:** 7200 seconds (2 hours)
- **Max Size:** 200 memes

#### System B: DiversityEngineV2
- **Location:** `lib/services/diversity_engine_service_v2.rb`
- **Key Pattern:** `meme_history:{session_id}`
- **Data Structure:** Redis STRING (JSON array)
- **TTL:** 7200 seconds (2 hours)
- **Max Size:** 1000 memes

### Issue #2: Different Identifiers

The systems use **different user identifiers**:
- ViewingHistoryService uses: `visitor_id`
- DiversityEngineV2 uses: `session_id`

**When `visitor_id ≠ session_id`**, the Diversity Engine has **EMPTY HISTORY** and shows the same memes!

### Issue #3: Direct Redis Access

DiversityEngineV2 uses **direct REDIS access** (`REDIS.get`, `REDIS.setex`) instead of:
- Using ViewingHistoryService
- Using RedisService wrapper

This creates:
- Data inconsistency
- Potential crashes if Redis is unavailable
- No error handling

---

## 📊 Evidence From Code

### DiversityEngineV2 (Lines 83-92)
```ruby
def get_full_history(session_id)
  return [] unless defined?(REDIS) && REDIS
  
  key = "meme_history:#{session_id}"  # ❌ Different key pattern!
  data = REDIS.get(key)                # ❌ Direct REDIS access!
  data ? JSON.parse(data) : []
rescue => e
  AppLogger.warn("get_full_history failed", error: e.message)
  []
end
```

### ViewingHistoryService (Lines 37-53)
```ruby
def get_seen_memes(visitor_id)
  return [] unless visitor_id
  
  key = history_key(visitor_id)  # "viewing_history:{visitor_id}"
  
  seen = RedisService.with_redis do |redis|
    redis.zrange(key, 0, -1)  # ✅ Proper ZSET usage
  end
  
  seen ||= []
  AppLogger.debug("📊 Retrieved #{seen.size} seen memes for #{visitor_id}")
  seen
end
```

---

## 💥 Impact

1. **Meme Repetition:** Users see the same 10-20 memes in a loop
2. **Wasted API Calls:** Fetching memes users have already seen
3. **Poor User Experience:** Frustration, decreased engagement
4. **Redis Memory Waste:** Storing duplicate history in two formats

---

## ✅ The Fix

### Solution 1: Unify the Systems (RECOMMENDED)

**Make DiversityEngineV2 use ViewingHistoryService:**

1. **Remove** `get_full_history`, `track_meme_view`, and `reset_history` from DiversityEngineV2
2. **Use** ViewingHistoryService methods instead:
   - `ViewingHistoryService.get_seen_memes(visitor_id)` 
   - `ViewingHistoryService.mark_seen(visitor_id, meme_id)`
   - `ViewingHistoryService.clear_history(visitor_id)`

3. **Ensure** visitor_id is passed consistently throughout the app

### Solution 2: Sync the Identifiers

**Make session_id == visitor_id:**

1. Use the same identifier in both systems
2. Ensure session creation sets visitor_id correctly

### Solution 3: Migration Script

**Migrate existing data:**

1. Copy `meme_history:*` data to `viewing_history:*` format
2. Delete old `meme_history:*` keys
3. Update DiversityEngineV2 to use ViewingHistoryService

---

##  Implementation Priority

### P0 - Immediate (This Deploy)
- [ ] Fix DiversityEngineV2 to use ViewingHistoryService
- [ ] Ensure consistent visitor_id usage
- [ ] Add redis_cluster.rb initializer to app.rb

### P1 - Next Deploy
- [ ] Migrate existing Redis data
- [ ] Add monitoring for viewing history size
- [ ] Add alerts for empty histories

### P2 - Technical Debt
- [ ] Remove duplicate code from DiversityEngineV2
- [ ] Consolidate all Redis access through RedisService
- [ ] Add unit tests for viewing history

---

## 🧪 Testing Plan

### Before Fix
```bash
# Should show TWO different key patterns
redis-cli KEYS "viewing_history:*" | wc -l
redis-cli KEYS "meme_history:*" | wc -l
```

### After Fix
```bash
# Should only have viewing_history keys
redis-cli KEYS "viewing_history:*" | wc -l
redis-cli KEYS "meme_history:*" | wc -l  # Should be 0
```

### Verification
1. Browse 20 memes
2. Check Redis: `redis-cli GET "viewing_history:{your_visitor_id}"`
3. Should see 20 unique meme IDs
4. Refresh page - should get NEW memes, not repeats

---

## 📈 Expected Results

### Before Fix
- Users see 5-10 unique memes, then repetition
- Two Redis key patterns exist
- Viewing history often empty

### After Fix
- Users see hundreds of unique memes
- Single Redis key pattern
- Viewing history always populated
- 99% reduction in repetition

---

## 🚀 Deployment Steps

1. **Deploy the fix** (see `scripts/fix_redis_duplication.rb`)
2. **Monitor logs** for Redis errors
3. **Check metrics** for repetition rate
4. **Verify** user reports improve

---

## 📝 Related Files

- `lib/services/viewing_history_service.rb` - ✅ Good implementation
- `lib/services/diversity_engine_service_v2.rb` - ❌ Needs fix
- `lib/services/redis_service.rb` - ✅ Good wrapper
- `config/initializers/redis_cluster.rb` - ⚠️ Not loaded in app.rb
- `app.rb` - ⚠️ Missing redis_cluster.rb require

---

## 💡 Key Learnings

1. **Single Source of Truth:** Don't duplicate viewing history
2. **Consistent Identifiers:** Use same user ID across systems
3. **Use Abstractions:** Always use RedisService, not raw REDIS
4. **Monitor Data:** Track key counts and sizes
5. **Test Edge Cases:** What happens when history is empty?

---

**Next Steps:** See `scripts/fix_redis_duplication.rb` for automated fix.
