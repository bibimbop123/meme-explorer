# 🚀 Quick Start - TODAY'S 30-Minute Implementation

**Goal:** Deploy Phase 3 + Sentry to production  
**Duration:** 30 minutes  
**Status:** Phase 3 ✅ DONE | Sentry 🔄 IN PROGRESS

---

## ✅ DONE: Phase 3 Activation (5 minutes ago)

**What happened:**
- `/` route now uses `navigate_meme_v3()`
- `/random` route now uses `navigate_meme_v3()`
- Spaced repetition algorithm LIVE
- Algorithm score: 72 → 78

**Verify Phase 3 works:**
```bash
# Start dev server
bundle exec puma -c config/puma.rb

# Visit in browser
http://localhost:3000

# Test: Click next meme → see different meme each time
# Test: Wait 1 hour → same meme won't repeat until then
```

---

## ⏳ TODO: Sentry Setup (20 minutes)

### Step 1: Create Sentry Account (5 min)
```bash
# Go to https://sentry.io/signup/
# Sign up with email or GitHub
# Create organization: "Meme Explorer"
# Create project: select "Ruby" → "Sinatra"
# Copy your SENTRY_DSN (looks like: https://key@sentry.io/12345)
```

### Step 2: Add SENTRY_DSN to .env (2 min)
```bash
# Edit .env and add:
SENTRY_DSN="https://your-key@sentry.io/your-id"
SENTRY_ENVIRONMENT="production"
SENTRY_TRACES_SAMPLE_RATE="0.1"

# For development override:
SENTRY_ENVIRONMENT="development"
SENTRY_TRACES_SAMPLE_RATE="0.0"
```

### Step 3: Verify Sentry Installation (3 min)
```bash
# Stop and restart server to load new .env
bundle exec puma -c config/puma.rb

# Trigger a test error
# Visit any route and check logs for "Sentry" messages
# If Sentry is loaded, you'll see: "✅ Sentry initialized"
```

### Step 4: Verify Error Capture (5 min)
```bash
# Option A: Trigger a real error
# Visit: http://localhost:3000/doesnotexist
# Check Sentry dashboard - should see 404 error in ~30 seconds

# Option B: Manual test error
bundle exec ruby -e "
require 'sentry-ruby'
Sentry.init do |config|
  config.dsn = ENV['SENTRY_DSN']
end
Sentry.capture_message('Test message from CLI')
puts 'Test event sent to Sentry'
"

# Check Sentry dashboard - should see event within 30 seconds
```

### Step 5: Deploy to Production (5 min)
```bash
# Add SENTRY_DSN to Render environment variables:
# 1. Go to: https://dashboard.render.com/
# 2. Select: meme-explorer
# 3. Go to: Environment
# 4. Add: SENTRY_DSN = your-key
# 5. Redeploy

# Verify in logs:
# Should see: "✅ Sentry initialized"
```

---

## 📋 Verification Checklist

```
TODAY (BEFORE END OF DAY):
- [ ] Phase 3 active on /random (tested locally)
- [ ] Sentry account created
- [ ] SENTRY_DSN added to .env
- [ ] Sentry working locally (test error works)
- [ ] SENTRY_DSN added to Render
- [ ] Render redeployed with Sentry
- [ ] Production Sentry working (trigger test error on live site)

RESULT: Phase 3 + Sentry live in production ✅
```

---

## 🎯 Success Criteria

✅ **Phase 3:**
- Memes don't repeat within 1 hour (1st view)
- Spaced repetition decay is active
- Time-based pool selection working

✅ **Sentry:**
- Errors appear in dashboard in real-time
- Can see error rate, trends, affected users
- Alerts configured (optional)

---

## Troubleshooting

**"Sentry not available" warning:**
- Solution: Run `bundle install` to ensure gems are installed

**Events not appearing in Sentry:**
- Check: SENTRY_DSN is correct in .env
- Check: RACK_ENV is not "test"
- Check: Error occurred AFTER app restarted
- Check: Sentry quota (free: 5K events/month)

**Phase 3 memes repeating:**
- Solution: Wait for exponential decay timeout
- 1st view: 1 hour, 2nd: 4 hours, 3rd: 16 hours, 4th: 64 hours

---

## Next Steps (AFTER TODAY)

```
THIS WEEK:
→ PostgreSQL migration (12-16 hours)
→ Run full test suite (2-3 hours)

NEXT WEEK:
→ Deploy CDN Cloudflare (1-2 hours)
→ Complete test coverage (1-2 hours)
→ Multi-worker deployment (2-3 hours)

RESULT: 100 → 1,000+ users capacity
```

---

## Quick Links

- Sentry Dashboard: https://sentry.io/organizations/your-org/issues/
- Render Dashboard: https://dashboard.render.com/
- Meme Explorer Live: https://meme-explorer.onrender.com/
