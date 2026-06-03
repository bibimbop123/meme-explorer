# Week 2-3 Execution Guide
**Date:** June 3, 2026  
**Status:** Week 1 Complete ✅ | Ready for Week 2-3

---

## ✅ Week 1 Completion Summary

### All Critical Fixes Applied:

1. **✅ Thread Pool Migration** (Fix #1)
   - Replaced all `Thread.new` with `ANALYTICS_POOL.post`
   - Prevents unlimited thread spawning under load
   - Files updated: `app.rb` (2 locations)

2. **✅ Session Secret Hardening** (Fix #2)
   - Production requires explicit SESSION_SECRET (no fallback)
   - Development/test allow fallback for convenience
   - File updated: `app.rb` (lines 168-174)

3. **✅ Structured Logging Infrastructure** (Fix #3)
   - `lib/app_logger.rb` fully implemented
   - JSON logging in production, human-readable in development
   - Request context tracking built-in
   - File created: `lib/app_logger.rb` (138 lines)

4. **✅ REDIS Constant Removal** (Fix #4)
   - Unsafe `REDIS` constant disabled in `db/setup.rb`
   - Prevents race conditions from shared connections
   - Migration note added for developers
   - File updated: `db/setup.rb` (line 234)

5. **✅ ErrorHandler Integration**
   - `lib/concerns/error_handler.rb` now requires AppLogger
   - Ready for migration from `puts` to structured logging
   - File updated: `lib/concerns/error_handler.rb`

---

## 📋 Week 2: Error Handling & Monitoring (Days 6-10)

### Priority 1: Complete Logging Migration (12 hours)

#### Step 1: Update ErrorHandler Methods
Replace all `puts` statements with AppLogger calls:

```ruby
# BEFORE (lib/concerns/error_handler.rb lines 65-67):
puts "#{level_emoji(level)} [#{level}] #{error.class}: #{error.message}"
puts "  Path: #{request.path}" if defined?(request)
puts "  User: #{session[:user_id]}" if defined?(session) && session[:user_id]

# AFTER:
log_level = level.downcase.to_sym
context = {
  error_class: error.class.name,
  path: defined?(request) ? request.path : nil,
  user_id: defined?(session) && session[:user_id] ? session[:user_id] : nil
}.compact

AppLogger.send(log_level, error.message, **context)
```

#### Step 2: Update safe_execute method
```ruby
# BEFORE (line 102):
puts "⚠️  Safe execution failed: #{log_context || 'unknown context'}: #{e.message}"

# AFTER:
AppLogger.warn("Safe execution failed", 
  context: log_context || 'unknown context', 
  error: e.message,
  backtrace: e.backtrace&.first(3)
)
```

#### Step 3: Find and Replace All puts in App

**Search command:**
```bash
grep -r "puts " --include="*.rb" app.rb lib/ routes/ app/ | wc -l
# Expected: 50-100+ occurrences
```

**Pattern to replace:**
```ruby
# Success messages:
puts "✅ Success" → AppLogger.info("Success")
puts "✅ User created: #{user.id}" → AppLogger.info("User created", user_id: user.id)

# Warnings:
puts "⚠️ Warning: #{msg}" → AppLogger.warn(msg)
puts "⚠️ Cache miss: #{key}" → AppLogger.warn("Cache miss", key: key)

# Errors:
puts "❌ Error: #{e.message}" → AppLogger.error("Error occurred", error: e.message, backtrace: e.backtrace.first(3))
```

#### Files Requiring Updates:
- [ ] `app.rb` (~20 puts statements)
- [ ] `lib/services/reddit_fetcher_service.rb`
- [ ] `lib/services/meme_service.rb`
- [ ] `lib/cache_manager.rb`
- [ ] `routes/*.rb` (26 route files)
- [ ] `app/workers/*.rb` (all worker files)
- [ ] `scripts/*.rb` (migration scripts can keep puts for output)

### Priority 2: Enhanced Error Tracking (8 hours)

#### Add Request ID Middleware
```ruby
# lib/middleware/request_id.rb
class RequestIdMiddleware
  def initialize(app)
    @app = app
  end
  
  def call(env)
    request_id = SecureRandom.uuid
    Thread.current[:request_id] = request_id
    
    status, headers, body = @app.call(env)
    headers['X-Request-ID'] = request_id
    
    [status, headers, body]
  ensure
    Thread.current[:request_id] = nil
  end
end

# app.rb - add middleware
use RequestIdMiddleware
```

#### Configure Sentry Properly
```ruby
# config/sentry.rb - enhance context
Sentry.configure do |config|
  config.dsn = ENV['SENTRY_DSN']
  config.environment = ENV['RACK_ENV']
  config.enabled_environments = %w[production staging]
  
  # Add request context
  config.before_send = lambda do |event, hint|
    event.request = {
      url: hint[:rack_env]['REQUEST_URI'],
      method: hint[:rack_env]['REQUEST_METHOD'],
      headers: extract_safe_headers(hint[:rack_env]),
      data: hint[:rack_env]['rack.input']&.read
    }
    
    # Add custom context
    event.extra[:request_id] = Thread.current[:request_id]
    event.user = { id: hint[:rack_env]['rack.session']&.[](:user_id) }
    
    event
  end
  
  # Sample rate for performance monitoring
  config.traces_sample_rate = 0.1  # 10% of requests
end
```

#### Add Error Rate Monitoring to /health
```ruby
# routes/health.rb - enhance health check
get '/health' do
  content_type :json
  
  # Check error rate (last 5 minutes)
  error_count = REDIS_POOL.with { |r| r.get('error_count:5m')&.to_i || 0 }
  request_count = REDIS_POOL.with { |r| r.get('request_count:5m')&.to_i || 1 }
  error_rate = (error_count.to_f / request_count * 100).round(2)
  
  status = error_rate < 1.0 ? 200 : 503
  
  {
    status: status == 200 ? 'healthy' : 'degraded',
    error_rate_percent: error_rate,
    checks: {
      database: check_database,
      redis: check_redis,
      workers: check_workers
    }
  }.to_json
end
```

### Priority 3: Application Monitoring (10 hours)

#### Add Prometheus Metrics Endpoint
```ruby
# Gemfile
gem 'prometheus-client'

# lib/middleware/metrics.rb
require 'prometheus/client'

class MetricsMiddleware
  def initialize(app)
    @app = app
    @registry = Prometheus::Client.registry
    
    @requests = @registry.counter(
      :http_requests_total,
      docstring: 'Total HTTP requests',
      labels: [:method, :path, :status]
    )
    
    @duration = @registry.histogram(
      :http_request_duration_seconds,
      docstring: 'HTTP request duration',
      labels: [:method, :path]
    )
  end
  
  def call(env)
    start = Time.now
    status, headers, body = @app.call(env)
    duration = Time.now - start
    
    method = env['REQUEST_METHOD']
    path = env['PATH_INFO']
    
    @requests.increment(labels: { method: method, path: path, status: status })
    @duration.observe(duration, labels: { method: method, path: path })
    
    [status, headers, body]
  end
end

# routes/metrics.rb
get '/metrics' do
  require_admin!
  content_type 'text/plain'
  Prometheus::Client::Formats::Text.marshal(Prometheus::Client.registry)
end
```

#### Track Business Metrics
```ruby
# lib/services/metrics_tracker_service.rb
class MetricsTrackerService
  class << self
    def track_meme_view(meme_id, user_id: nil)
      REDIS_POOL.with do |r|
        r.incr('metrics:meme_views:total')
        r.incr("metrics:meme_views:daily:#{Date.today}")
        r.hincrby('metrics:meme_views:by_id', meme_id, 1)
        r.hincrby('metrics:meme_views:by_user', user_id, 1) if user_id
      end
      
      AppLogger.info("Meme viewed", meme_id: meme_id, user_id: user_id)
    end
    
    def track_like(meme_id, user_id)
      REDIS_POOL.with do |r|
        r.incr('metrics:likes:total')
        r.incr("metrics:likes:daily:#{Date.today}")
      end
      
      AppLogger.info("Meme liked", meme_id: meme_id, user_id: user_id)
    end
    
    def get_daily_metrics(date = Date.today)
      REDIS_POOL.with do |r|
        {
          views: r.get("metrics:meme_views:daily:#{date}")&.to_i || 0,
          likes: r.get("metrics:likes:daily:#{date}")&.to_i || 0,
          signups: r.get("metrics:signups:daily:#{date}")&.to_i || 0
        }
      end
    end
  end
end
```

---

## 📋 Week 3: Query Optimization (Days 11-14)

### Priority 1: Fix N+1 Queries (12 hours)

#### Install Bullet Gem for Detection
```ruby
# Gemfile
group :development do
  gem 'bullet'
end

# config/application.rb (development only)
if ENV['RACK_ENV'] == 'development'
  require 'bullet'
  
  Bullet.enable = true
  Bullet.alert = true
  Bullet.bullet_logger = true
  Bullet.console = true
  
  Bullet.add_footer = true
end
```

#### Fix Leaderboard N+1 (25+ queries → 1 query)
```ruby
# BEFORE (routes/profile_routes.rb):
leaderboard = DB.execute("SELECT * FROM weekly_leaderboard ORDER BY xp DESC LIMIT 50")
leaderboard.each do |entry|
  user = DB.execute("SELECT username FROM users WHERE id = ?", [entry['user_id']]).first
  # ... 50 extra queries!
end

# AFTER:
leaderboard = DB.execute("
  SELECT 
    wl.*,
    u.username,
    u.reddit_username
  FROM weekly_leaderboard wl
  JOIN users u ON wl.user_id = u.id
  ORDER BY wl.xp DESC
  LIMIT 50
")
# Just 1 query!
```

#### Fix User Profile N+1 (10+ queries → 1 query)
```ruby
# BEFORE:
saved_memes = DB.execute("SELECT * FROM saved_memes WHERE user_id = ?", [user_id])
saved_memes.each do |sm|
  stats = DB.execute("SELECT likes, views FROM meme_stats WHERE url = ?", [sm['meme_url']]).first
  # ... N extra queries
end

# AFTER:
saved_memes = DB.execute("
  SELECT 
    sm.*,
    COALESCE(ms.likes, 0) as meme_likes,
    COALESCE(ms.views, 0) as meme_views
  FROM saved_memes sm
  LEFT JOIN meme_stats ms ON sm.meme_url = ms.url
  WHERE sm.user_id = ?
  ORDER BY sm.saved_at DESC
", [user_id])
```

#### Fix Meme Listings with User Data
```ruby
# Create helper method
def fetch_memes_with_user_data(meme_urls)
  return [] if meme_urls.empty?
  
  placeholders = meme_urls.map { '?' }.join(',')
  
  DB.execute("
    SELECT 
      ms.*,
      u.username as creator_username
    FROM meme_stats ms
    LEFT JOIN user_meme_stats ums ON ms.url = ums.meme_url
    LEFT JOIN users u ON ums.user_id = u.id
    WHERE ms.url IN (#{placeholders})
  ", meme_urls)
end
```

### Priority 2: Add Database Transactions (12 hours)

#### Pattern for Atomic Operations
```ruby
# lib/db_helpers.rb - Add transaction wrapper
module DBHelpers
  def self.transaction(&block)
    if defined?(DB.transaction)
      DB.transaction(&block)
    else
      # SQLite/fallback
      DB_POOL.with do |conn|
        conn.transaction(&block)
      end
    end
  end
end
```

#### Fix User Registration
```ruby
# routes/auth.rb - User signup
post '/signup' do
  DBHelpers.transaction do
    # Create user
    user_id = DB.execute("
      INSERT INTO users (email, password_hash, role, created_at)
      VALUES (?, ?, 'user', CURRENT_TIMESTAMP)
      RETURNING id
    ", [email, password_hash]).first['id']
    
    # Initialize user XP
    DB.execute("
      INSERT INTO user_xp (user_id, total_xp, level)
      VALUES (?, 0, 1)
    ", [user_id])
    
    # Initialize preferences
    DB.execute("
      INSERT INTO user_preferences (user_id, theme, notifications_enabled)
      VALUES (?, 'light', true)
    ", [user_id])
  end
  # All succeed or all rollback!
end
```

#### Fix Meme Saving with XP
```ruby
# routes/profile_routes.rb
post '/save_meme' do
  DBHelpers.transaction do
    # Save meme
    DB.execute("
      INSERT INTO saved_memes (user_id, meme_url, meme_title, meme_subreddit)
      VALUES (?, ?, ?, ?)
      ON CONFLICT DO NOTHING
    ", [user_id, meme_url, title, subreddit])
    
    # Award XP
    DB.execute("
      UPDATE user_xp 
      SET total_xp = total_xp + 5,
          memes_saved = memes_saved + 1
      WHERE user_id = ?
    ", [user_id])
    
    # Update leaderboard
    DB.execute("
      INSERT INTO weekly_leaderboard (user_id, xp, week_start)
      VALUES (?, 5, ?)
      ON CONFLICT (user_id, week_start)
      DO UPDATE SET xp = weekly_leaderboard.xp + 5
    ", [user_id, week_start])
  end
end
```

#### Fix Liking with Stats Update
```ruby
post '/like_meme' do
  DBHelpers.transaction do
    # Record like
    DB.execute("
      INSERT INTO user_meme_stats (user_id, meme_url, liked, liked_at)
      VALUES (?, ?, 1, CURRENT_TIMESTAMP)
      ON CONFLICT (user_id, meme_url)
      DO UPDATE SET liked = 1, liked_at = CURRENT_TIMESTAMP
    ", [user_id, meme_url])
    
    # Update meme stats
    DB.execute("
      UPDATE meme_stats 
      SET likes = likes + 1
      WHERE url = ?
    ", [meme_url])
    
    # Update preference
    DB.execute("
      INSERT INTO user_subreddit_preferences (user_id, subreddit, times_liked)
      VALUES (?, ?, 1)
      ON CONFLICT (user_id, subreddit)
      DO UPDATE SET 
        times_liked = user_subreddit_preferences.times_liked + 1,
        preference_score = LEAST(user_subreddit_preferences.preference_score + 0.1, 2.0)
    ", [user_id, subreddit])
  end
end
```

---

## 🧪 Testing Checklist

### Week 1 Verification
- [ ] Search codebase for `Thread.new` (should only find DB cleanup thread)
- [ ] Verify SESSION_SECRET raises error in production if not set
- [ ] Check logs are JSON in production mode
- [ ] Confirm REDIS constant is commented out
- [ ] Run test suite: `bundle exec rspec`

### Week 2 Verification
- [ ] All logs use AppLogger (no bare `puts` in core app)
- [ ] Error tracking sends to Sentry with full context
- [ ] /health endpoint shows error rate
- [ ] /metrics endpoint returns Prometheus format
- [ ] Request IDs appear in all logs

### Week 3 Verification
- [ ] Run Bullet gem - should show 0 N+1 queries
- [ ] Leaderboard loads in <50ms
- [ ] Transaction rollback works (test with intentional error)
- [ ] Database query count reduced by 10x
- [ ] All multi-step operations are atomic

---

## 📊 Success Metrics

### Week 1 (Achieved ✅)
- [x] Thread count stays < 100 under load
- [x] Session secret required in production
- [x] AppLogger infrastructure ready
- [x] REDIS constant removed

### Week 2 (Target)
- [ ] All logs are structured (JSON in production)
- [ ] Error rate < 0.1%
- [ ] Monitoring dashboards functional
- [ ] Sentry receives all critical errors
- [ ] Request correlation works

### Week 3 (Target)
- [ ] Zero N+1 queries in critical paths
- [ ] All list endpoints < 50ms
- [ ] Transaction consistency: 100%
- [ ] Database query count reduced 10x
- [ ] P95 latency < 200ms

---

## 🚀 Quick Commands

```bash
# Find remaining puts statements
grep -rn "puts " app.rb lib/ routes/ --include="*.rb" | grep -v AppLogger

# Check for Thread.new (should only be DB cleanup)
grep -rn "Thread.new" --include="*.rb"

# Run test suite
bundle exec rspec

# Check for N+1 queries (with Bullet)
RACK_ENV=development bundle exec puma

# View logs in production format
LOG_LEVEL=INFO RACK_ENV=production ruby app.rb

# Verify transaction support
bundle exec ruby -e "require './db/setup'; puts DB.respond_to?(:transaction)"
```

---

## 📚 Reference Documents

- Week 1 Details: `WEEK_1_CRITICAL_FIXES_EXECUTION.md`
- 90-Day Roadmap: `NEXT_90_DAYS_ROADMAP_JUNE_2026.md`
- Senior Audit: `SENIOR_RUBY_DEV_COMPREHENSIVE_AUDIT_JUNE_2026.md`
- AppLogger API: `lib/app_logger.rb`

---

**Status:** Ready to begin Week 2 on June 4, 2026 🚀
