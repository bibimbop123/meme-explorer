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

-- Should be < 25 (pool size)
```

**Solutions:**
```ruby
# Check connection pool configuration
DB_POOL.size  # Should return 25

# Force connection release
DB_POOL.shutdown { |conn| conn.close }
DB_POOL = create_new_pool()
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
# Reset database (development only!)
rm memes.db
bundle exec ruby scripts/setup_database.rb

# For PostgreSQL, run migrations
bundle exec ruby scripts/run_migrations.rb

# Check database exists
psql -l | grep meme_explorer
```

### Tests Failing
**Error:** RSpec failures, flaky tests

**Solutions:**
```bash
# Run with seed for reproducibility
bundle exec rspec --seed 12345

# Clear test database
RACK_ENV=test bundle exec ruby scripts/setup_database.rb

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
# Check slow queries
tail -f log/production.log | grep "Slow query"

# Profile a request
PerformanceProfiler.profile { visit '/random' }
```

**Solutions:**
1. Check database indexes exist
2. Review N+1 queries
3. Increase cache TTL
4. Enable CDN for static assets

### Sidekiq Jobs Piling Up
**Symptoms:** Queue depth increasing, jobs not processing

**Diagnosis:**
```bash
# Check Sidekiq stats
bundle exec sidekiq-cli stats

# Check queue depth
redis-cli LLEN "queue:default"
```

**Solutions:**
```bash
# Increase concurrency
# Edit config/sidekiq.yml: concurrency: 10

# Clear failed jobs
bundle exec sidekiq-cli clear-failed

# Restart Sidekiq
sudo systemctl restart sidekiq
```

---

## 🔐 AUTHENTICATION ISSUES

### Session Expires Too Quickly
**Symptoms:** Users logged out unexpectedly

**Check:**
```ruby
# config/application.rb
MemeExplorerConfig::SESSION_EXPIRE_AFTER  # Should be 2 weeks
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
# Locally simulate production build
RACK_ENV=production bundle install
RACK_ENV=production bundle exec ruby app.rb

# Check Render logs
render logs --tail <service-id>
```

### Rollback Procedure
```bash
# Via Render dashboard
1. Go to service → Deployments
2. Click "Rollback" on last known good deployment

# Via Render CLI
render rollback <service-id>
```

### Environment Variables Missing
**Error:** "Environment variable not set"

**Check:**
```bash
# List all env vars
render env <service-id>

# Set missing var
render env:set SESSION_SECRET=<value> <service-id>
```

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
