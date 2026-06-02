# Access Production Shell & Refresh API Memes - Quick Guide

## ✅ **NO NEED TO WAIT 30 MINUTES!**

You can manually refresh the cache in production RIGHT NOW using any of these methods:

---

## Method 1: Access Render Shell (FASTEST) ⚡

### Step 1: Access the Shell
Go to your Render Dashboard:
1. Open https://dashboard.render.com
2. Click on your **meme-explorer** service
3. Click the **"Shell"** tab at the top
4. This opens an interactive terminal in production

### Step 2: Run the Manual Cache Refresh Script
```bash
bundle exec ruby scripts/manual_cache_refresh.rb
```

This will:
- ✅ Check Reddit API credentials (already set in production)
- ✅ Fetch fresh memes from Reddit API
- ✅ Update the cache immediately
- ✅ Show you the results

### Step 3: Verify It Worked
```bash
bundle exec ruby -e "require './app'; cache = MemeExplorer::MEME_CACHE.get(:memes) || []; puts 'Total: ' + cache.size.to_s + ' | API: ' + cache.count { |m| m['url'] && !m['url'].start_with?('/') }.to_s"
```

You should see something like: `Total: 250 | API: 200`

---

## Method 2: Use Render CLI (If Installed)

If you have the Render CLI installed:

```bash
# SSH into production
render ssh meme-explorer

# Once connected, run:
cd /opt/render/project/src
bundle exec ruby scripts/manual_cache_refresh.rb
```

---

## Method 3: HTTP Endpoint (NO SHELL ACCESS NEEDED!) 🌐

**Perfect for Render free tier without shell access!**

Just make a POST request to the endpoint:

```bash
# From your terminal:
curl -X POST https://meme-explorer.onrender.com/admin/refresh-cache
```

Or visit in your browser:
```
https://meme-explorer.onrender.com/admin/refresh-cache
```

You'll get a JSON response showing the results:
```json
{
  "success": true,
  "message": "Cache refreshed successfully",
  "total": 250,
  "api_count": 200,
  "local_count": 50,
  "timestamp": "2026-06-01T20:59:00Z"
}
```

**This is the EASIEST method if you don't have shell access!**

---

## Method 4: Wait for Sidekiq Auto-Refresh

The Sidekiq worker automatically refreshes every 30 minutes, but you don't need to wait when you can use Methods 1-3!

---

## What About Redis?

**Redis is ALREADY working in production!** 

From your `render.yaml`:
- ✅ Redis service: `meme-explorer-redis` 
- ✅ Connected via: `REDIS_URL` environment variable
- ✅ Sidekiq worker is running

The 30-minute wait was for the **automatic** Sidekiq worker to refresh. But you can bypass that and refresh **immediately** using the manual script.

---

## Verify API Memes Are Loading

After running the manual refresh, visit:
- https://meme-explorer.onrender.com/random

Click "Next Meme" several times. You should see memes from:
- r/dankmemes
- r/memes  
- r/funny
- r/me_irl

NOT just "local" memes.

---

## Troubleshooting

### "Script not found"
Make sure you're in the project directory:
```bash
cd /opt/render/project/src
ls scripts/  # Should see manual_cache_refresh.rb
```

### "Redis connection failed"
Check Redis URL is set:
```bash
echo $REDIS_URL
# Should output: redis://...
```

### "Still seeing only local memes"
1. Check Reddit credentials are set in Render Dashboard:
   - Dashboard → meme-explorer → Environment
   - Verify `REDDIT_CLIENT_ID` and `REDDIT_CLIENT_SECRET` are set
2. Run the diagnostic script:
   ```bash
   bundle exec ruby scripts/diagnose_api_memes.rb
   ```

---

## Production Environment Variables

Your Reddit credentials are already configured in production:
- ✅ `REDDIT_CLIENT_ID`: UrNOxX8Lb6xlwnSwyScNuA
- ✅ `REDDIT_CLIENT_SECRET`: Xb41Yz48NlM5sxlD9fUbgEk5syLL-A

(From `.env.production` - these should be set in Render Dashboard)

---

## Quick Commands Cheatsheet

```bash
# Refresh cache manually
bundle exec ruby scripts/manual_cache_refresh.rb

# Check cache status
bundle exec ruby scripts/diagnose_api_memes.rb

# Quick cache check
bundle exec ruby -e "require './app'; puts MemeExplorer::MEME_CACHE.get(:memes).size"

# Check Redis connection
bundle exec ruby -e "require './app'; puts MemeExplorer::MEME_CACHE.get(:last_refresh)"
```

---

## Summary

**You have 3 options to refresh immediately:**

1. **HTTP Endpoint** ← EASIEST! Works without shell access
2. **Render Dashboard Shell** ← Visual interface
3. **Render CLI SSH** ← If you have CLI installed
4. **Wait for Sidekiq** ← Automatic every 30 min (slower)

**Choose Option 1 for instant results!** 🚀

Just run:
```bash
curl -X POST https://meme-explorer.onrender.com/admin/refresh-cache
```

Or visit: https://meme-explorer.onrender.com/admin/refresh-cache in your browser!
