# 🚀 DAY 2: Staging Deployment - Step by Step Guide

**Status:** PostgreSQL local testing complete ✅  
**Goal:** Deploy and test on Render staging  
**Timeline:** 4-5 hours  
**Risk Level:** LOW (staging environment)

---

## 📋 Prerequisites - DAY 1 Checklist

Before starting DAY 2, verify:
- [x] PostgreSQL installed locally
- [x] Migration script tested locally
- [x] SQLite backup created
- [x] Render production app running (https://meme-explorer.onrender.com/)
- [x] Git repo current (latest commits pushed)

**Ready? → Continue to Step 1**

---

## Step 1: Create Render Staging Environment (30 minutes)

### 1.1 Go to Render Dashboard
```
https://dashboard.render.com/
```

### 1.2 Create Staging PostgreSQL Database
```
1. Click: "New +" → "PostgreSQL"
2. Name: meme-explorer-staging-db
3. Database: meme_explorer_staging
4. User: postgres
5. Region: Same as production
6. Plan: Standard (free tier works for testing)
7. Click: "Create Database"
8. Wait for database to be ready (2-3 minutes)
```

### 1.3 Copy Database Credentials
After database is created:
```
1. Go to: Render Dashboard → meme-explorer-staging-db
2. Copy: Internal Database URL
   Format: postgresql://user:pass@hostname:5432/dbname
3. Store safely - you'll need this for step 2
```

### 1.4 Create Staging Web Service
```
1. Click: "New +" → "Web Service"
2. Repository: bibimbop123/meme-explorer (connect GitHub)
3. Branch: main (or create 'staging' branch)
4. Name: meme-explorer-staging
5. Runtime: Ruby
6. Build Command: bundle install
7. Start Command: bundle exec puma -c config/puma.rb
8. Plan: Free or Starter
9. Click: "Create Web Service"
```

---

## Step 2: Configure Staging Environment Variables (15 minutes)

### 2.1 Add Database URL to Staging
```
1. Go to: Render Dashboard → meme-explorer-staging
2. Click: "Environment" tab
3. Click: "Add Environment Variable"
4. Name: DATABASE_URL
5. Value: <paste from Step 1.3>
6. Click: "Save"
```

### 2.2 Add Other Environment Variables
```
Same as production:
- SENTRY_DSN: <your sentry DSN>
- RACK_ENV: staging
- REDDIT_CLIENT_ID: <your reddit client ID>
- REDDIT_CLIENT_SECRET: <your reddit secret>
```

### 2.3 Verify All Variables Set
```
Render Dashboard → meme-explorer-staging → Environment

Should see:
✓ DATABASE_URL
✓ SENTRY_DSN
✓ RACK_ENV=staging
✓ REDDIT_CLIENT_ID
✓ REDDIT_CLIENT_SECRET
```

---

## Step 3: Deploy Staging Web Service (10 minutes)

### 3.1 Manual Deploy
```
Render Dashboard → meme-explorer-staging → "Deploy latest commit"
Monitor logs: Should see "Server started"
Estimated time: 2-3 minutes
```

### 3.2 Verify Deployment
```bash
# Check if staging app is running
curl https://meme-explorer-staging.onrender.com/health

# Expected output: JSON with status "ok"
```

---

## Step 4: Run PostgreSQL Migration on Staging (20 minutes)

### 4.1 Create Render One-Off Dyno
```
1. Go to: Render Dashboard → meme-explorer-staging
2. Click: "Shell" tab
3. This opens a shell in the staging environment
```

### 4.2 Run Migration
```bash
# In the Render shell, run:
cd /app
export DATABASE_URL="<your staging database URL>"
ruby db/migrate_sqlite_to_postgres.rb

# Expected output: Migration complete
```

### 4.3 Verify Migration
```bash
# In psql or Render shell:
psql $DATABASE_URL -c "SELECT COUNT(*) FROM meme_stats;"

# Expected: Should show record count
```

---

## Step 5: Test Staging Thoroughly (60-90 minutes)

### 5.1 Test Phase 3 Algorithm
```bash
curl https://meme-explorer-staging.onrender.com/random \
  -H "Accept: text/html"

# Should return: HTML page with meme data
# Check console: No JavaScript errors
# Check logs: No database errors
```

### 5.2 Test User Accounts
```
1. Go to: https://meme-explorer-staging.onrender.com/
2. Click: "Sign Up"
3. Create test account
4. Like some memes
5. Save some memes
6. Verify data persists (refresh page)
```

### 5.3 Test Error Monitoring
```bash
# Trigger 404 error
curl https://meme-explorer-staging.onrender.com/does-not-exist

# Check Sentry:
# https://sentry.io/organizations/your-org/issues/
# Should see 404 error from staging app
```

### 5.4 Load Testing (Optional)
```bash
# Simulate multiple users
for i in {1..10}; do
  curl https://meme-explorer-staging.onrender.com/random &
done

# Monitor performance:
# Render Dashboard → Metrics
# Should see: CPU < 50%, Memory < 200MB
```

### 5.5 Database Validation
```bash
# Connect to staging database and verify:

# Users table
psql $DATABASE_URL -c "SELECT COUNT(*) FROM users;"

# Meme stats
psql $DATABASE_URL -c "SELECT COUNT(*) FROM meme_stats;"

# All should match production (or be 0 if fresh start)
```

---

## Step 6: Monitor Staging for 24 Hours (Continuous)

### 6.1 Watch These Metrics
```
Render Dashboard → meme-explorer-staging → Metrics

✓ Response time: Should be < 500ms
✓ Error rate: Should be 0%
✓ Memory: Should stay < 300MB
✓ CPU: Should stay < 70%
```

### 6.2 Check Error Logs
```
Render Dashboard → meme-explorer-staging → Logs

Look for:
✓ No database connection errors
✓ No "cannot find table" errors
✓ No timeout errors
```

### 6.3 Sentry Monitoring
```
https://sentry.io/organizations/your-org/issues/

✓ No spike in errors
✓ 404s only (expected)
✓ No database errors
```

---

## ✅ Day 2 Success Criteria

- [ ] Render staging PostgreSQL created
- [ ] Staging web service deployed
- [ ] Environment variables configured
- [ ] Migration executed on staging
- [ ] Phase 3 algorithm works
- [ ] User accounts work
- [ ] Sentry monitoring works
- [ ] Load testing passed
- [ ] No database errors
- [ ] Monitoring shows healthy metrics
- [ ] 24-hour monitoring period completed

---

## 🚨 If Something Goes Wrong

### Issue: Database connection refused
**Solution:**
1. Verify DATABASE_URL is correct
2. Check database is running: Render Dashboard → Databases
3. Restart web service

### Issue: Migration failed
**Solution:**
1. Check logs for specific error
2. Restore backup: `psql $DATABASE_URL < backup.sql`
3. Fix issue locally, retest
4. Try migration again

### Issue: Phase 3 not loading memes
**Solution:**
1. Check Redis connection (if used)
2. Check Reddit API credentials
3. Verify database has meme_stats table
4. Check Sentry for errors

### Issue: Performance too slow
**Solution:**
1. Check database indexes: Created during migration
2. Monitor query times
3. Scale up Render plan if needed
4. Check for N+1 queries in logs

---

## 🎯 Ready for DAY 3?

After 24 hours of successful staging monitoring:
1. ✅ Verify all tests pass
2. ✅ Confirm no errors in Sentry
3. ✅ Performance is acceptable
4. ✅ Users can login and use app

**Then → Proceed to DAY 3: Production Deployment**

---

## Rollback Plan (If Staging Fails)

```bash
# Easiest rollback:
1. Render Dashboard → meme-explorer-staging
2. Click: "Delete Service"
3. Create new staging service (repeat from Step 1)

# That's it - production is unaffected
```

---

## Timeline Summary

| Task | Duration |
|------|----------|
| Create staging database | 10 min |
| Create staging web service | 5 min |
| Configure environment variables | 10 min |
| Deploy staging | 5 min |
| Run migration | 10 min |
| Test Phase 3 algorithm | 15 min |
| Test user accounts | 15 min |
| Test error monitoring | 10 min |
| Load testing | 15 min |
| 24-hour monitoring | 1 day |
| **TOTAL** | **~1.5 hours + 1 day** |

---

## Commands Reference

```bash
# Deploy Render staging
git push staging main

# Check health
curl https://meme-explorer-staging.onrender.com/health

# Run migration
ruby db/migrate_sqlite_to_postgres.rb

# Test Phase 3
curl https://meme-explorer-staging.onrender.com/random

# Monitor logs
tail -f ~/.local/share/render/logs/meme-explorer-staging.log
```

---

**Ready to start DAY 2?**

→ Start at Step 1: Create Render Staging Environment
