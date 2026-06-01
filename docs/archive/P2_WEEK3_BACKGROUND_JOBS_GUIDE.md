# 🔄 P2 Week 3: Background Jobs with Sidekiq
**Date:** May 11, 2026  
**Estimated Time:** 4-6 hours  
**Status:** READY TO EXECUTE  
**Complexity:** MEDIUM

---

## 🎯 Objectives

Convert blocking background threads to proper Sidekiq workers for:
1. **Cache Refresh** - Reddit meme fetching (currently Thread.new)
2. **Leaderboard Calculation** - Weekly score updates
3. **Database Cleanup** - Old record removal
4. **Activity Stats Aggregation** - Real-time visitor tracking

### Why Sidekiq?

**Current Problems:**
- ❌ Threads die silently on errors
- ❌ No retry logic
- ❌ No monitoring/observability
- ❌ Memory leaks from long-running threads
- ❌ Can't scale horizontally

**Sidekiq Benefits:**
- ✅ Automatic retries with exponential backoff
- ✅ Web UI for monitoring
- ✅ Job persistence (survives server restarts)
- ✅ Horizontal scaling (add more workers)
- ✅ Better error handling and logging

---

## 📋 Prerequisites

### 1. Add Sidekiq Gem
**File:** `Gemfile`
```ruby
# Background job processing
gem 'sidekiq', '~> 7.0'
gem 'sidekiq-scheduler', '~> 5.0'  # For cron-like scheduling
```

Run: `bundle install`

### 2. Configure Redis (Already Have!)
Sidekiq uses Redis - you already have `REDIS_URL` configured! ✅

### 3. Create Sidekiq Config
**File:** `config/sidekiq.yml`
```yaml
---
:concurrency: 5
:timeout: 25
:queues:
  - critical  # Leaderboard calculations
  - default   # Cache refresh
  - low       # Cleanup tasks

# Scheduler configuration
:schedule:
  cache_refresh:
    cron: '*/10 * * * *'  # Every 10 minutes
    class: CacheRefreshWorker
    queue: default
    
  leaderboard_update:
    cron: '0 * * * *'  # Every hour
    class: LeaderboardCalculationWorker
    queue: critical
    
  database_cleanup:
    cron: '0 2 * * *'  # Daily at 2 AM
    class: DatabaseCleanupWorker
    queue: low
    
  activity_aggregation:
    cron: '*/5 * * * *'  # Every 5 minutes
    class: ActivityAggregationWorker
    queue: default

production:
  :concurrency: 10

development:
  :concurrency: 2
```

---

## 🔨 Implementation

### Phase 1: Create Worker Classes (2 hours)

#### Worker 1: Cache Refresh
**File:** `app/workers/cache_refresh_worker.rb`
```ruby
class CacheRefreshWorker
  include Sidekiq::Worker
  
  sidekiq_options queue: :default, retry: 3, backtrace: true
  
  def perform
    puts "🔄 [CACHE WORKER] Starting cache refresh at #{Time.now}"
    
    # Load local memes as fallback
    local_memes = load_local_memes
    puts "✅ [CACHE WORKER] Loaded #{local_memes.size} local memes"
    
    # Try OAuth2 first
    api_memes = fetch_with_oauth || fetch_without_auth
    puts "✅ [CACHE WORKER] Fetched #{api_memes.size} API memes"
    
    # Update cache
    validated = api_memes.select { |m| m["url"] && m["url"].to_s.strip.length > 0 }
    
    if validated.empty?
      MEME_CACHE.set(:memes, local_memes.shuffle)
      puts "⚠️ [CACHE WORKER] No API memes - using local only"
    else
      all_memes = (validated + local_memes).uniq { |m| m["url"] }
      MEME_CACHE.set(:memes, all_memes.shuffle)
      puts "✅ [CACHE WORKER] Cache updated: #{validated.size} API + #{local_memes.size} local"
    end
    
    MEME_CACHE.set(:last_refresh, Time.now)
    
  rescue => e
    puts "❌ [CACHE WORKER] Error: #{e.message}"
    Sentry.capture_exception(e) if defined?(Sentry)
    raise  # Re-raise for Sidekiq retry
  end
  
  private
  
  def load_local_memes
    yaml_data = YAML.load_file("data/memes.yml")
    if yaml_data.is_a?(Hash)
      yaml_data.values.flatten.compact
    else
      yaml_data || []
    end
  rescue => e
    puts "❌ Failed to load local memes: #{e.message}"
    []
  end
  
  def fetch_with_oauth
    client_id = ENV['REDDIT_CLIENT_ID'].to_s.strip
    client_secret = ENV['REDDIT_CLIENT_SECRET'].to_s.strip
    
    return nil if client_id.empty? || client_secret.empty?
    
    client = OAuth2::Client.new(
      client_id,
      client_secret,
      site: "https://www.reddit.com",
      authorize_url: "/api/v1/authorize",
      token_url: "/api/v1/access_token"
    )
    
    token = client.client_credentials.get_token(scope: "read")
    subreddits = YAML.load_file("data/subreddits.yml")["popular"].sample(8)
    
    MemeExplorer.fetch_reddit_memes_authenticated(token.token, subreddits, 30)
  rescue => e
    puts "⚠️ OAuth failed: #{e.message}"
    nil
  end
  
  def fetch_without_auth
    subreddits = YAML.load_file("data/subreddits.yml")["popular"].sample(8)
    MemeExplorer.fetch_reddit_memes_static(subreddits, 30)
  rescue => e
    puts "⚠️ Unauthenticated fetch failed: #{e.message}"
    []
  end
end
```

#### Worker 2: Leaderboard Calculation
**File:** `app/workers/leaderboard_calculation_worker.rb`
```ruby
class LeaderboardCalculationWorker
  include Sidekiq::Worker
  
  sidekiq_options queue: :critical, retry: 5, backtrace: true
  
  def perform
    puts "🏆 [LEADERBOARD WORKER] Calculating leaderboard scores at #{Time.now}"
    
    # Get current week period
    current_week = Time.now.strftime('%Y%U')
    
    # Calculate scores for all users
    users_with_activity = DB.execute("
      SELECT DISTINCT user_id 
      FROM user_meme_stats 
      WHERE liked = 1 
         OR saved = 1 
      UNION
      SELECT DISTINCT user_id 
      FROM saved_memes
    ")
    
    users_with_activity.each do |row|
      user_id = row['user_id']
      calculate_user_score(user_id, current_week)
    end
    
    puts "✅ [LEADERBOARD WORKER] Updated #{users_with_activity.size} users"
    
  rescue => e
    puts "❌ [LEADERBOARD WORKER] Error: #{e.message}"
    Sentry.capture_exception(e) if defined?(Sentry)
    raise
  end
  
  private
  
  def calculate_user_score(user_id, period)
    # Calculate engagement score
    likes = DB.get_first_value(
      "SELECT COUNT(*) FROM user_meme_stats WHERE user_id = ? AND liked = 1",
      [user_id]
    ).to_i
    
    saved = DB.get_first_value(
      "SELECT COUNT(*) FROM saved_memes WHERE user_id = ?",
      [user_id]
    ).to_i
    
    battles_won = DB.get_first_value(
      "SELECT COUNT(*) FROM meme_battles WHERE winner_id = ?",
      [user_id]
    ).to_i || 0
    
    # Calculate score (likes * 10 + saved * 20 + battles_won * 50)
    score = (likes * 10) + (saved * 20) + (battles_won * 50)
    
    # Update or insert
    DB.execute(
      "INSERT INTO leaderboard_entries (user_id, period, period_type, score, likes_count, saved_count, battles_won) 
       VALUES (?, ?, 'weekly', ?, ?, ?, ?)
       ON CONFLICT(user_id, period, period_type) 
       DO UPDATE SET 
         score = excluded.score,
         likes_count = excluded.likes_count,
         saved_count = excluded.saved_count,
         battles_won = excluded.battles_won,
         updated_at = CURRENT_TIMESTAMP",
      [user_id, period, score, likes, saved, battles_won]
    )
  rescue => e
    puts "⚠️ Error calculating score for user #{user_id}: #{e.message}"
  end
end
```

#### Worker 3: Database Cleanup
**File:** `app/workers/database_cleanup_worker.rb`
```ruby
class DatabaseCleanupWorker
  include Sidekiq::Worker
  
  sidekiq_options queue: :low, retry: 3
  
  def perform
    puts "🧹 [CLEANUP WORKER] Starting database cleanup at #{Time.now}"
    
    cleanup_stats = {
      broken_images: 0,
      old_meme_stats: 0,
      expired_sessions: 0
    }
    
    # Remove old broken images (failure_count >= 5 and > 1 day old)
    cleanup_stats[:broken_images] = DB.execute(
      "DELETE FROM broken_images 
       WHERE failure_count >= 5 
       AND datetime(first_failed_at) < datetime('now', '-1 day')"
    ).changes
    
    # Remove old meme stats (no engagement and > 7 days old)
    cleanup_stats[:old_meme_stats] = DB.execute(
      "DELETE FROM meme_stats 
       WHERE likes = 0 
       AND views = 0 
       AND datetime(updated_at) < datetime('now', '-7 days')"
    ).changes
    
    # Clean up old experiment assignments (> 30 days)
    cleanup_stats[:expired_sessions] = DB.execute(
      "DELETE FROM experiment_assignments 
       WHERE datetime(assigned_at) < datetime('now', '-30 days')"
    ).changes
    
    puts "✅ [CLEANUP WORKER] Removed #{cleanup_stats[:broken_images]} broken images, #{cleanup_stats[:old_meme_stats]} old stats, #{cleanup_stats[:expired_sessions]} expired experiments"
    
  rescue => e
    puts "❌ [CLEANUP WORKER] Error: #{e.message}"
    Sentry.capture_exception(e) if defined?(Sentry)
    # Don't raise - cleanup is not critical
  end
end
```

#### Worker 4: Activity Aggregation
**File:** `app/workers/activity_aggregation_worker.rb`
```ruby
class ActivityAggregationWorker
  include Sidekiq::Worker
  
  sidekiq_options queue: :default, retry: 3
  
  def perform
    puts "📊 [ACTIVITY WORKER] Aggregating activity stats at #{Time.now}"
    
    return unless defined?(REDIS) && REDIS
    
    # Get all active user keys
    active_keys = REDIS.keys("active:*")
    
    # Count unique users in last 5 minutes
    active_count = active_keys.count do |key|
      ttl = REDIS.ttl(key)
      ttl > 0  # Still active
    end
    
    # Store hourly aggregates
    hour_key = "activity:hourly:#{Time.now.strftime('%Y%m%d%H')}"
    REDIS.hincrby(hour_key, "active_users", active_count)
    REDIS.hincrby(hour_key, "samples", 1)
    REDIS.expire(hour_key, 86400)  # Keep for 24 hours
    
    # Calculate and store average
    samples = REDIS.hget(hour_key, "samples").to_i
    total = REDIS.hget(hour_key, "active_users").to_i
    avg = samples > 0 ? (total.to_f / samples).round(1) : 0
    REDIS.hset(hour_key, "average", avg)
    
    puts "✅ [ACTIVITY WORKER] Logged #{active_count} active users (avg: #{avg})"
    
  rescue => e
    puts "❌ [ACTIVITY WORKER] Error: #{e.message}"
    # Don't raise - not critical
  end
end
```

---

### Phase 2: Remove Old Threads from app.rb (1 hour)

**File:** `app.rb`

Remove these thread blocks:

```ruby
# DELETE THIS:
@cache_refresh_thread = Thread.new do
  # ... entire cache refresh thread code
end

# DELETE THIS:
@db_cleanup_thread = Thread.new do
  # ... entire cleanup thread code
end
```

Add at bottom of file (before `run!`):

```ruby
# Start Sidekiq scheduler (only if not already running)
if ENV['RACK_ENV'] == 'production'
  require 'sidekiq/web'
  require 'sidekiq-scheduler'
  
  # Mount Sidekiq web UI (admin only)
  use Rack::Auth::Basic, "Protected Area" do |username, password|
    # In production, use ENV vars or check admin role
    username == ENV['SIDEKIQ_USERNAME'] && password == ENV['SIDEKIQ_PASSWORD']
  end
  
  mount Sidekiq::Web, at: '/sidekiq'
end
```

---

### Phase 3: Update Initialization (30 minutes)

**File:** `config/initializers/sidekiq.rb` (NEW)
```ruby
require 'sidekiq'
require 'sidekiq-scheduler'

Sidekiq.configure_server do |config|
  config.redis = { url: ENV['REDIS_URL'] || 'redis://localhost:6379/0' }
  
  # Load schedule from config file
  config.on(:startup) do
    Sidekiq.schedule = YAML.load_file(File.expand_path('../../sidekiq.yml', __FILE__))[:schedule]
    SidekiqScheduler::Scheduler.instance.reload_schedule!
  end
end

Sidekiq.configure_client do |config|
  config.redis = { url: ENV['REDIS_URL'] || 'redis://localhost:6379/0' }
end
```

---

### Phase 4: Create Procfile for Deployment (15 minutes)

**File:** `Procfile`
```
web: bundle exec puma -C config/puma.rb
worker: bundle exec sidekiq -C config/sidekiq.yml
```

**File:** `Procfile.dev` (for local development)
```
web: bundle exec puma -C config/puma.rb
worker: bundle exec sidekiq -C config/sidekiq.yml -e development
```

---

### Phase 5: Testing (1-2 hours)

#### Test Workers Manually
```bash
# Start Sidekiq
bundle exec sidekiq -C config/sidekiq.yml

# In Rails/IRB console, trigger manually:
CacheRefreshWorker.perform_async
LeaderboardCalculationWorker.perform_async
DatabaseCleanupWorker.perform_async
ActivityAggregationWorker.perform_async
```

#### Monitor Jobs
1. Visit `http://localhost:8080/sidekiq` (with auth)
2. Check:
   - Jobs processed/failed
   - Queue depths
   - Retry counts
   - Scheduled jobs

---

## 🚀 Deployment

### Render.com Configuration

**Update** `render.yaml`:
```yaml
services:
  - type: web
    name: meme-explorer-web
    env: ruby
    buildCommand: bundle install
    startCommand: bundle exec puma -C config/puma.rb
    envVars:
      - key: REDIS_URL
        fromService:
          type: redis
          name: meme-explorer-redis
          property: connectionString
      - key: DATABASE_URL
        fromDatabase:
          name: meme-explorer-db
          property: connectionString
      - key: SIDEKIQ_USERNAME
        generateValue: true
      - key: SIDEKIQ_PASSWORD
        generateValue: true
  
  # NEW: Sidekiq worker service
  - type: worker
    name: meme-explorer-worker
    env: ruby
    buildCommand: bundle install
    startCommand: bundle exec sidekiq -C config/sidekiq.yml
    envVars:
      - key: REDIS_URL
        fromService:
          type: redis
          name: meme-explorer-redis
          property: connectionString
      - key: DATABASE_URL
        fromDatabase:
          name: meme-explorer-db
          property: connectionString
```

### Heroku Configuration
```bash
# Add Sidekiq dyno
heroku ps:scale worker=1

# Or in Procfile, Heroku auto-detects
```

---

## 📊 Monitoring & Observability

### Sidekiq Web UI
- **URL:** `/sidekiq` (admin auth required)
- **Metrics:**
  - Processed jobs
  - Failed jobs
  - Queue latency
  - Worker memory usage

### Custom Monitoring
```ruby
# Add to health endpoint
get '/health' do
  sidekiq_stats = Sidekiq::Stats.new
  
  {
    status: "ok",
    sidekiq: {
      processed: sidekiq_stats.processed,
      failed: sidekiq_stats.failed,
      enqueued: sidekiq_stats.enqueued,
      scheduled: sidekiq_stats.scheduled_size,
      retry: sidekiq_stats.retry_size,
      workers: sidekiq_stats.workers_size
    }
  }.to_json
end
```

---

## ⚠️ Gotchas & Solutions

### Issue 1: Jobs Not Running
**Cause:** Sidekiq process not started
**Solution:** Check `ps aux | grep sidekiq` or Render dashboard

### Issue 2: Redis Connection Errors
**Cause:** Wrong REDIS_URL
**Solution:** Verify `echo $REDIS_URL` matches Redis instance

### Issue 3: Jobs Failing Silently
**Cause:** Errors not being raised
**Solution:** Always `raise` after logging in workers (for retry)

### Issue 4: Memory Leaks
**Cause:** Workers loading too much data
**Solution:** Batch processing, clear instance variables

---

## 🎯 Success Criteria

Week 3 is complete when:
1. ✅ All 4 workers created and tested
2. ✅ Threads removed from app.rb
3. ✅ Sidekiq web UI accessible
4. ✅ Jobs running on schedule in production
5. ✅ Monitoring shows successful job execution
6. ✅ Error rate < 1% in Sidekiq dashboard
7. ✅ Cache refreshing every 10 minutes
8. ✅ Leaderboard updating hourly

---

## 💡 Future Enhancements

Once Sidekiq is stable:
1. Add email notifications (Sidekiq Mailers)
2. Add webhook workers for external integrations
3. Add image processing workers (thumbnails, compression)
4. Add analytics aggregation workers

---

**Estimated Time:** 4-6 hours (including testing)  
**Difficulty:** Medium (straightforward if following guide)  
**Impact:** High (better reliability, scalability, observability)

Ready to execute! 🚀
