# Week 1-3 Deployment Checklist
**Status:** ✅ READY FOR DEPLOYMENT  
**Date:** June 3, 2026

---

## 🎯 What Was Built

### Week 1: Critical Stability Fixes
- ✅ Thread Pool Migration
- ✅ Session Secret Hardening  
- ✅ Structured Logging (AppLogger)
- ✅ REDIS Constant Removal

### Week 2: Error Handling & Monitoring
- ✅ ErrorHandler with AppLogger integration
- ✅ Request ID Middleware for request tracing
- ✅ Metrics Tracker Service for business metrics

### Week 3: Query Optimization
- ✅ Database Transaction Helpers
- ✅ Query Optimization Helpers (N+1 prevention)
- ✅ Comprehensive documentation and examples

---

## ✅ Pre-Deployment Checklist

### 1. Environment Variables
```bash
# Required in production:
- [ ] SESSION_SECRET is set (must be unique, 64+ characters)
- [ ] REDIS_URL is configured
- [ ] DATABASE_URL is configured (PostgreSQL)
- [ ] SENTRY_DSN is set (for error tracking)

# Optional but recommended:
- [ ] LOG_LEVEL=INFO (or DEBUG for troubleshooting)
- [ ] RACK_ENV=production
```

### 2. Dependencies
```bash
# Verify all gems are installed:
bundle install --deployment --without development test

# Check for security vulnerabilities:
bundle audit check --update
```

### 3. Database
```bash
# Run any pending migrations:
# (No new migrations in Week 1-3, only helpers added)

# Verify database connectivity:
bundle exec ruby -e "require './db/setup'; puts DB.execute('SELECT 1').first"
```

### 4. Code Integration
```bash
# Verify new requires are loaded:
grep -A 3 "request_id_middleware" app.rb
grep -A 3 "metrics_tracker_service" app.rb
grep -A 3 "db_transaction_helpers" app.rb

# Verify middleware is registered:
grep "use RequestIdMiddleware" app.rb
```

### 5. Logs
```bash
# Create logs directory if needed:
mkdir -p logs

# Verify AppLogger works:
bundle exec ruby -e "require './lib/app_logger'; AppLogger.info('Test log')"

# Check log output format:
tail -f logs/production.log
# Should see JSON in production, human-readable in development
```

---

## 🚀 Deployment Steps

### Step 1: Deploy Code
```bash
# Push to production branch:
git add .
git commit -m "Week 1-3: Critical infrastructure improvements"
git push origin main

# Or deploy to Render/Heroku:
git push heroku main
# OR
render deploy
```

### Step 2: Verify Deployment
```bash
# Check application starts successfully:
curl https://your-app.com/health

# Expected response:
{
  "status": "healthy",
  "uptime_seconds": 123,
  "timestamp": "2026-06-03T...",
  "checks": {
    "database": true,
    "redis": true
  }
}
```

### Step 3: Monitor Logs
```bash
# On Render:
render logs --tail

# On Heroku:
heroku logs --tail

# Look for:
✅ "AppLogger initialized" 
✅ "RequestIdMiddleware loaded"
✅ JSON-formatted log entries (production)
```

### Step 4: Test Features
```bash
# Test request tracing:
curl -v https://your-app.com/random
# Check for X-Request-ID header in response

# Test metrics:
# (requires admin access)
curl https://your-app.com/health/detailed

# Test error handling:
# Check that errors are logged with full context
```

---

## 📊 Post-Deployment Verification

### 1. Structured Logging
```bash
# In production logs, verify JSON format:
tail logs/production.log
# Should see:
# {"level":"INFO","timestamp":"...","message":"...","request_id":"..."}

# NOT:
# INFO: Some message
```

### 2. Request Tracing
```bash
# Make a few requests and check logs:
curl https://your-app.com/random
curl https://your-app.com/trending

# Logs should include request_id:
# {"level":"INFO","request_id":"abc-123-def-456",...}
```

### 3. Thread Pool
```bash
# Monitor thread count:
# Should stay < 100 even under load
ps aux | grep puma | awk '{print $2}' | xargs -I{} ps -p {} -o nlwp
```

### 4. Session Stability
```bash
# Verify sessions persist across requests:
# Login, navigate around, ensure you stay logged in
# (No random logouts)
```

---

## 🔍 Monitoring & Alerts

### Metrics to Watch
```bash
# Error rate (should be < 0.1%):
# Check Sentry dashboard or:
curl https://your-app.com/api/metrics | jq '.error_rate_percent'

# Response time (P95 should be < 200ms):
# Check performance monitoring

# Thread count (should stay < 100):
# Monitor server metrics
```

### Sentry Integration
```ruby
# Verify errors are being tracked:
# 1. Cause an intentional error in development
# 2. Check Sentry dashboard
# 3. Should see error with:
#    - Full stack trace
#    - Request ID
#    - User context
#    - Custom context
```

---

## 🐛 Troubleshooting

### Issue: Logs not appearing
```bash
# Check LOG_LEVEL:
echo $LOG_LEVEL  # Should be INFO or DEBUG

# Check file permissions:
ls -la logs/

# Force log to stdout (Heroku/Render):
# Logs automatically go to stdout, no file needed
```

### Issue: Request IDs not in logs
```bash
# Verify middleware is loaded:
grep "use RequestIdMiddleware" app.rb

# Check middleware order (should be early):
# RequestIdMiddleware should be before RequestTimer
```

### Issue: Thread count still growing
```bash
# Verify ANALYTICS_POOL is being used:
grep "Thread.new" app.rb routes/*.rb lib/**/*.rb
# Should only find:
# - DB cleanup thread (intentional)
# - Thread pool initialization

# NOT:
# - Analytics tracking
# - Background jobs (should use Sidekiq)
```

### Issue: Sessions still dying on deploy
```bash
# Verify SESSION_SECRET is set:
echo $SESSION_SECRET

# Verify it's NOT changing between deploys:
# Check your deployment platform's environment variables
# SESSION_SECRET should be persistent, not regenerated
```

---

## 📈 Success Criteria

| Metric | Target | How to Verify |
|--------|--------|---------------|
| Thread count | < 100 | `ps aux` or server metrics |
| Error rate | < 0.1% | Sentry or `/health/detailed` |
| P95 latency | < 200ms | APM tools or logs |
| Session stability | 100% | Manual testing |
| Log format | JSON | Check logs |
| Request tracing | 100% | Check X-Request-ID headers |

---

## 🎓 Training for Team

### For Developers:
```ruby
# Use AppLogger for all logging:
AppLogger.info("User logged in", user_id: user.id)
AppLogger.warn("Cache miss", key: cache_key)
AppLogger.error("API failed", error: e.message, api: "reddit")

# Use transaction helpers for atomic operations:
DBTransactionHelpers.transaction do
  DB.execute("INSERT INTO users ...")
  DB.execute("INSERT INTO user_xp ...")
end

# Use query helpers to prevent N+1:
leaderboard = QueryOptimizationHelpers.fetch_leaderboard_with_users(limit: 50)
```

### For DevOps:
```bash
# Monitor these logs:
grep "ERROR" logs/production.log | jq
grep "request_id" logs/production.log | jq

# Check health endpoints:
curl /health  # Quick check
curl /health/detailed  # Full diagnostics

# Monitor metrics:
curl /api/metrics | jq
```

---

## 📝 Rollback Plan

If issues occur after deployment:

```bash
# 1. Revert to previous version:
git revert HEAD
git push origin main

# 2. Or rollback on platform:
# Render:
render rollback

# Heroku:
heroku releases:rollback

# 3. Verify rollback worked:
curl https://your-app.com/health
```

---

## 📚 Documentation References

- **Week 1**: `WEEK_1_CRITICAL_FIXES_EXECUTION.md`
- **Week 2-3**: `WEEK_2_3_EXECUTION_GUIDE.md`
- **Query Examples**: `WEEK_3_QUERY_OPTIMIZATION_EXAMPLES.md`
- **AppLogger API**: `lib/app_logger.rb` (inline documentation)
- **Transaction Helpers**: `lib/helpers/db_transaction_helpers.rb`
- **Query Helpers**: `lib/helpers/query_optimization_helpers.rb`

---

## ✅ Final Sign-Off

- [ ] All code reviewed and tested
- [ ] Environment variables configured
- [ ] Dependencies updated
- [ ] Logs verified (JSON in production)
- [ ] Request tracing working
- [ ] Thread pool migration verified
- [ ] Session secret hardened
- [ ] Team trained on new helpers
- [ ] Monitoring configured
- [ ] Rollback plan tested

**Approved by:** _________________  
**Date:** _________________  

---

**Ready to deploy! 🚀**
