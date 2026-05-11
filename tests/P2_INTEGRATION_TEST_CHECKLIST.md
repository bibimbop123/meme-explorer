# ✅ P2 Integration Test Checklist

**Version:** 2.0  
**Date:** May 11, 2026  
**Environment:** Production/Staging  
**Tester:** _______________

---

## 📋 Overview

This checklist ensures all P2 features are working correctly in production before declaring deployment successful.

**Testing Order:**
1. Basic functionality (health checks)
2. A/B testing system
3. Request timing & monitoring
4. Background jobs (Sidekiq)
5. Architecture integrity
6. Performance benchmarks

**Estimated Time:** 45-60 minutes

---

## 🏥 1. Health & Basic Functionality

### 1.1 Health Check Endpoint
- [ ] Visit `/health`
- [ ] Response status is `200 OK`
- [ ] JSON includes `status: "ok"`
- [ ] All services show as `"ok"`: database, redis, sidekiq
- [ ] Sidekiq stats present (processed, failed, enqueued)
- [ ] Response time < 500ms

**Expected Response:**
```json
{
  "status": "ok",
  "services": {
    "database": "ok",
    "redis": "ok",
    "sidekiq": "ok"
  },
  "sidekiq": {
    "processed": 123,
    "failed": 0,
    "enqueued": 4
  }
}
```

### 1.2 Core Routes Still Work
- [ ] Homepage (`/`) loads successfully
- [ ] Random meme (`/random`) displays correctly
- [ ] Random API (`/random.json`) returns valid JSON
- [ ] Trending page (`/trending`) shows memes
- [ ] Search (`/search?q=test`) returns results
- [ ] Leaderboard (`/leaderboard`) displays rankings
- [ ] Profile pages accessible

**Notes:** _______________

---

## 🧪 2. A/B Testing Framework

### 2.1 Admin Access
- [ ] Visit `/admin/ab-testing`
- [ ] Redirected to login if not authenticated
- [ ] Login with admin credentials
- [ ] Admin dashboard displays
- [ ] "Create Experiment" button visible

### 2.2 Create Experiment
- [ ] Click "Create Experiment"
- [ ] Fill form:
  - Name: `test_integration`
  - Description: `Integration test experiment`
  - Variants: `control: 0.5, variant: 0.5`
  - Active: ✅
- [ ] Submit form
- [ ] Success message appears
- [ ] Experiment appears in list

### 2.3 Variant Assignment
- [ ] Open new incognito/private window
- [ ] Visit homepage
- [ ] Note assigned variant (check browser console or cookie)
- [ ] Refresh page 3 times
- [ ] **Verify:** Same variant assigned each time (consistent hashing)
- [ ] Close and reopen browser
- [ ] **Verify:** Still same variant (cookie persistence)

**Assigned Variant:** _______________

### 2.4 Conversion Tracking
- [ ] Perform conversion action (e.g., click CTA)
- [ ] Visit `/admin/ab-testing/experiments/test_integration/stats.json`
- [ ] Verify conversion recorded
- [ ] Sample count increased
- [ ] Conversion rate calculated correctly

### 2.5 Toggle Experiment Off
- [ ] Go back to admin interface
- [ ] Toggle experiment to "Inactive"
- [ ] Visit homepage in new incognito window
- [ ] **Verify:** No variant assigned to new users
- [ ] Existing users may still see their variant (cached)

### 2.6 View Statistics
- [ ] Visit experiment detail page
- [ ] Stats show for both variants
- [ ] Conversion rates displayed
- [ ] Sample sizes visible
- [ ] Winner indicated (if significant)
- [ ] Charts/graphs render correctly

**A/B Testing Score:** ___/6

---

## ⏱️ 3. Request Timing & Monitoring

### 3.1 Request Headers
- [ ] Make any request (e.g., GET `/random`)
- [ ] Open browser DevTools → Network tab
- [ ] Inspect response headers
- [ ] **Verify header present:** `X-Request-Duration`
- [ ] Duration value reasonable (e.g., "156ms")
- [ ] **Verify header present:** `X-Request-ID` (UUID format)

**Sample Duration:** _______________

### 3.2 Slow Request Detection
- [ ] Make a request that might be slow (e.g., complex search)
- [ ] Check application logs
- [ ] **If >500ms:** Warning logged
- [ ] **If >1000ms:** Alert sent to Sentry

**To test artificially slow request:**
```bash
# Add sleep to a route temporarily, or:
curl https://your-app.com/search?q=test&page=100
```

### 3.3 Sentry Integration
- [ ] Visit Sentry dashboard
- [ ] Check for any new errors from last 1 hour
- [ ] Look for "Slow request" events
- [ ] Verify request context included (duration, endpoint, user)
- [ ] Error grouping working correctly

**Sentry Status:** ✅ / ⚠️ / ❌

### 3.4 Metrics Dashboard
- [ ] Visit `/metrics` (admin only)
- [ ] Login if prompted
- [ ] Dashboard displays
- [ ] Performance metrics visible:
  - Average response time
  - P95/P99 response times
  - Requests per minute
- [ ] Cache metrics visible (hit rate, size)
- [ ] Database metrics visible (connections, queries)
- [ ] Sidekiq metrics visible (processed, failed, busy)

**Monitoring Score:** ___/4

---

## 🔄 4. Sidekiq Background Jobs

### 4.1 Sidekiq Dashboard Access
- [ ] Visit `/sidekiq`
- [ ] Prompted for username/password
- [ ] Enter credentials (from env vars)
- [ ] Dashboard loads successfully
- [ ] Shows Sidekiq version and uptime

### 4.2 Workers Running
- [ ] Navigate to "Busy" tab
- [ ] May see active jobs (or empty if between runs)
- [ ] Navigate to "Queues" tab
- [ ] See queues: `default`, `cache`, `analytics`, `cleanup`
- [ ] Queue sizes shown

**Active Workers:** _______________

### 4.3 Scheduled Jobs
- [ ] Navigate to "Scheduled" tab
- [ ] **Verify job present:** `CacheRefreshWorker` (next run ~10 min)
- [ ] **Verify job present:** `LeaderboardCalculationWorker` (next run ~1 hour)
- [ ] **Verify job present:** `DatabaseCleanupWorker` (next run: 2 AM)
- [ ] **Verify job present:** `ActivityAggregationWorker` (next run ~5 min)
- [ ] Next run times displayed correctly

**Next Cache Refresh:** _______________

### 4.4 Job Processing
- [ ] Wait for a scheduled job to run (or trigger manually if possible)
- [ ] Navigate to "Processed" tab
- [ ] Verify job count increasing over time
- [ ] Check "Failed" tab
- [ ] **Verify:** 0 failed jobs (or investigate if failures present)

**Processed in last hour:** _______________  
**Failed jobs:** _______________

### 4.5 Manual Worker Test
If you have access to trigger jobs manually:

```bash
# In Rails console or Sidekiq console
CacheRefreshWorker.perform_async
```

- [ ] Job enqueued successfully
- [ ] Job appears in "Enqueued" or "Busy"
- [ ] Job completes within expected time
- [ ] No errors in logs
- [ ] Cache updated (verify by checking timestamps)

### 4.6 Worker Logs
- [ ] Check application logs for Sidekiq output
- [ ] Jobs starting and completing logged
- [ ] No error stack traces
- [ ] Performance metrics in logs (job duration)

**Sidekiq Score:** ___/6

---

## 🏗️ 5. Architecture Integrity

### 5.1 All Routes Accessible
Test that refactoring didn't break any routes:

**Public Routes:**
- [ ] `GET /` - Homepage
- [ ] `GET /random` - Random meme page
- [ ] `GET /random.json` - Random meme API
- [ ] `GET /trending` - Trending page
- [ ] `GET /search?q=test` - Search
- [ ] `GET /leaderboard` - Leaderboard
- [ ] `GET /profile/testuser` - Public profile

**Auth Routes:**
- [ ] `GET /login` - Login page
- [ ] `GET /signup` - Signup page
- [ ] `POST /auth/login` - Login endpoint (test with curl)
- [ ] `POST /auth/logout` - Logout endpoint

**Authenticated Routes:**
- [ ] `GET /profile` - Own profile (requires login)
- [ ] `POST /memes/:id/save` - Save meme (requires login)
- [ ] `POST /memes/:id/react` - React to meme

**Admin Routes:**
- [ ] `GET /admin` - Admin dashboard
- [ ] `GET /admin/ab-testing` - A/B testing interface
- [ ] `GET /metrics` - Metrics dashboard
- [ ] `GET /sidekiq` - Sidekiq UI

**Routes Tested:** ___/16

### 5.2 Sessions Persist
- [ ] Login to application
- [ ] Navigate to different pages
- [ ] **Verify:** Stay logged in across pages
- [ ] Close browser
- [ ] Reopen and visit site
- [ ] **Verify:** Session persisted (if remember me) or expired appropriately

### 5.3 Authentication Works
- [ ] Try accessing `/profile` without login
- [ ] **Verify:** Redirected to login page
- [ ] Try accessing `/admin` without admin role
- [ ] **Verify:** Forbidden or redirected
- [ ] Login with valid credentials
- [ ] **Verify:** Access granted

### 5.4 API Endpoints Return Correct Data
- [ ] `GET /random.json` returns meme object with required fields
- [ ] `GET /trending.json` returns array of memes
- [ ] `GET /search.json?q=test` returns search results
- [ ] `GET /leaderboard.json` returns rankings
- [ ] All JSON responses valid (no HTML mixed in)

**Architecture Score:** ___/4

---

## 📈 6. Performance Benchmarks

### 6.1 Response Time Tests

Use this command or browser DevTools:
```bash
curl -o /dev/null -s -w "Time: %{time_total}s\n" https://your-app.com/endpoint
```

| Endpoint | Target | Actual | Pass/Fail |
|----------|--------|--------|-----------|
| `/` | <300ms | ___ms | ___ |
| `/random` | <200ms | ___ms | ___ |
| `/random.json` | <150ms | ___ms | ___ |
| `/trending` | <500ms | ___ms | ___ |
| `/search?q=test` | <400ms | ___ms | ___ |
| `/leaderboard` | <600ms | ___ms | ___ |

**Average:** ___ms  
**All under targets:** ✅ / ❌

### 6.2 Memory Usage
- [ ] Check hosting dashboard for memory usage
- [ ] **Current usage:** ___MB
- [ ] **Target:** <400MB
- [ ] **Status:** Within limits ✅ / Over limit ❌

### 6.3 Database Connections
- [ ] Check database dashboard
- [ ] **Active connections:** ___
- [ ] **Target:** <30
- [ ] **Status:** Within limits ✅ / Over limit ❌

### 6.4 Cache Hit Rate
- [ ] Check Redis stats or metrics dashboard
- [ ] **Hit rate:** ___%
- [ ] **Target:** >70%
- [ ] **Status:** Acceptable ✅ / Needs improvement ❌

### 6.5 Error Rate
- [ ] Check logs or Sentry for errors in last hour
- [ ] **Errors:** ___
- [ ] **Requests:** ~___
- [ ] **Error rate:** ___%
- [ ] **Target:** <0.5%
- [ ] **Status:** Acceptable ✅ / Too high ❌

**Performance Score:** ___/5

---

## 🎯 Final Verification

### Critical Path Test (5-Minute User Journey)

Simulate a real user's journey:

1. [ ] Visit homepage
2. [ ] Click "Random Meme"
3. [ ] See meme displayed with image
4. [ ] Click "Next" for another random meme
5. [ ] React to meme (like/laugh/fire)
6. [ ] Search for "funny"
7. [ ] View search results
8. [ ] Click on a meme from results
9. [ ] Visit trending page
10. [ ] Check leaderboard
11. [ ] Sign up for new account
12. [ ] Save a meme to favorites
13. [ ] View profile
14. [ ] Logout

**Journey completed without errors:** ✅ / ❌  
**Notes:** _______________

---

## 📊 Test Summary

### Scores

| Category | Score | Status |
|----------|-------|--------|
| Health & Basic | __/6 | ___ |
| A/B Testing | __/6 | ___ |
| Monitoring | __/4 | ___ |
| Sidekiq | __/6 | ___ |
| Architecture | __/4 | ___ |
| Performance | __/5 | ___ |
| **TOTAL** | **__/31** | ___ |

### Pass/Fail Criteria
- **Pass:** ≥28/31 (90%+) with no critical failures
- **Conditional:** 24-27/31 (77-87%) - minor issues acceptable
- **Fail:** <24/31 - requires fixes before production

### Critical Issues Found
1. _______________
2. _______________
3. _______________

### Minor Issues Found
1. _______________
2. _______________
3. _______________

### Recommendations
1. _______________
2. _______________
3. _______________

---

## ✅ Sign-Off

**Tester Name:** _______________  
**Date/Time:** _______________  
**Overall Result:** PASS / CONDITIONAL / FAIL  
**Approved for Production:** YES / NO  
**Notes:** _______________

---

## 📞 Next Steps

**If PASS:**
- [ ] Mark deployment as successful
- [ ] Begin 24-hour monitoring period
- [ ] Schedule retrospective
- [ ] Celebrate! 🎉

**If CONDITIONAL:**
- [ ] Document known issues
- [ ] Create tickets for fixes
- [ ] Deploy fixes in next iteration
- [ ] Continue monitoring

**If FAIL:**
- [ ] Document all failures
- [ ] Consider rollback
- [ ] Fix critical issues
- [ ] Re-test completely

---

**Last Updated:** May 11, 2026  
**Version:** 2.0
