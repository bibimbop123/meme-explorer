# 🔧 TROUBLESHOOTING GUIDE

Common issues and solutions for Meme Explorer.

---

## 🚨 PRODUCTION ISSUES

### Memory Leak / High Memory Usage
**Symptoms:** Memory gradually increases, eventual OOM crash

**Diagnosis:**
```bash
# Check memory usage
ps aux | grep ruby

# Check Sidekiq memory
ps aux | grep sidekiq
```

**Solutions:**
✅ **FIXED in Phase 1:** Removed @db_cleanup_thread memory leak
- Ensure using latest code with Sidekiq workers
- Restart Puma/Sidekiq if memory exceeds 1GB
- Check for orphaned threads: `Thread.list.size`

### Database Connection Exhaustion
**Symptoms:** "Too many connections" errors

**Diagnosis:**
```sql
-- PostgreSQL
SELECT count(*) FROM pg_stat_activity;

-- Should be < 35 (see db/setup.rb - pool size is currently 35,
-- sized for 32 Puma threads; check db/setup.rb directly, this
-- number changes)
```

**Solutions:**
```ruby
# Check connection pool configuration
DB_POOL.size  # Reports the actual configured size (see db/setup.rb)

# Force connection release
DB_POOL.shutdown { |conn| conn.close }
# Then restart the process - DB_POOL is a top-level constant set once
# at boot in db/setup.rb, it isn't meant to be reassigned at runtime.
```

### Redis Connection Failures
**Symptoms:** "Redis::CannotConnectError"

**Diagnosis:**
```bash
# Test Redis connection
redis-cli ping  # Should return PONG

# Check Redis memory
redis-cli info memory
```

**Solutions:**
```bash
# Restart Redis
sudo systemctl restart redis

# Clear Redis (CAUTION: loses all cache)
redis-cli FLUSHALL

# Check configuration
cat config/initializers/sidekiq.rb
```

---

## 🐛 DEVELOPMENT ISSUES

### Bundle Install Fails
**Error:** `Gem::Ext::BuildError` or version conflicts

**Solutions:**
```bash
# Clean bundler cache
bundle clean --force

# Remove Gemfile.lock and reinstall
rm Gemfile.lock
bundle install

# Check Ruby version
ruby -v  # Should be 3.2.1

# Use specific bundler version
gem install bundler:2.4.10
bundle _2.4.10_ install
```

### Database Migration Errors
**Error:** `SQLite3::SQLException` or `PG::Error`

**Solutions:**
```bash
# Re-run setup (creates tables if missing - see db/setup.rb)
ruby db/setup.rb

# Individual migrations live in db/migrations/ and db/migrate_*.rb -
# check that directory for the actual current migration files rather
# than a fixed script name here, as it changes over time

# Check database exists
psql -l | grep meme_explorer
```

### Tests Failing
**Error:** RSpec failures, flaky tests

**Solutions:**
```bash
# Run with seed for reproducibility
bundle exec rspec --seed 12345

# Re-run setup against the test DB if tables are missing/stale
RACK_ENV=test ruby db/setup.rb

# Run specific failing test
bundle exec rspec spec/path/to/spec.rb:42

# Check test dependencies
bundle exec rspec --format documentation
```

---

## 🌐 API ISSUES

### Reddit API Rate Limiting
**Symptoms:** 429 errors, empty meme pools

**Diagnosis:**
```ruby
# Check rate limit status
puts REDIS.get("reddit:rate_limit:#{Date.today}")
```

**Solutions:**
- Wait 60 seconds between requests
- Use OAuth authentication (higher limits)
- Implement exponential backoff
- Cache aggressively (30+ min TTL)

### OAuth Token Expired
**Error:** "Invalid OAuth token"

**Solutions:**
```bash
# Check environment variables
echo $REDDIT_CLIENT_ID
echo $REDDIT_CLIENT_SECRET

# Regenerate token
curl -X POST https://www.reddit.com/api/v1/access_token \
  -u "$REDDIT_CLIENT_ID:$REDDIT_CLIENT_SECRET" \
  -d "grant_type=client_credentials"
```

---

## ⚡ PERFORMANCE ISSUES

### Slow Page Load
**Symptoms:** Pages taking > 2 seconds to load

**Diagnosis:**
```ruby
# If it's specifically /random or /random.json feeling slow, check the
# real, live latency breakdown first - don't guess:
#   Visit /metrics (admin-only) and look at "Selection Latency Breakdown"
#   :pool_lookup vs :selection tells you whether the cost is finding a
#   meme pool or choosing from it; :pool_manager_lookup vs :reddit_fetch
#   narrows pool_lookup further into "Redis was slow" vs "the on-demand
#   Reddit fetch was slow" - see lib/services/selection_benchmark.rb.

# For other routes, check slow queries
tail -f log/production.log | grep "Slow query"

# Or use PerformanceProfiler for ad-hoc profiling (lib/concerns/performance_profiler.rb)
PerformanceProfiler.profile { visit '/random' }
```

**Solutions:**
1. If `/metrics` shows `:reddit_fetch` or `:pool_manager_lookup` p95/p99
   is high, that's real network I/O - check Reddit API rate limits and
   Redis connectivity/latency, not the Ruby code
2. Check database indexes exist
3. Review N+1 queries
4. Increase cache TTL
5. Enable CDN for static assets

### Sidekiq Jobs Piling Up
**Symptoms:** Queue depth increasing, jobs not processing

**Diagnosis:**
```bash
# `sidekiq-cli` is not a real command - check the Sidekiq Web UI (if
# mounted) or query Redis directly:

# Check queue depth
redis-cli LLEN "queue:default"

# Or use the Sidekiq API from a Ruby console:
# Sidekiq::Queue.new.size
```

**Solutions:**
```bash
# Increase concurrency
# Edit config/sidekiq.yml: concurrency: 10

# Clear failed jobs - via the Sidekiq API (no "sidekiq-cli" command exists):
#   Sidekiq::RetrySet.new.clear
#   Sidekiq::DeadSet.new.clear

# Restart Sidekiq (adjust to however it's actually run in your environment -
# this repo's Procfile runs it via `bundle exec sidekiq -r ./app.rb -C config/sidekiq.yml`,
# not systemd)
```

---

## 🔐 AUTHENTICATION ISSUES

### Session Expires Too Quickly
**Symptoms:** Users logged out unexpectedly

**Check:**
```ruby
# config/app_constants.rb
AppConstants::SESSION_EXPIRE_AFTER
```

**Solutions:**
```ruby
# Increase session expiration
set :session_expire_after, 60 * 60 * 24 * 14  # 2 weeks
```

### CSRF Token Mismatch
**Error:** "Invalid CSRF token"

**Solutions:**
```ruby
# Ensure CSRF middleware is loaded
use Rack::CSRF, raise: true

# Check token in forms
<input type="hidden" name="_csrf" value="<%= csrf_token %>">

# Skip CSRF for specific routes
use Rack::CSRF, skip: ['POST:/api/webhook']
```

---

## 📊 MONITORING & DEBUGGING

### Enable Debug Logging
```ruby
# config/application.rb
configure :development do
  set :logging, Logger::DEBUG
end
```

### Check Health Status
```bash
# Quick health check
curl https://your-app.com/health

# Detailed health check (admin only)
curl -H "Authorization: Bearer $ADMIN_TOKEN" \
  https://your-app.com/health/detailed
```

### View Sentry Errors
1. Go to https://sentry.io
2. Select meme-explorer project
3. Filter by environment: production
4. Check error frequency and stack traces

---

## 🔄 DEPLOYMENT ISSUES

### Deploy Fails
**Error:** Build fails on Render

**Check:**
```bash
# Locally simulate production build - render.yaml's buildCommand is
# just `bundle install` (no test/build step), so this is genuinely
# the whole build:
RACK_ENV=production bundle install
RACK_ENV=production bundle exec rackup config.ru -p 8080

# Check Render logs via the Render dashboard, or the Render CLI if
# installed - verify exact current flags against `render --help`
# rather than trusting a fixed command here; CLI syntax changes.
```

### Rollback Procedure

Via the Render dashboard: go to the service → Deployments → click
"Rollback" on the last known good deployment. Verify current Render CLI
rollback support and syntax directly (`render --help`) before relying on
a specific command here.

### Environment Variables Missing
**Error:** "Environment variable not set"

**Check:** Render dashboard → service → Environment tab. Verify current
Render CLI env-var commands directly (`render --help`) rather than
trusting a fixed command here.

---

## 📞 GETTING HELP

### Before Opening an Issue
1. Check this troubleshooting guide
2. Search existing GitHub issues
3. Review ARCHITECTURE.md
4. Check Sentry for error details

### When Opening an Issue
Include:
- Ruby version (`ruby -v`)
- Environment (development/production)
- Error message (full stack trace)
- Steps to reproduce
- Expected vs actual behavior

### Emergency Contacts
- **Critical Production Issues:** Create GitHub issue with `[URGENT]` prefix
- **Security Issues:** Email security@example.com (do not create public issue)

---

**Last Updated:** June 3, 2026  
**Maintained by:** Development Team
