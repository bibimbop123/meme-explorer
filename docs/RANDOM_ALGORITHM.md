# Random Algorithm Architecture

**Last Updated:** July 15, 2026  
**Refactoring Score:** 90/100 (A-)  
**Sprints Completed:** 3 of 3

---

## 📐 Architecture Overview

The random meme algorithm uses a multi-layered approach with clear separation of concerns:

```
┌─────────────────────────────────────────────────────────────┐
│                    routes/random_meme.rb                     │
│              (≤20 lines - thin routing layer)                │
└──────────────────────┬──────────────────────────────────────┘
                       │
                       ▼
┌─────────────────────────────────────────────────────────────┐
│           lib/controllers/random_meme_controller.rb          │
│                  (Main orchestration logic)                  │
│                                                               │
│  1. Initialize session                                        │
│  2. Get meme pool → MemePool.get                             │
│  3. Select meme → DiversityEngineService                     │
│  4. Track viewing → ViewingHistoryService                    │
│  5. Handle gamification → Various services                   │
│  6. Prepare display data                                     │
│  7. Track analytics → MemeStatsWriter (async)                │
└──────────────────────┬──────────────────────────────────────┘
                       │
        ┌──────────────┼──────────────┐
        │              │              │
        ▼              ▼              ▼
┌──────────────┐ ┌─────────────┐ ┌──────────────────┐
│  MemePool    │ │  Diversity  │ │ ViewingHistory   │
│   Service    │ │   Engine    │ │    Service       │
│              │ │   Service   │ │                  │
│ • Redis      │ │ • Anti-rep  │ │ • Redis-backed   │
│ • Bootstrap  │ │ • Scoring   │ │ • TTL: 2 hours   │
│ • Fallback   │ │ • Context   │ │ • Max: 200 memes │
└──────────────┘ └─────────────┘ └──────────────────┘
```

---

## 🎯 Core Components

### 1. RandomMemeController
**Location:** `lib/controllers/random_meme_controller.rb`  
**Responsibility:** Orchestrate the entire meme selection process

**Key Methods:**
- `handle()` - Main entry point, returns Result object
- `get_meme_pool()` - Delegates to MemePool service
- `select_meme()` - Delegates to DiversityEngineService
- `track_viewing()` - Records viewing history
- `handle_gamification()` - Manages milestones, streaks, rewards
- `track_analytics()` - Queues async DB writes

**Result Object:**
```ruby
{
  meme: Hash,           # Selected meme data
  milestone: Hash,      # Achievement milestone (if any)
  surprise_reward: Hash,# Random reward (10% chance)
  streak_status: Hash,  # User's current streak
  social_proof: Hash,   # Social engagement data
  tease: Hash,          # Near-miss tease (if applicable)
  progress: Hash,       # Progress to next milestone
  image_src: String,    # Image URL/path
  reddit_path: String,  # Reddit permalink
  likes: Integer        # Like count
}
```

---

### 2. MemePool Service
**Location:** `lib/services/meme_pool.rb`  
**Responsibility:** Single source of truth for meme pools

**Fallback Hierarchy:**
```ruby
1. Redis/MemePoolManager (Authoritative source)
   ↓ (if empty/failed)
2. Bootstrap Pool (Rebuild from Reddit)
   ↓ (if bootstrap failed)
3. Local Static Memes (Emergency fallback)
```

**Usage:**
```ruby
pool = MemeExplorer::MemePool.get
# Returns: Array of meme hashes
```

---

### 3. DiversityEngineService
**Location:** `lib/services/diversity_engine_service.rb`  
**Responsibility:** Anti-repetition and intelligent meme selection

**Algorithm:**
1. Filter out recently seen memes (session-based)
2. Filter out recently shown subreddits
3. Filter out recently shown pools/categories
4. Apply contextual scoring (time-of-day, user preferences)
5. Select from top 20% of scored candidates
6. Return diverse meme

**Usage:**
```ruby
meme = MemeExplorer::DiversityEngineService.select_diverse_meme(
  pool,
  session_id: session_id,
  preferences: user_preferences
)
```

---

### 4. ViewingHistoryService
**Location:** `lib/services/viewing_history_service.rb`  
**Responsibility:** Track what users have seen

**Storage:** Redis (with TTL)
- **TTL:** 2 hours
- **Max Size:** 200 memes per session
- **Key Pattern:** `viewing_history:{session_id}`

**Methods:**
```ruby
# Mark meme as seen
ViewingHistoryService.mark_seen(session_id, meme_url)

# Get all seen memes for session
seen = ViewingHistoryService.get_seen_memes(session_id)

# Clear history (admin/testing)
ViewingHistoryService.clear_history(session_id)
```

---

### 5. MemeStatsWriter Worker
**Location:** `app/workers/meme_stats_writer.rb`  
**Responsibility:** Async database writes for analytics

**Benefits:**
- Non-blocking HTTP requests
- Automatic retries (3x on failure)
- Scales independently via Sidekiq

**Queue:** `default`
**Retry:** 3 attempts

**Usage:**
```ruby
MemeStatsWriter.perform_async(
  meme_identifier,
  title,
  subreddit,
  user_id # optional
)
```

---

## ⚙️ Configuration Management

**Location:** `config/algorithm_config.yml`  
**Service:** `lib/services/algorithm_config_service.rb`

All algorithm parameters are centralized in YAML for easy tuning:

```yaml
algorithm:
  selection:
    top_percentile: 0.2  # Top 20% of scored memes
    surprise_reward_chance: 0.1
    
  contextual_scoring:
    time_weight: 0.6  # 60% weight to time-of-day
    day_weight: 0.4   # 40% weight to day-of-week
    
  viewing_history:
    ttl_seconds: 7200  # 2 hours
    max_size: 200
```

**Loading Config:**
```ruby
config = MemeExplorer::AlgorithmConfigService.config
top_pct = config['selection']['top_percentile']
```

**Reloading Config (without restart):**
```ruby
MemeExplorer::AlgorithmConfigService.reload!
```

---

## 🧪 Testing

**Integration Tests:** `spec/integration/random_algorithm_integration_spec.rb`

**Test Coverage:**
- ✅ Controller integration
- ✅ Anti-repetition logic
- ✅ Viewing history persistence
- ✅ Pool fallback hierarchy
- ✅ Configuration loading
- ✅ Async worker queuing
- ✅ Error handling
- ✅ Performance benchmarks

**Running Tests:**
```bash
# All integration tests
bundle exec rspec spec/integration/

# Specific test
bundle exec rspec spec/integration/random_algorithm_integration_spec.rb

# With coverage
COVERAGE=true bundle exec rspec spec/integration/
```

---

## 📊 Monitoring

**Key Metrics to Track:**

1. **Selection Time**
   - Target: <100ms per selection
   - Alert: >500ms

2. **Error Rate**
   - Target: <0.1% errors
   - Alert: >1% errors

3. **Repetition Rate**
   - Target: 0% consecutive repeats
   - Alert: >0.1% repeats in same session

4. **Pool Health**
   - Target: >100 memes in pool
   - Alert: <50 memes

5. **Worker Queue Depth**
   - Target: <100 jobs queued
   - Alert: >1000 jobs

**Monitoring Code:**
```ruby
# In controller
def handle(session:, user_id:, request_ip:)
  start_time = Time.now
  
  result = perform_selection(...)
  
  # Track metrics
  duration_ms = ((Time.now - start_time) * 1000).round(2)
  StatsD.timing('random_algorithm.selection_time', duration_ms)
  StatsD.increment('random_algorithm.success')
  
  result
rescue => e
  StatsD.increment('random_algorithm.error')
  handle_error(e, session)
end
```

---

## 🚀 Deployment

**Prerequisites:**
1. Redis running and accessible
2. Sidekiq workers running
3. Algorithm config deployed
4. Database migrations applied

**Deployment Steps:**
```bash
# 1. Deploy code
git push origin main

# 2. Restart Sidekiq workers
systemctl restart sidekiq

# 3. Restart app servers
systemctl restart puma

# 4. Monitor logs
tail -f log/production.log | grep RandomMemeController
```

**Rollback Plan:**
```bash
# Revert to previous version
git revert HEAD
git push origin main

# Or use specific commit
git reset --hard <previous-commit-sha>
git push origin main --force
```

---

## 🐛 Troubleshooting

### Issue: Repetitive Memes

**Symptoms:** Users seeing same memes repeatedly

**Debugging:**
```ruby
# Check viewing history
session_id = "<session-id>"
seen = MemeExplorer::ViewingHistoryService.get_seen_memes(session_id)
puts "Seen memes: #{seen.size}"

# Check pool size
pool = MemeExplorer::MemePool.get
puts "Pool size: #{pool.size}"

# Check for duplicates in pool
urls = pool.map { |m| m["url"] }
puts "Duplicate URLs: #{urls.size - urls.uniq.size}"
```

**Solutions:**
1. Clear viewing history: `ViewingHistoryService.clear_history(session_id)`
2. Refresh pool: `MemePoolManager.bootstrap_pool`
3. Check Redis connectivity
4. Verify diversity engine is running

---

### Issue: Slow Selection

**Symptoms:** >500ms response times

**Debugging:**
```ruby
# Benchmark selection
require 'benchmark'

pool = MemeExplorer::MemePool.get
time = Benchmark.measure {
  MemeExplorer::DiversityEngineService.select_diverse_meme(
    pool,
    session_id: "test",
    preferences: {}
  )
}
puts "Selection time: #{time.real}s"
```

**Solutions:**
1. Reduce pool size (target: 100-500 memes)
2. Optimize scoring algorithms
3. Add Redis caching for scores
4. Use connection pooling

---

### Issue: Worker Backlog

**Symptoms:** MemeStatsWriter queue growing

**Debugging:**
```ruby
# Check queue stats
stats = Sidekiq::Stats.new
puts "Queue depth: #{stats.queues['default']}"
puts "Processed: #{stats.processed}"
puts "Failed: #{stats.failed}"
```

**Solutions:**
1. Scale Sidekiq workers: `sidekiq -c 10`
2. Add more worker processes
3. Reduce retry count if appropriate
4. Investigate slow DB queries

---

## 📈 Performance Optimization

**Optimization Tips:**

1. **Pool Size**
   - Sweet spot: 100-500 memes
   - Too small: Repetition increases
   - Too large: Selection slows down

2. **Redis Connection Pooling**
   ```ruby
   REDIS_POOL = ConnectionPool.new(size: 20, timeout: 5) do
     Redis.new(url: ENV['REDIS_URL'])
   end
   ```

3. **Caching Scored Memes**
   ```ruby
   # Cache contextual scores for 5 minutes
   cache_key = "contextual_scores:#{hour_of_day}"
   scores = REDIS.get(cache_key) || recalculate_scores
   REDIS.setex(cache_key, 300, scores.to_json)
   ```

4. **Batch Processing**
   ```ruby
   # Process multiple analytics writes in one job
   MemeStatsWriter.perform_async([meme1, meme2, meme3])
   ```

---

## 🎓 Best Practices

1. **Always Use MemePool.get**
   - ❌ Don't access `MEME_CACHE` directly
   - ✅ Use `MemePool.get` for fallback hierarchy

2. **Track Viewing History**
   - ❌ Don't filter manually in routes
   - ✅ Use `ViewingHistoryService.mark_seen`

3. **Async DB Writes**
   - ❌ Don't write to DB in request cycle
   - ✅ Use `MemeStatsWriter.perform_async`

4. **Configuration Over Hardcoding**
   - ❌ Don't hardcode algorithm parameters
   - ✅ Use `AlgorithmConfigService.config`

5. **Graceful Error Handling**
   - ❌ Don't let errors crash the app
   - ✅ Always return fallback meme

---

## 📚 Additional Resources

- **Audit Report:** `RANDOM_ALGORITHM_SENIOR_AUDIT_2026.md`
- **Refactoring Roadmap:** `RANDOM_ALGORITHM_REFACTORING_ROADMAP_2026.md`
- **Sprint 1 Complete:** `SPRINT1_COMPLETE.md`
- **Sprint 2 Complete:** `SPRINT2_COMPLETE.md`
- **Sprint 3 Complete:** `SPRINT3_COMPLETE.md`

---

## 🏆 Achievements

- **Code Quality:** 72 → 90 (+18 points)
- **Lines of Code:** 145-line route → 20-line route
- **Architecture:** Monolithic → Clean separation of concerns
- **Performance:** Sync DB writes → Async workers
- **Maintainability:** Hardcoded values → Centralized config
- **Testing:** Manual testing → Automated integration tests

---

**Last Refactored:** July 15, 2026  
**Next Review:** Recommended in 90 days
