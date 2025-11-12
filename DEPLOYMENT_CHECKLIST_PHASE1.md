# Phase 1 Deployment Checklist & Monitoring Guide

**Document**: Deployment preparation for Random Meme UX Phase 1
**Target**: Production deployment with canary strategy
**Timeline**: 2-4 hours total (including monitoring setup)

---

## PRE-DEPLOYMENT VERIFICATION (15 min)

### Code Quality Review
- [ ] `routes/memes.rb`: No console errors, genre filtering logic verified
- [ ] `views/random.erb`: All JavaScript classes instantiated correctly
- [ ] No breaking changes to existing functionality
- [ ] Backward compatibility confirmed (all `?genre` params optional)

### Browser Compatibility Tests
- [ ] Chrome/Chromium (latest 2 versions)
- [ ] Firefox (latest 2 versions)
- [ ] Safari (latest 2 versions)
- [ ] Mobile Safari (iOS)
- [ ] Chrome Mobile (Android)

### Mobile Testing
- [ ] Genre filter buttons responsive
- [ ] Stats display visible on 375px screens
- [ ] Back button accessible/visible
- [ ] Skeleton loader visible
- [ ] Keyboard shortcuts don't conflict with mobile OS

### Performance Baseline
- [ ] `/random.json` response time < 200ms
- [ ] Initial page load < 2s
- [ ] Skeleton animation smooth (60fps)
- [ ] localStorage operations < 10ms

### localStorage Verification
- [ ] localStorage available (not disabled)
- [ ] Session history persists correctly
- [ ] Streak data resets at midnight
- [ ] Genre preference persists after refresh
- [ ] 50KB usage limit confirmed

---

## STAGING DEPLOYMENT (30 min)

### Pre-Flight
- [ ] Backup current production code
- [ ] Verify staging environment matches production
- [ ] Clear browser cache/localStorage on staging

### Deploy to Staging
- [ ] Merge changes to staging branch
- [ ] Deploy to staging server
- [ ] Verify deployment successful (no 500 errors)

### Smoke Tests on Staging
- [ ] Load `/random` page successfully
- [ ] Genre filter buttons clickable
- [ ] Click genre filter → `/random.json?genre=funny` works
- [ ] Streak counter initializes to 0
- [ ] Daily likes counter initializes to 0
- [ ] Back button hidden initially
- [ ] Like meme → streak increments
- [ ] Like meme → back button appears
- [ ] Click back button → previous meme restored
- [ ] Hard refresh → stats persist (localStorage)
- [ ] Keyboard shortcuts work (Space, Backspace, T)
- [ ] No console errors (F12 check)
- [ ] Mobile responsive (DevTools)

### Data Validation
- [ ] localStorage quota not exceeded
- [ ] Genre filtering returns memes correctly
- [ ] All 4 genres have memes
- [ ] 'all' genre returns complete list
- [ ] Error handling for empty genre results

---

## PRODUCTION DEPLOYMENT STRATEGY

### Option A: Canary Deployment (Recommended) ✅
**Phase 1A: 10% Traffic (4 hours)**
- Deploy to 10% of users
- Monitor error rates, engagement metrics
- Set success criteria (zero critical errors, no performance regression)

**Phase 1B: 25% Traffic (next 4 hours)**
- If Phase 1A successful, expand to 25%
- Continue monitoring

**Phase 1C: 50% Traffic (next 4 hours)**
- If Phase 1B successful, expand to 50%
- Continue monitoring

**Phase 1D: 100% Traffic (final 2 hours)**
- Full production rollout
- Extended monitoring (24 hours)

### Option B: Direct Deployment (Faster)
- Deploy to 100% immediately
- Intensive monitoring for 24-48 hours
- Ready to rollback if issues

**Recommendation**: Use Option A (canary) - safer learning curve

---

## PRODUCTION DEPLOYMENT EXECUTION

### Pre-Deployment Communication
- [ ] Notify team in Slack: "Phase 1 deploying in X minutes"
- [ ] QA team standing by for testing
- [ ] On-call engineer available for rollback

### Deploy Command (Example)
```bash
# Merge to main
git checkout main
git pull origin main
git merge feature/phase1-random-improvements

# Deploy
# (adjust per your CI/CD setup)
git push origin main
# or
docker build -t meme-explorer:phase1 .
docker push meme-explorer:phase1
kubectl set image deployment/meme-explorer \
  meme-explorer=meme-explorer:phase1
```

### Deployment Verification
- [ ] No deployment errors
- [ ] All pods/services healthy
- [ ] Database migrations (if any) completed successfully
- [ ] No spike in error rates

---

## REAL-TIME MONITORING (First 24 Hours)

### Critical Metrics (Monitor Continuously)
**Every 5 minutes:**
- [ ] Error rate (target: < 0.1%)
- [ ] Response time: `/random.json` (target: < 300ms)
- [ ] HTTP 500 errors (target: 0)
- [ ] localStorage errors in logs (target: 0)

**Every 30 minutes:**
- [ ] Session duration change vs baseline
- [ ] Genre filter click rate
- [ ] Like button engagement
- [ ] Back button usage
- [ ] User retention rate

**Every 2 hours:**
- [ ] Cumulative engagement metrics
- [ ] Device type breakdown (mobile vs desktop)
- [ ] Browser distribution (any specific failures?)

### Success Criteria (Phase 1 Deployment Valid)
✅ All criteria must be met:
- Error rate remains < 0.1%
- No new exceptions from genre filtering code
- Response times stable (no >500ms spikes)
- localStorage operations successful (no quota exceeded)
- > 40% of sessions use genre filter (adoption indicator)

### Warning Triggers (Escalation Required)
⚠️ Pause deployment & investigate:
- Error rate > 1%
- Response time > 500ms consistently
- Any `localStorage` exceptions
- Genre filtering returning empty results unexpectedly
- Back button not functioning
- Skeleton loader blocking content

### Critical Failure (Rollback)
🔴 Automatic rollback if:
- Error rate > 5%
- Database connection failures
- Session data loss
- API endpoint crashes

---

## MONITORING DASHBOARD SETUP

### Metrics to Track (Post-Deployment)

**Engagement Metrics**
```
metric: session_duration_seconds
  baseline: 240 (4 minutes)
  target: 336 (5.6 minutes, +40%)
  
metric: memes_viewed_per_session
  baseline: 8
  target: 11+ (+35%)
  
metric: genre_filter_usage_rate
  target: >70% of sessions
  
metric: like_rate
  baseline: 15% of memes viewed
  target: 18%+
```

**Technical Metrics**
```
metric: random_json_response_time_ms
  target: <300ms (p95: <500ms)
  
metric: page_load_time_ms
  target: <2s
  
metric: javascript_errors_per_session
  target: 0
  
metric: localstorage_quota_usage_percent
  target: <25%
```

**User Experience**
```
metric: back_button_clicks_per_session
  target: >0.5 (indicates usage)
  
metric: genre_preference_persistence
  target: >95% (genre remembered after refresh)
  
metric: daily_return_rate
  baseline: 25%
  target: 31%+ (+25%)
```

### SQL Queries for Metrics (if using analytics DB)

**Session Duration Comparison**
```sql
SELECT 
  DATE(created_at) as date,
  AVG(CASE WHEN has_genre_filter=1 THEN session_duration ELSE NULL END) as phase1_avg,
  AVG(CASE WHEN has_genre_filter=0 THEN session_duration ELSE NULL END) as baseline_avg
FROM sessions
GROUP BY DATE(created_at)
ORDER BY date DESC
LIMIT 14;
```

**Genre Filter Adoption**
```sql
SELECT 
  genre,
  COUNT(*) as count,
  ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 2) as percentage
FROM genre_filter_events
WHERE DATE(created_at) = CURDATE()
GROUP BY genre
ORDER BY count DESC;
```

**Engagement Lift**
```sql
SELECT 
  DATE(created_at) as date,
  COUNT(DISTINCT session_id) as sessions,
  SUM(memes_viewed) as total_memes,
  SUM(likes_given) as total_likes,
  ROUND(AVG(session_duration_sec), 1) as avg_session_duration
FROM user_analytics
WHERE DATE(created_at) >= DATE_SUB(CURDATE(), INTERVAL 7 DAY)
GROUP BY DATE(created_at)
ORDER BY date DESC;
```

---

## TROUBLESHOOTING GUIDE

### Issue: "Genre filter returns no results"
**Diagnosis**: Subreddit mapping incomplete
**Fix**: 
1. Check `filter_memes_by_genre()` in routes/memes.rb
2. Verify meme subreddit names match mapping
3. Add missing subreddits to genre_map
**Prevention**: Backfill genre categories for all memes

### Issue: "localStorage full error"
**Diagnosis**: History stack consuming too much space
**Fix**:
1. Reduce max history size from 15 to 10
2. Clear old session data
3. Implement cleanup on session end
**Prevention**: Monitor localStorage usage in real-time

### Issue: "Back button not appearing"
**Diagnosis**: History stack not initializing
**Fix**:
1. Check browser console for errors
2. Verify sessionStorage is enabled
3. Clear browser cache/sessionStorage
4. Hard refresh page (Ctrl+Shift+R)
**Prevention**: Add error boundaries in JavaScript

### Issue: "Skeleton loader never disappears"
**Diagnosis**: Fetch request hanging
**Fix**:
1. Check network tab for timeout
2. Verify `/random.json` endpoint responding
3. Increase timeout threshold
4. Check for CORS issues
**Prevention**: Add fetch error handling

### Issue: "Performance degradation after deployment"
**Diagnosis**: Possible memory leak or inefficient code
**Fix**:
1. Profile JavaScript (DevTools → Performance)
2. Check for event listener leaks
3. Monitor memory usage over time
4. Reduce animation frame rate if needed
**Prevention**: Load testing before deployment

---

## ROLLBACK PROCEDURE (If Critical Issues)

### Immediate Rollback Steps (< 5 min)
1. [ ] Stop accepting new connections to Phase 1
2. [ ] Revert to previous production version:
   ```bash
   git revert HEAD
   git push origin main
   # or
   kubectl rollout undo deployment/meme-explorer
   ```
3. [ ] Verify rollback successful
4. [ ] Monitor error rates return to normal

### Post-Rollback Analysis
1. [ ] Identify root cause of failure
2. [ ] Fix in development environment
3. [ ] Re-test thoroughly
4. [ ] Schedule re-deployment in 24 hours

---

## POST-DEPLOYMENT (24-48 Hours)

### Success Celebration ✅
If all metrics positive:
- [ ] Notify team: Phase 1 successful
- [ ] Document lessons learned
- [ ] Schedule Phase 2 planning meeting

### Continued Monitoring
- [ ] Monitor Phase 1 for 7 days
- [ ] Collect user feedback
- [ ] Document any edge cases
- [ ] Plan Phase 2 based on Phase 1 data

### Phase 2 Decision Point (48 hours)
**Proceed to Phase 2 if:**
- ✅ Error rate stable < 0.5%
- ✅ Genre filter adoption > 50%
- ✅ Session duration +30%+ vs baseline
- ✅ Zero critical user-reported issues
- ✅ Team consensus to continue

**Defer Phase 2 if:**
- ⚠️ Unexpected issues require fixes
- ⚠️ Adoption lower than expected
- ⚠️ Performance not meeting targets
- ⚠️ Team capacity constraints

---

## DEPLOYMENT SIGN-OFF

**Code Review**: _________________ Date: _______
**QA Testing**: _________________ Date: _______
**Product Owner**: _________________ Date: _______
**Engineering Lead**: _________________ Date: _______

**Ready for Production Deployment**: [ ] YES  [ ] NO

---

**Deployment Initiated**: _________________ Time: _______
**Deployment Completed**: _________________ Time: _______
**Monitoring Status**: ACTIVE ✅
**Rollback Readiness**: READY ✅
