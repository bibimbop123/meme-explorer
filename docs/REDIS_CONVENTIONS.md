# Redis Key Naming Conventions
**Week 1 Day 6-7** | **Date:** July 15, 2026

---

## 🎯 Purpose

Standardize Redis key naming for:
- Easy debugging
- Consistent TTLs
- Memory management
- Performance monitoring

---

## 📋 Key Naming Pattern

```
{namespace}:{entity}:{identifier}:{suffix}
```

### Examples:

```
meme:pool:funny:tier1          - Meme pool for 'funny' category, tier 1
user:session:12345              - User session for user ID 12345
cache:trending:all:50           - Trending cache, all categories, 50 items
history:viewing:67890           - Viewing history for user 67890
stats:daily:2026-07-15          - Daily statistics for specific date
lock:subreddit:wholesomememes   - Lock for subreddit fetching
```

---

## 🏷️ Namespace Definitions

| Namespace | Purpose | Default TTL | Example |
|-----------|---------|-------------|---------|
| `meme:*` | Meme pools | 1 hour | `meme:pool:funny:tier1` |
| `user:*` | User data | 24 hours | `user:session:123` |
| `cache:*` | Cache data | 5-15 min | `cache:trending:all:50` |
| `history:*` | User history | 24 hours | `history:viewing:456` |
| `stats:*` | Statistics | 1 hour | `stats:daily:2026-07-15` |
| `lock:*` | Distributed locks | 30 seconds | `lock:subreddit:funny` |
| `config:*` | Configuration | Never expires | `config:feature_flags` |

---

## ⏱️ TTL Guidelines

### Short TTL (< 5 minutes)
- Trending data
- Real-time stats
- Distributed locks

### Medium TTL (5-60 minutes)
- Meme pools
- Search results
- Computed values

### Long TTL (1-24 hours)
- User sessions
- Viewing history
- Daily aggregates

### No TTL (Persistent)
- Feature flags
- Configuration
- Critical system state

**⚠️ Default:** If unsure, use **24 hours**

---

## 🛠️ Implementation

### Setting Keys with TTL

```ruby
# Good: Set key with TTL in one operation
RedisService.setex("cache:trending:all:50", 300, data.to_json)

# Bad: Set key without TTL
RedisService.set("cache:trending:all:50", data.to_json) # ❌ Memory leak!
```

### Checking TTLs

```ruby
# Check if key has TTL
ttl = RedisService.ttl("meme:pool:funny:tier1")
# -1 = no expiry (BAD!)
# -2 = key doesn't exist
# > 0 = seconds until expiry (GOOD!)
```

### Setting TTL on Existing Keys

```ruby
# Set 24-hour TTL on existing key
RedisService.expire("user:session:123", 86400)
```

---

## 🧹 Cleanup Script

Run weekly to find keys without TTL:

```bash
ruby scripts/set_redis_ttls.rb
```

---

## 📊 Monitoring

### Check Redis Memory

```bash
redis-cli INFO memory
```

### Find Keys Without TTL

```ruby
keys_without_ttl = RedisService.redis_pool.with do |redis|
  redis.keys('*').select { |k| redis.ttl(k) == -1 }
end
```

### Memory Usage by Namespace

```ruby
namespaces = {}
RedisService.redis_pool.with do |redis|
  redis.keys('*').each do |key|
    namespace = key.split(':').first
    namespaces[namespace] ||= 0
    namespaces[namespace] += redis.strlen(key)
  end
end
```

---

## ✅ Best Practices

1. **Always set TTL** when creating keys
2. **Use descriptive names** with clear namespaces
3. **Document new namespaces** in this file
4. **Run cleanup script** weekly
5. **Monitor memory usage** monthly
6. **Invalidate caches** when data changes
7. **Use shorter TTLs** for frequently changing data

---

## 🚨 Anti-Patterns

❌ **Don't:**
- Create keys without TTL
- Use generic names like `data` or `temp`
- Mix data types in one namespace
- Store large objects (>1MB)
- Use Redis as primary database

✅ **Do:**
- Set TTL on every key
- Use clear, hierarchical naming
- Keep values small (<100KB ideal)
- Use database for persistence
- Cache computed/expensive data

---

**Last Updated:** July 15, 2026  
**Maintainer:** Engineering Team  
**Review Frequency:** Quarterly
