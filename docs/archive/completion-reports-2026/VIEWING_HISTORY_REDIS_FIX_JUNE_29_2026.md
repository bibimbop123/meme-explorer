# Viewing History Redis Fix - June 29, 2026

## 🚨 Production Error

**Error Message:**
```
Failed to mark meme as seen: undefined method `zadd' for RedisService:Class
```

**Request ID:** `f5c7847b-cebf-4c17-8bb6-eb6fae361a4c`  
**Timestamp:** June 29, 2026, 00:21:38 UTC  
**Severity:** ERROR  
**Environment:** Production

---

## 🔍 Root Cause Analysis

The `ViewingHistoryService` was calling Redis sorted set methods (like `zadd`, `zremrangebyrank`, `expire`, etc.) directly on the `RedisService` class, but these methods don't exist as class methods.

### The Problem

```ruby
# ❌ INCORRECT - These methods don't exist on RedisService
RedisService.zadd(key, Time.now.to_i, meme_identifier)
RedisService.zremrangebyrank(key, 0, -(MAX_HISTORY_SIZE + 1))
RedisService.expire(key, HISTORY_TTL)
```

### The Solution

The correct pattern is to use `RedisService.with_redis` to get a Redis connection from the pool, then call the methods on that connection:

```ruby
# ✅ CORRECT - Use with_redis to access the connection pool
RedisService.with_redis do |redis|
  redis.zadd(key, Time.now.to_i, meme_identifier)
  redis.zremrangebyrank(key, 0, -(MAX_HISTORY_SIZE + 1))
  redis.expire(key, HISTORY_TTL)
end
```

---

## 📝 Changes Made

### File: `lib/services/viewing_history_service.rb`

Updated all Redis operations to use the correct pattern:

1. **mark_seen** - Wraps zadd, zremrangebyrank, and expire in `with_redis` block
2. **get_seen_memes** - Wraps zrange in `with_redis` block
3. **seen?** - Wraps zscore in `with_redis` block
4. **seen_count** - Wraps zcard in `with_redis` block
5. **clear_history** - Wraps del in `with_redis` block
6. **get_stats** - Wraps zcard and ttl in `with_redis` block

### Benefits of This Approach

- ✅ **Proper connection pooling** - Uses the REDIS_POOL correctly
- ✅ **Error handling** - Leverages RedisService's built-in error handling
- ✅ **Graceful degradation** - Returns nil if Redis is unavailable
- ✅ **Circuit breaker** - Prevents hammering Redis when it's down
- ✅ **Consistent logging** - Uses RedisService's error logging

---

## 🎯 Impact

### What Was Broken
- Viewing history tracking was failing silently
- Users might see repeated memes because "seen" tracking wasn't working
- Error logs were being generated on every meme view

### What's Fixed Now
- Viewing history properly tracks seen memes in Redis sorted sets
- Anti-repetition algorithm can correctly exclude already-seen memes
- No more "undefined method `zadd`" errors

---

## 🚀 Deployment

### Automatic Deployment
This fix will be deployed automatically when you push to the main branch. Render will:
1. Pull the latest code
2. Restart the web service
3. Apply the fix immediately

### Manual Testing (Optional)
```bash
# Make the script executable
chmod +x scripts/deploy_viewing_history_fix_june_29.sh

# Run the deployment script (production only)
./scripts/deploy_viewing_history_fix_june_29.sh
```

---

## 📊 Monitoring

After deployment, monitor for:

### ✅ Success Indicators
- No more "undefined method `zadd`" errors in logs
- "📝 Marked meme as seen" debug logs appear correctly
- Users don't see the same meme repeatedly in the same session
- Redis connection pool stats show healthy connections

### ⚠️ Watch For
- Any new Redis-related errors
- Increase in Redis connection pool timeouts
- Users reporting seeing too many repeated memes

### Verification Commands

```bash
# Check for the error (should return nothing after fix)
heroku logs --tail | grep "undefined method.*zadd"

# Verify viewing history is working
heroku logs --tail | grep "Marked meme as seen"

# Check Redis health
heroku run rails console
> RedisService.stats
```

---

## 🔧 Technical Details

### RedisService Architecture

The `RedisService` class provides these patterns:

```ruby
# Simple get/set with automatic fallback
RedisService.get(key, default: nil)
RedisService.set(key, value, ttl: 3600)

# Direct Redis access for advanced operations
RedisService.with_redis do |redis|
  redis.zadd(key, score, member)
  redis.zrange(key, 0, -1)
  # ... any Redis command
end
```

### Why This Pattern Exists

1. **Connection Pooling** - Manages a pool of Redis connections efficiently
2. **Error Handling** - Automatic retry logic and graceful degradation
3. **Circuit Breaker** - Prevents cascading failures when Redis is down
4. **Monitoring** - Centralized logging and metrics collection
5. **Consistency** - Single source of truth for Redis access patterns

---

## 📚 Related Documentation

- `lib/services/redis_service.rb` - Core Redis service implementation
- `REDIS_PHASE_3_MIGRATION_GUIDE.md` - Redis architecture migration guide
- `VIEWING_HISTORY_FIX_COMPLETE.md` - Previous viewing history improvements

---

## ✨ Summary

**Problem:** ViewingHistoryService was calling non-existent class methods on RedisService  
**Solution:** Use `RedisService.with_redis` pattern to access the connection pool  
**Impact:** Viewing history tracking now works correctly, preventing meme repetition  
**Status:** ✅ Ready for deployment

---

**Fixed by:** Cline AI Assistant  
**Date:** June 29, 2026  
**Priority:** P0 - Critical Production Bug  
**Estimated Downtime:** None (hot fix)
