# 📋 Redis Phase 3 - Migration Guide
## Gradual Migration Strategy - June 3, 2026

---

## 🎯 MIGRATION OBJECTIVE

Gradually migrate 84+ direct `REDIS` calls to use `RedisService` wrapper for:
- ✅ Automatic error handling
- ✅ Connection pooling
- ✅ Circuit breaker protection  
- ✅ Consistent fallback logic
- ✅ Centralized logging

**Strategy:** Non-breaking, gradual migration over 3 weeks

---

## 📊 REDIS USAGE AUDIT

### Current Redis Calls in Codebase:

**File: `app.rb` (Primary Usage)**
- `get_meme_likes` method (~line 800-810)
- `toggle_like` method (~line 815-865)
- `get_cached_memes` method (~line 730-750)
- Before/after hooks (session storage)

**File: `lib/services/activity_tracker_service.rb`**
- Real-time user tracking
- Active user counts

**File: `lib/services/leaderboard_service.rb`**
- Sorted set operations
- Score tracking

**Total Estimated:** 84+ calls across application

---

## 🔥 PHASE 3 MIGRATION PLAN

### **WEEK 1: HIGH PRIORITY** (Est: 2-3 hours)

#### 1. Migrate `get_meme_likes` in app.rb

**Current Code** (~line 800):
```ruby
def get_meme_likes(url)
  return 0 unless url
  likes = REDIS&.get("meme:likes:#{url}")&.to_i
  return likes if likes

  row = DB.execute("SELECT likes FROM meme_stats WHERE url = ?", url).first
  likes = row ? row["likes"].to_i : 0
  REDIS&.set("meme:likes:#{url}", likes)
  likes
end
```

**Migrated Code:**
```ruby
def get_meme_likes(url)
  return 0 unless url
  
  # Try Redis first with automatic fallback to DB
  RedisService.fetch("meme:likes:#{url}", ttl: 300) do
    # Fallback: query database
    row = DB.execute("SELECT likes FROM meme_stats WHERE url = ?", url).first
    row ? row["likes"].to_i : 0
  end
end
```

**Benefits:**
- ✅ Automatic error handling
- ✅ Fallback to DB if Redis fails
- ✅ TTL management
- ✅ Circuit breaker protection

---

#### 2. Migrate `toggle_like` in app.rb

**Current Code** (~line 815-865):
```ruby
def toggle_like(url, liked_now, session)
  return 0 unless url
  
  session[:meme_like_counts] ||= {}
  was_liked_before = session[:meme_like_counts][url] || false
  user_id = session[:user_id]
  
  if liked_now && !was_liked_before
    DB.execute("INSERT OR IGNORE INTO meme_stats (url, likes) VALUES (?, 0)", [url])
    DB.execute("UPDATE meme_stats SET likes = likes + 1, updated_at = CURRENT_TIMESTAMP WHERE url = ?", [url])
    
    if user_id
      # ... user stats updates
    end
    session[:meme_like_counts][url] = true
  elsif !liked_now && was_liked_before
    DB.execute("UPDATE meme_stats SET likes = likes - 1, updated_at = CURRENT_TIMESTAMP WHERE url = ? AND likes > 0", [url])
    session[:meme_like_counts][url] = false
  end

  likes = DB.execute("SELECT likes FROM meme_stats WHERE url = ?", [url]).first&.dig("likes").to_i
  REDIS&.set("meme:likes:#{url}", likes)
  likes
end
```

**Migrated Code:**
```ruby
def toggle_like(url, liked_now, session)
  return 0 unless url
  
  session[:meme_like_counts] ||= {}
  was_liked_before = session[:meme_like_counts][url] || false
  user_id = session[:user_id]
  
  if liked_now && !was_liked_before
    DB.execute("INSERT OR IGNORE INTO meme_stats (url, likes) VALUES (?, 0)", [url])
    DB.execute("UPDATE meme_stats SET likes = likes + 1, updated_at = CURRENT_TIMESTAMP WHERE url = ?", [url])
    
    if user_id
      # ... user stats updates
    end
    session[:meme_like_counts][url] = true
  elsif !liked_now && was_liked_before
    DB.execute("UPDATE meme_stats SET likes = likes - 1, updated_at = CURRENT_TIMESTAMP WHERE url = ? AND likes > 0", [url])
    session[:meme_like_counts][url] = false
  end

  # Get updated likes count and cache with RedisService
  likes = DB.execute("SELECT likes FROM meme_stats WHERE url = ?", [url]).first&.dig("likes").to_i
  RedisService.set("meme:likes:#{url}", likes, ttl: 300)  # 5 min cache
  likes
end
```

**Benefits:**
- ✅ Automatic error handling (won't crash if Redis down)
- ✅ Consistent TTL management
- ✅ Logging for failures

---

#### 3. Migrate `get_cached_memes` in app.rb

**Current Code** (~line 730):
```ruby
def get_cached_memes
  cached = REDIS&.get("memes:latest")
  memes = cached ? JSON.parse(cached) : MEME_CACHE.get(:memes) || MEMES

  memes.reject! do |m|
    file_missing = m["file"] && !File.exist?(File.join(settings.public_folder, m["file"]))
    url_invalid  = m["url"] && !m["url"].match?(/^https?:\/\//)
    file_missing || url_invalid
  end

  REDIS&.setex("memes:latest", 300, memes.to_json) rescue nil
  MEME_CACHE.set(:memes, memes)
  memes
rescue => e
  puts "❌ get_cached_memes error: #{e.class} - #{e.message}"
  MEME_CACHE.get(:memes) || MEMES
end
```

**Migrated Code:**
```ruby
def get_cached_memes
  # Use RedisService.fetch with automatic fallback
  memes = RedisService.fetch("memes:latest", ttl: 300) do
    # Fallback: get from memory cache or static data
    MEME_CACHE.get(:memes) || MEMES
  end

  # Filter out invalid memes
  memes.reject! do |m|
    file_missing = m["file"] && !File.exist?(File.join(settings.public_folder, m["file"]))
    url_invalid  = m["url"] && !m["url"].match?(/^https?:\/\//)
    file_missing || url_invalid
  end

  # Update memory cache
  MEME_CACHE.set(:memes, memes)
  memes
rescue => e
  puts "❌ get_cached_memes error: #{e.class} - #{e.message}"
  MEME_CACHE.get(:memes) || MEMES
end
```

**Benefits:**
- ✅ Cleaner code (RedisService handles JSON serialization)
- ✅ Automatic fallback chain
- ✅ Circuit breaker protection

---

### **WEEK 2: MEDIUM PRIORITY** (Est: 4-5 hours)

#### 4. Migrate Activity Tracker Service

**File:** `lib/services/activity_tracker_service.rb`

**Current Pattern:**
```ruby
def self.mark_active(visitor_id, page:, ip_address: nil)
  return unless REDIS
  
  key = "active:#{Time.now.strftime('%Y%m%d%H%M')}"
  REDIS.sadd(key, "#{visitor_id}:#{ip_address}")
  REDIS.expire(key, 300)
end
```

**Migrated Pattern:**
```ruby
def self.mark_active(visitor_id, page:, ip_address: nil)
  RedisService.with_redis do |redis|
    key = "active:#{Time.now.strftime('%Y%m%d%H%M')}"
    redis.sadd(key, "#{visitor_id}:#{ip_address}")
    redis.expire(key, 300)
  end || false  # Returns false if Redis unavailable
end
```

**Benefits:**
- ✅ Graceful degradation (tracking fails silently if Redis down)
- ✅ Connection pool usage
- ✅ Circuit breaker

---

#### 5. Migrate Leaderboard Service

**File:** `lib/services/leaderboard_service.rb`

**Current Pattern:**
```ruby
def self.update_weekly_score(user_id, points)
  return unless REDIS
  
  week_key = "leaderboard:weekly:#{current_week}"
  REDIS.zincrby(week_key, points, user_id)
  REDIS.expire(week_key, 7.days)
end
```

**Migrated Pattern:**
```ruby
def self.update_weekly_score(user_id, points)
  RedisService.with_redis do |redis|
    week_key = "leaderboard:weekly:#{current_week}"
    redis.zincrby(week_key, points, user_id)
    redis.expire(week_key, 7 * 24 * 3600)  # 7 days
  end
end
```

---

#### 6. Migrate Session Storage (Before/After Hooks)

**File:** `app.rb` - Before/After hooks

**Current:**
```ruby
before do
  if REDIS && session[:user_id]
    @redis_meme_history_key = "user:#{session[:user_id]}:meme_history"
    @redis_meme_likes_key = "user:#{session[:user_id]}:meme_like_counts"
  end
end
```

**Migrated:**
```ruby
before do
  if RedisService.redis_available? && session[:user_id]
    @redis_meme_history_key = "user:#{session[:user_id]}:meme_history"
    @redis_meme_likes_key = "user:#{session[:user_id]}:meme_like_counts"
  end
end
```

---

### **WEEK 3: LOW PRIORITY** (Est: 3-4 hours)

#### 7-10. Migrate Remaining Services

**Services to migrate:**
- Cache invalidation helpers
- Admin tools (cache clearing)
- Background workers
- Test/development code

**Pattern:** Same as above - replace `REDIS&.method` with `RedisService.method` or `RedisService.with_redis { |r| r.method }`

---

## 🛠️ MIGRATION CHECKLIST

### Before Each Migration:
- [ ] Identify the file and method
- [ ] Read current implementation
- [ ] Write migrated version
- [ ] Test locally (verify no errors)
- [ ] Deploy to staging
- [ ] Monitor for 24 hours
- [ ] Deploy to production

### Testing Strategy:
```ruby
# Test Redis availability
RedisService.ping  # => true/false

# Test fallback behavior (simulate Redis down)
# Temporarily comment out REDIS_URL in .env
# Verify app still works (using fallbacks)

# Monitor logs for errors
grep "Redis error" logs/production.log
```

---

## 📊 MIGRATION TRACKING

| Week | Component | Files | Est. Time | Status |
|------|-----------|-------|-----------|--------|
| 1 | get_meme_likes | app.rb | 30 min | ⬜ Not started |
| 1 | toggle_like | app.rb | 1 hour | ⬜ Not started |
| 1 | get_cached_memes | app.rb | 30 min | ⬜ Not started |
| 2 | Activity Tracker | activity_tracker_service.rb | 2 hours | ⬜ Not started |
| 2 | Leaderboard | leaderboard_service.rb | 2 hours | ⬜ Not started |
| 2 | Session hooks | app.rb | 1 hour | ⬜ Not started |
| 3 | Remaining | Various | 3 hours | ⬜ Not started |

**Total Estimate:** 10-12 hours over 3 weeks

---

## 🎯 SUCCESS METRICS

### Before Migration:
```ruby
# Check current Redis usage
grep -r "REDIS\&\." app.rb lib/ | wc -l  # Count direct calls
```

### After Migration:
```ruby
# Should be significantly reduced
grep -r "REDIS\&\." app.rb lib/ | wc -l  # Should be ~0

# New pattern dominant
grep -r "RedisService\." app.rb lib/ | wc -l  # Should be high
```

### Monitoring:
```ruby
# Check RedisService stats
RedisService.stats
# => {
#   available: true,
#   hit_rate: 95.2,
#   pool_size: 40,
#   pool_available: 38,
#   ...
# }

# Check for errors
grep "Redis error" logs/*.log | tail -20
```

---

## 🚨 ROLLBACK PLAN

If issues occur after migration:

### 1. Quick Rollback (Git)
```bash
git revert HEAD  # Revert last commit
git push origin main
```

### 2. Partial Rollback
```ruby
# Keep RedisService available but revert specific methods
# Change back to REDIS&.method pattern for problematic code
```

### 3. Monitor After Rollback
```bash
# Check error rates return to normal
curl https://your-app.com/health | jq '.checks.redis'
```

---

## 💡 BEST PRACTICES

### DO:
✅ Migrate one method at a time  
✅ Test thoroughly in staging  
✅ Monitor logs for 24 hours  
✅ Keep fallbacks in place  
✅ Document changes in commit messages

### DON'T:
❌ Migrate everything at once  
❌ Skip staging testing  
❌ Remove error handling  
❌ Change behavior  
❌ Deploy on Fridays

---

## 📚 CODE EXAMPLES REFERENCE

### Pattern 1: Simple Get/Set
```ruby
# OLD
likes = REDIS&.get("key")&.to_i || 0
REDIS&.set("key", value)

# NEW
likes = RedisService.get("key", default: 0)
RedisService.set("key", value, ttl: 300)
```

### Pattern 2: Get with DB Fallback
```ruby
# OLD
cached = REDIS&.get("key")
return JSON.parse(cached) if cached
data = fetch_from_db
REDIS&.setex("key", 600, data.to_json)
data

# NEW
RedisService.fetch("key", ttl: 600) do
  fetch_from_db
end
```

### Pattern 3: Complex Operations (Sorted Sets)
```ruby
# OLD
REDIS&.zadd("leaderboard", score, user_id)
REDIS&.zrevrange("leaderboard", 0, 9)

# NEW
RedisService.with_redis do |redis|
  redis.zadd("leaderboard", score, user_id)
  redis.zrevrange("leaderboard", 0, 9)
end || []  # Fallback to empty array
```

### Pattern 4: Availability Check
```ruby
# OLD
if REDIS
  # do something
end

# NEW
if RedisService.redis_available?
  # do something
end
```

---

## 🎉 COMPLETION CRITERIA

Phase 3 is complete when:
- [x] All high-priority methods migrated (Week 1)
- [x] All medium-priority methods migrated (Week 2)
- [x] All low-priority methods migrated (Week 3)
- [x] Zero direct `REDIS&.` calls remain in critical paths
- [x] All tests passing
- [x] Production stable for 1 week
- [x] Redis pool metrics healthy
- [x] No increase in error rates

---

## 📞 SUPPORT

**Issues During Migration:**
1. Check logs: `grep "Redis" logs/*.log`
2. Check health: `curl /health | jq '.checks.redis'`
3. Check pool: `RedisService.stats`
4. Rollback if needed (see Rollback Plan)

**Questions:**
- Review `lib/services/redis_service.rb` for method documentation
- Check `REDIS_PHASE_2_COMPLETE.md` for examples
- Run `RedisService.stats` for diagnostics

---

**Phase 3 Status:** 📋 **PLANNING COMPLETE**  
**Ready to Execute:** ✅ **YES**  
**Estimated Duration:** 3 weeks (10-12 hours total)  
**Risk Level:** LOW (gradual, tested approach)

---

**Created by:** Senior Ruby Developer  
**Date:** June 3, 2026  
**Next Action:** Begin Week 1 migrations with `get_meme_likes`
