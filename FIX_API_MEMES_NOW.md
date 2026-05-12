# Fix API Memes Not Loading - Diagnostic & Solution

## Quick Fix (3 Steps)

### Step 1: Run the Diagnostic Script
```bash
cd /Users/brian/DiscoveryPartnersInstitute/meme-explorer
bundle exec ruby scripts/manual_cache_refresh.rb
```

This script will:
1. Check if Reddit API credentials are configured
2. Attempt to fetch memes from Reddit API
3. Update the cache with API memes
4. Show you exactly what's wrong (if anything)

### Step 2: Fix Based on Output

#### If you see "Reddit API credentials not set":
1. Create/edit your `.env` file:
```bash
# Get credentials from https://www.reddit.com/prefs/apps
REDDIT_CLIENT_ID=your_client_id_here
REDDIT_CLIENT_SECRET=your_client_secret_here
```

2. To get credentials:
   - Go to https://www.reddit.com/prefs/apps
   - Click "create another app..." at the bottom
   - Name: "Meme Explorer"
   - Type: Select "script"
   - Redirect URI: http://localhost:8080/auth/reddit/callback
   - Click "create app"
   - Copy the **client ID** (under app name) and **secret**

#### If you see "Fetched 0 memes from Reddit API":
- Reddit may be rate-limiting you
- Try again in 5-10 minutes
- The script will use local memes as fallback

#### If you see "✅ SUCCESS: Cache contains API memes!":
- Great! The cache is working
- Just restart your server

### Step 3: Restart Your Server
```bash
# Stop current server (Ctrl+C)
# Then restart:
bundle exec puma
```

---

## What Was Wrong?

The issue was **two-fold**:

1. **Validation Too Strict** ✅ FIXED in `app.rb`
   - The `has_valid_media?` method rejected many valid Reddit URLs
   - Now accepts all HTTP/HTTPS URLs (except Reddit post links)

2. **Cache Not Refreshing** 🔧 NEEDS DIAGNOSIS
   - Sidekiq worker may not be running
   - OR Reddit API credentials not configured
   - OR Reddit rate limiting
   - Run the diagnostic script to find out

---

## Permanent Solution: Enable Sidekiq

For automatic cache refresh every 30 minutes:

### Option A: Development (Simple)
```bash
# In a separate terminal:
bundle exec sidekiq
```

### Option B: Production (Recommended)
Already configured in `Procfile` and `render.yaml` - Sidekiq runs automatically on deployment.

---

## Verification

After running the script and restarting:

1. Visit http://localhost:8080/random
2. Click "Next Meme" several times
3. Check subreddit names - you should see:
   - dankmemes
   - me_irl
   - memes
   - funny
   - etc.

NOT just "local" memes.

---

## Troubleshooting

### "Script errors out"
```bash
# Make sure you have the oauth2 gem:
bundle install
```

### "Still seeing only local memes"
1. Check `.env` file has Reddit credentials
2. Restart server completely (stop and start again)
3. Run diagnostic script again to verify cache
4. Check server logs for errors

### "Rate limited by Reddit"
- Wait 10-15 minutes
- Reddit API has rate limits
- Happens if you run the script too many times
- Fallback to local memes until rate limit resets

---

## Quick Status Check

Run this to see current cache status:
```bash
bundle exec ruby -r./app -e "cache = MemeExplorer::MEME_CACHE.get(:memes) || []; puts \"Total: #{cache.size} | API: #{cache.count { |m| m['url'] && !m['url'].start_with?('/') }} | Local: #{cache.count { |m| m['file'] || (m['url'] && m['url'].start_with?('/')) }}\""
```

**Expected:** API count should be > 0 (ideally 200+)

---

## Files Modified
- ✅ `app.rb` - Fixed `has_valid_media?` validation (line 1353)
- ✅ `scripts/manual_cache_refresh.rb` - New diagnostic script
- ⏳ `.env` - May need Reddit credentials added

---

**Need Help?** Share the output of the diagnostic script!
