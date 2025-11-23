# Week 3 Deployment Instructions: Meme Explorer to Render

## Overview
Deploy Meme Explorer to production on Render with PostgreSQL backing. This guide covers the Hybrid Approach (Option C):
- Days 1-2: Deploy to production
- Days 3-5: Monitor and optimize with Sentry

---

## Prerequisites Checklist

- [ ] GitHub account with meme-explorer repository pushed
- [ ] Render.com account created (free)
- [ ] Sentry.io account created (free)
- [ ] PostgreSQL local setup verified (test suite passing)
- [ ] .env.production file created

---

## Step 1: Create Render Account & PostgreSQL Database

### 1.1 Go to Render.com
1. Visit https://render.com
2. Sign up (free tier available)
3. Create new account or log in

### 1.2 Create PostgreSQL Database
1. Dashboard → New (+) → PostgreSQL
2. Configuration:
   - Name: `meme-explorer-postgres`
   - Database: `meme_explorer_prod`
   - User: `meme_explorer`
   - Region: Oregon (or closest to you)
   - Plan: Starter ($15/month)
3. Create Database
4. **Copy the Internal Database URL** (you'll need this)
   - Format: `postgresql://user:password@internal_hostname:5432/meme_explorer_prod`

---

## Step 2: Create Render Web Service

### 2.1 Connect GitHub
1. Dashboard → New (+) → Web Service
2. "Connect repository"
3. Authorize GitHub and select `meme-explorer`
4. Configuration:
   - Name: `meme-explorer`
   - Environment: Ruby
   - Build Command: `bundle install`
   - Start Command: `bundle exec rackup config.ru -p $PORT`
   - Plan: Free (or Pro for better performance)
   - Region: Oregon

### 2.2 Set Environment Variables
In the "Environment" section, add:
```
RACK_ENV=production
PORT=3000
DATABASE_URL=<paste internal URL from Step 1.2>
DB_TYPE=postgres
SESSION_SECRET=<generate random string here>
SENTRY_DSN=<leave empty for now, add after Step 3>
```

**Generate SESSION_SECRET:**
```bash
ruby -r securerandom -e "puts SecureRandom.hex(32)"
```

### 2.3 Deploy
- Click "Create Web Service"
- Render will deploy automatically
- **Wait for deployment to complete** (takes 5-10 minutes)

---

## Step 3: Set Up Sentry Error Tracking

### 3.1 Create Sentry Project
1. Go to https://sentry.io
2. Sign up (free tier)
3. Create new project:
   - Platform: Ruby/Sinatra
   - Alert settings: Default
4. **Copy your DSN** (looks like: `https://key@sentry.io/project-id`)

### 3.2 Add Sentry to Production
1. Go to Render dashboard
2. Select `meme-explorer` service
3. Settings → Environment Variables
4. Add/Update:
   - `SENTRY_DSN=<your DSN from Step 3.1>`
5. Manual Deploy or wait for next git push

---

## Step 4: Verify Deployment

### 4.1 Test Health Endpoint
```bash
curl https://meme-explorer.onrender.com/health
```

Expected response:
```json
{
  "status": "ok",
  "uptime_seconds": 123,
  "cache_status": {
    "total_memes": 18,
    "cache_freshness": "FRESH"
  }
}
```

### 4.2 Test Core Features
1. Random meme: https://meme-explorer.onrender.com/random.json
2. Search: https://meme-explorer.onrender.com/search?q=funny
3. Homepage: https://meme-explorer.onrender.com/

---

## Step 5: Monitor Production (Days 3-5)

### 5.1 Watch Sentry Dashboard
1. Go to Sentry.io dashboard
2. Monitor for errors in real-time
3. Set up alerts:
   - Alert if: 5+ errors in 5 minutes
   - Alert if: New error type detected
   - Notify: Your email

### 5.2 Check Render Logs
1. Render dashboard → meme-explorer service
2. Logs tab
3. Look for:
   - Database connection errors
   - Memory/CPU issues
   - Deployment failures

### 5.3 Performance Monitoring
Track in Sentry:
- Error rate (should be <0.5%)
- Response time (should be <200ms average)
- User sessions

---

## Troubleshooting

### App won't start
1. Check Render logs for error messages
2. Verify DATABASE_URL is correct
3. Run: `bundle exec rackup config.ru` locally to test

### Database connection failing
1. Verify DATABASE_URL copied correctly
2. Check if PostgreSQL service is ready (Render takes ~2 min)
3. Render dashboard → PostgreSQL service → Logs

### Tests failing on production
1. Check `/errors` endpoint (admin panel)
2. Review Sentry dashboard for patterns
3. Look for environment-specific issues

### Performance is slow
1. Check if PostgreSQL connection pool is saturated
2. Monitor cache hit rates in logs
3. Consider upgrading Render tier

---

## Next Steps: Days 3-5 Optimization

Based on Sentry data, focus on:
1. **Critical errors** - Fix immediately
2. **Slow endpoints** - Optimize queries
3. **Test coverage** - Add tests for found issues
4. **Performance** - Tune based on real metrics

---

## Rollback Plan (If Needed)

If production deployment has critical issues:
1. Render dashboard → meme-explorer
2. Environment → Toggle `RACK_ENV=development`
3. Or roll back to previous git commit
4. Deploy again after fixes

---

## Success Criteria

✅ App loads in <2 seconds  
✅ /random.json returns memes  
✅ Search works  
✅ Like functionality works  
✅ Error rate <0.5% in Sentry  
✅ No spike in error logs  

**Once all verified, you have a production-ready app serving real users!**
