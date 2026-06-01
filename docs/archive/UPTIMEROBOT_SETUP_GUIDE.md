# 🤖 UptimeRobot Setup Guide - Keep Your Site Awake

## Why This Is Critical

**Problem**: Render free tier sleeps after 15 minutes of inactivity
**Solution**: UptimeRobot pings your site every 5 minutes → Site NEVER sleeps
**Result**: AdSense crawler always hits a warm, fast site (no "site down" errors)

**Time required**: 5 minutes
**Cost**: FREE forever

---

## Step-by-Step Setup

### Step 1: Create Free Account (2 min)

1. Go to: **https://uptimerobot.com**
2. Click: **"Sign Up Free"** (top right)
3. Enter your email address
4. Choose a password
5. Click **"Sign Up"**
6. Check your email and **verify your account** (click the verification link)

---

### Step 2: Add Your First Monitor (3 min)

Once logged in to your UptimeRobot dashboard:

1. Click: **"+ Add New Monitor"** (big button)

2. Fill in the form:

   **Monitor Type**: 
   - Select: **HTTP(s)**
   
   **Friendly Name**: 
   - Enter: `Meme Explorer Health Check`
   
   **URL (or IP)**: 
   - Enter: `https://meme-explorer.onrender.com/health/live`
   
   **Monitoring Interval**: 
   - Select: **5 minutes** (this is perfect - keeps site warm)
   
   **Monitor Timeout**: 
   - Leave default: **30 seconds**
   
   **Alert Contacts To Notify**:
   - Check the box next to your email
   - This will alert you if the site actually goes down

3. Click: **"Create Monitor"** (bottom of form)

---

### Step 3: Verify It's Working (30 seconds)

1. You should see your new monitor in the dashboard
2. Status should show: **"Up"** with a green checkmark ✅
3. You'll see: "Last checked: a few seconds ago"

**Perfect!** Your site will now be pinged every 5 minutes.

---

## What Happens Now?

### Every 5 Minutes:
- UptimeRobot sends a request to `/health/live`
- Your Render service wakes up (if it was sleeping)
- Render resets its 15-minute sleep timer
- Your site stays perpetually awake 🔥

### If Your Site Goes Down:
- UptimeRobot detects it within 5 minutes
- You get an **email alert** immediately
- You can check the dashboard for uptime history

---

## Verification Tests

### Test 1: Check Monitor Status
Visit your UptimeRobot dashboard:
- Monitor should show **"Up"** status
- Response time should be < 1000ms (usually 200-500ms)

### Test 2: Wait 20 Minutes, Then Test Response Time
```bash
# After 20 minutes (normally would be cold start), test:
curl -w "\nResponse time: %{time_total}s\n" https://meme-explorer.onrender.com/health/live
```

**Expected**: Response time < 1 second (no 30+ second delay)
**Success**: UptimeRobot is keeping your site warm! 🎉

---

## Dashboard Features

### Monitor Details
Click on your monitor name to see:
- **Uptime percentage** (should be 99.9%+)
- **Response time graph** (average 200-600ms)
- **Up/down history** (green bars = good)
- **Alert log** (emails sent when down)

### Free Tier Limits (More Than Enough)
- ✅ **50 monitors** (you only need 1)
- ✅ **5-minute checks** (perfect for keeping site warm)
- ✅ **Unlimited alerts**
- ✅ **2-month logs**

---

## Important Notes

### ⚠️ Use /health/live Endpoint
- ✅ **Good**: `https://meme-explorer.onrender.com/health/live`
- ❌ **Bad**: `https://meme-explorer.onrender.com/` (inflates analytics)

**Why /health/live?**
- Lightweight (returns in <50ms)
- Doesn't count as a "view" in your metrics
- Specifically designed for health checks
- No database queries = faster response

### ⚠️ Don't Set Interval > 5 Minutes
- 10+ minutes = site might sleep between checks
- 5 minutes is the sweet spot (free tier allows it)
- More frequent (1-2 min) is overkill and wastes requests

---

## Troubleshooting

### "Monitor shows 'Down' status"
**Possible causes**:
1. Site is deploying (wait 2-3 minutes)
2. Render service crashed (check Render logs)
3. Render having outage (check https://status.render.com)

**Fix**: 
- Check Render dashboard for errors
- Look at deployment logs
- Usually resolves itself in 2-3 minutes

### "Response time > 10 seconds"
**Cause**: Cold start still happening

**Fix**:
1. Verify monitor interval is 5 minutes (not longer)
2. Check monitor is actually "active" (not paused)
3. Verify URL is correct: `/health/live` (not `/`)

### "Getting too many alert emails"
**Fix**:
1. Click on monitor name
2. Scroll to "Alert Contacts"
3. Adjust notification settings
4. Or set "Alert When Down For" to 2+ checks (reduces false alarms)

---

## Email Alerts You'll Receive

### When You First Set Up:
```
✅ UptimeRobot Monitor Created
   Meme Explorer Health Check is now being monitored
```

### If Site Goes Down:
```
❌ Monitor Down Alert
   Meme Explorer Health Check is DOWN
   Last checked: 2 minutes ago
   Response: Connection timeout
```

### When Site Comes Back Up:
```
✅ Monitor Up Again
   Meme Explorer Health Check is UP again
   Downtime duration: 5 minutes
```

**Pro tip**: These alerts are actually useful! They tell you immediately if Render has an issue.

---

## Advanced: Optional Enhancements

### Add Multiple Monitors (Free)
You can monitor different endpoints:
- Main site: `https://meme-explorer.onrender.com/`
- Health check: `https://meme-explorer.onrender.com/health/live`
- AdSense verification: `https://meme-explorer.onrender.com/adsense-verification`

### Set Up Status Page (Free)
UptimeRobot offers a **public status page**:
- Shows your uptime percentage
- Live status updates
- Shareable URL
- Good for transparency with users

To enable:
1. Go to "Status Pages" in dashboard
2. Click "Add Status Page"
3. Select your monitor
4. Get a public URL like: `https://stats.uptimerobot.com/ABC123`

---

## Success Checklist

After setup, verify:

- [ ] UptimeRobot account created and verified
- [ ] Monitor added with correct URL: `/health/live`
- [ ] Monitor interval set to **5 minutes**
- [ ] Monitor status shows **"Up"** ✅
- [ ] Email alerts enabled
- [ ] Waited 20+ minutes and tested - no cold start
- [ ] AdSense crawler will now always hit a warm site

---

## What's Next?

Once UptimeRobot is running:

1. ✅ **Your site stays warm 24/7** (no cold starts)
2. ✅ **AdSense crawler can verify site** (no "unavailable" errors)
3. ⏰ **Wait 24-48 hours** for Google to re-crawl
4. 📧 **Request AdSense review** (see DEPLOY_ADSENSE_FIX.md)
5. 🎉 **Get approved** (typically 1-3 days)

---

## Quick Reference

**Website**: https://uptimerobot.com  
**Monitor URL**: `https://meme-explorer.onrender.com/health/live`  
**Interval**: 5 minutes  
**Cost**: FREE forever  
**Support**: https://blog.uptimerobot.com/knowledge-base/

---

**Status**: Ready to set up NOW! 🚀  
**Time**: 5 minutes  
**Impact**: Fixes "site down" AdSense error

---

*Created: May 21, 2026*
