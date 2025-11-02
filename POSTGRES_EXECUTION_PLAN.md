# 🚀 PostgreSQL Migration - Detailed Execution Plan

**Goal:** Safely migrate from SQLite to PostgreSQL this week  
**Risk Level:** HIGH (database) → MITIGATED (staged approach)  
**Timeline:** 3 days of execution (12-16 hours active work)

---

## 🎯 Strategic Approach (Senior Engineer Perspective)

### Why Staged Execution?
- Database migrations are HIGH RISK
- Need testing at each stage before production
- Rollback must be possible
- Zero downtime is target
- Data integrity MUST be verified

### Recommended Sequence:
1. **Day 1 (LOCAL):** Test migration locally
2. **Day 2 (STAGING):** Deploy & test on Render staging
3. **Day 3 (PRODUCTION):** Blue-green deployment to production

---

## 📋 PRE-FLIGHT CHECKLIST

Before starting ANY migration work, verify:

```bash
# 1. Check current SQLite size
ls -lh db/memes.db
# Expected: Small file (~1-10MB)

# 2. Verify backup exists
ls -lh db/memes.db.backup
# Expected: Backup file present

# 3. Test migration script locally
bash scripts/verify_postgres_setup.sh
# Expected: All checks pass ✅

# 4. Confirm Render staging exists
# Go to: https://dashboard.render.com/
# Expected: meme-explorer-staging service visible
```

---

## 🗓️ DAY 1: LOCAL TESTING (4-5 hours)

### Step 1: Create Local PostgreSQL Database
```bash
# 1. Start PostgreSQL
brew services start postgresql

# 2. Create database for testing
createdb -U postgres meme_explorer_local

# 3. Verify connection
psql -U postgres -d meme_explorer_local -c "SELECT version();"
# Expected: PostgreSQL version printed
```

### Step 2: Run Local Migration
```bash
# 1. Set test environment variable
export DATABASE_URL="postgresql://postgres@localhost/meme_explorer_local"

# 2. Run migration script (DRY RUN FIRST)
ruby db/migrate_sqlite_to_postgres.rb --dry-run
# Review output carefully - this is a SIMULATION

# 3. If dry-run looks good, run ACTUAL migration
ruby db/migrate_sqlite_to_postgres.rb
# Expected: "Migration complete" message

# 4. Verify data integrity
psql -U postgres -d meme_explorer_local -c "SELECT COUNT(*) FROM meme_stats;"
# Expected: Same count as in SQLite
```

### Step 3: Local Testing with RSpec
```bash
# 1. Run test suite against PostgreSQL
export DATABASE_URL="postgresql://postgres@localhost/meme_explorer_local"
bundle exec rspec --format progress
# Expected: All tests pass (60%+ coverage)

# 2. Manual testing
bundle exec puma -c config/puma.rb
# Visit: http://localhost:3000/random
# Test: Phase 3 algorithm works
# Test: Memes load correctly
# Test: No database errors in logs
```

### Step 4: Backup SQLite (CRITICAL)
```bash
# 1. Create timestamped backup
cp db/memes.db db/memes.db.backup.$(date +%Y%m%d_%H%M%S)

# 2. Store securely (outside project)
cp db/memes.db ~/Desktop/meme_explorer_sqlite_backup.db

# 3. Verify backup
ls -lh ~/Desktop/meme_explorer_sqlite_backup.db
# Expected: Same size as original
```

### ✅ Day 1 Success Criteria
- [ ] PostgreSQL installed locally
- [ ] Database created successfully
- [ ] Migration script runs without errors
- [ ] RSpec tests pass (60%+)
- [ ] Manual testing works
- [ ] SQLite backup created (2 copies)
- [ ] All data verified

---

## 🗓️ DAY 2: STAGING DEPLOYMENT (4-5 hours)

### Step 1: Set Up Render Staging
```bash
# 1. Go to Render dashboard
https://dashboard.render.com/

# 2. Look for meme-explorer-staging service
# If it doesn't exist, create it as a staging environment

# 3. Create PostgreSQL database on Render
# Render → Databases → Create PostgreSQL
# Name: meme-explorer-staging-db
# Region: Same as web service
```

### Step 2: Deploy to Staging
```bash
# 1. Create staging branch
git checkout -b staging

# 2. Set DATABASE_URL in staging environment
# Render Dashboard → meme-explorer-staging → Environment
# Add: DATABASE_URL=postgresql://user:pass@host:5432/db_name

# 3. Deploy to staging
git push staging
# Or redeploy manually in Render dashboard
```

### Step 3: Run Staging Migration
```bash
# 1. SSH into Render staging (if available)
# Or create a one-time process to run migration

# 2. Execute migration on staging
# (Command depends on Render environment)
```

### Step 4: Test Staging Thoroughly
```bash
# 1. Test Phase 3 algorithm
curl https://meme-explorer-staging.onrender.com/random -s | grep -i "spaced\|meme"

# 2. Test user accounts
# Login with test account
# Create some likes/saves
# Verify they persist

# 3. Load testing
# Simulate multiple users
# Monitor performance
# Check error logs

# 4. Database query validation
# Random queries from Render dashboard
# Verify data integrity
```

### ✅ Day 2 Success Criteria
- [ ] PostgreSQL created on Render staging
- [ ] Migrations run successfully
- [ ] All tests pass on staging
- [ ] Phase 3 algorithm works
- [ ] No error logs
- [ ] Performance acceptable
- [ ] Rollback plan tested

---

## 🗓️ DAY 3: PRODUCTION DEPLOYMENT (3-4 hours)

### Step 1: Final Pre-Production Checks
```bash
# 1. Backup production SQLite
curl https://dashboard.render.com/ → Download backup

# 2. Notify users (if needed)
# Tweet: "Database upgrade today, should be seamless"

# 3. Have rollback ready
# Know exactly how to revert to SQLite
```

### Step 2: Blue-Green Deployment Strategy
```bash
# 1. Keep old SQLite running (blue)
# 2. Deploy with PostgreSQL (green)
# 3. If issues, switch back to blue

# Steps:
# a) Create DATABASE_URL for production PostgreSQL
# b) Deploy code to Render
# c) Run migration (with monitoring)
# d) Health check: curl health endpoint
# e) 5 minute monitoring period
# f) If all good → complete
# g) If problems → rollback to SQLite
```

### Step 3: Production Deployment
```bash
# 1. Merge staging into main
git checkout main
git merge staging
git push origin main

# 2. Render auto-deploys (or manual redeploy)
# Monitor: https://dashboard.render.com/

# 3. Set environment variable in production
# DATABASE_URL=postgresql://user:pass@host:5432/prod_db

# 4. Monitor logs for errors
# Render Dashboard → Logs
# Expected: No database errors
```

### Step 4: Validation
```bash
# 1. Check health endpoint
curl https://meme-explorer.onrender.com/health | jq .

# 2. Test Phase 3
curl https://meme-explorer.onrender.com/random

# 3. Monitor Sentry
# https://sentry.io/organizations/your-org/issues/
# Expected: No database errors

# 4. Check database
# Connect to production PostgreSQL
# Verify row counts match SQLite
```

### ✅ Day 3 Success Criteria
- [ ] Production PostgreSQL running
- [ ] All data migrated
- [ ] Phase 3 algorithm works
- [ ] Tests pass
- [ ] No Sentry errors
- [ ] Performance acceptable
- [ ] Users unaffected

---

## 🚨 ROLLBACK PLAN (If Needed)

### Immediate Rollback (< 5 minutes)
```bash
# 1. Revert to SQLite
git revert HEAD
git push origin main

# 2. Render redeploys (auto or manual)
# Should take 2-3 minutes

# 3. Remove DATABASE_URL env variable
# Render → Environment → Delete DATABASE_URL

# 4. Verify rollback
curl https://meme-explorer.onrender.com/health
# Expected: HTTP 200 with SQLite schema
```

### Analysis Phase
```bash
# 1. Export error logs from Sentry
# Identify root cause

# 2. Fix issue locally
# Test with RSpec

# 3. Try migration again
# From Day 1, with fix in place
```

---

## 📊 Monitoring During Migration

### Watch These Metrics
- **Response Time:** Should stay < 500ms
- **Error Rate:** Should stay 0%
- **Database Connections:** Should be < 10
- **Disk Usage:** Watch for runaway queries

### Commands to Monitor
```bash
# Watch Render logs in real-time
# Render Dashboard → meme-explorer → Logs

# Monitor database connections
# Render PostgreSQL Dashboard → Connections

# Check Sentry errors
# https://sentry.io/ → Issues
```

---

## ⚠️ Common Issues & Solutions

| Issue | Cause | Solution |
|-------|-------|----------|
| **Migration timeout** | Large dataset | Increase timeout in script |
| **Connection refused** | PostgreSQL not accessible | Check DATABASE_URL |
| **Data loss** | Migration bug | Restore from backup |
| **Performance slow** | Missing indexes | Migration script adds them |
| **Users complaining** | Brief downtime | Expected, takes 2-3 min |

---

## 📝 Checklist: Ready to Execute?

Before starting:
- [ ] PostgreSQL installed locally
- [ ] Migration script tested locally
- [ ] SQLite backup created (2 copies)
- [ ] Render staging configured
- [ ] RSpec tests at 60%+ passing
- [ ] Rollback plan understood
- [ ] Monitoring tools ready

**Ready? → Start Day 1 local testing**

---

## 🎯 Success Definition

After 3 days:
- ✅ PostgreSQL in production
- ✅ All data migrated
- ✅ Zero data loss
- ✅ Phase 3 working
- ✅ Tests passing
- ✅ Users happy
- ✅ 10x capacity ready (100 → 1,000+)

**Timeline: Complete by end of this week**
