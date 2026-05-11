# Trending Navigation Debug Guide

## The Problem
Clicking a trending meme still shows a random meme instead of the clicked meme.

## CRITICAL: Did you restart the server?
**The changes won't work until you restart!**

```bash
# Stop the current server (Ctrl+C)
# Then start it again:
bundle exec ruby app.rb
```

## How to Debug

### Step 1: Check Browser Console
1. Open trending page: http://localhost:4567/trending
2. Open browser DevTools (F12)
3. Go to Console tab
4. Click on a meme
5. **Look for the URL it's navigating to**

**You should see navigation to:** `/random?url=https%3A%2F%2F...`

**If you see just:** `/random` (no `?url=` part)
- ❌ **PROBLEM:** JavaScript not working
- **FIX:** Hard refresh page (Ctrl+Shift+R or Cmd+Shift+R)

### Step 2: Check Server Console  
After clicking a meme, your server terminal should show:

```
🔍 [RANDOM] Looking for specific meme: https://...
✅ [RANDOM] Found meme in cache: Some Meme Title
✅ [RANDOM] Final meme being displayed:
   Title: Some Meme Title
   URL: https://...
   Image src: https://...
```

**If you DON'T see these messages:**
- ❌ Server not restarted with new code
- **FIX:** Restart server (see above)

**If you see these messages but wrong meme displays:**
- ❌ Meme found but display issue
- **SHARE:** The console output with me

### Step 3: Network Tab Check
1. Open DevTools → Network tab
2. Click a trending meme
3. Look for the request to `/random?url=...`
4. Click on it and check the "Preview" or "Response" tab

**You should see:** The HTML for the meme page

## Common Issues

### Issue 1: No URL parameter in navigation
**Symptom:** Browser goes to `/random` without `?url=`
**Cause:** JavaScript file not loaded or cached
**Fix:** 
```bash
# Hard refresh browser
Ctrl+Shift+R (Windows/Linux)
Cmd+Shift+R (Mac)
```

### Issue 2: Server shows no debug messages
**Symptom:** No 🔍 or ✅ messages in terminal
**Cause:** Server not restarted
**Fix:** 
```bash
# Kill server (Ctrl+C) and restart
bundle exec ruby app.rb
```

### Issue 3: Meme found but wrong one displays
**Symptom:** Logs show correct meme found, but page shows different meme
**Cause:** Cache mismatch or view rendering issue
**Fix:** Check if `@meme` variable is being overwritten somewhere

## Quick Test

Run this in your browser console on the trending page:

```javascript
// Test if trending.js is loaded
console.log(typeof TrendingPage);  // Should show "function"

// Test if click handler is working
document.querySelector('.meme-card')?.click();
// Should navigate to /random?url=...
```

## What to Share With Me

If it's still not working after restart, please share:

1. **Browser console output** when you click a meme
2. **Server terminal output** when you click a meme  
3. **The URL in browser address bar** after clicking

This will help me identify the exact issue!

## Expected Behavior

✅ **Correct flow:**
1. Click meme on trending page
2. Browser navigates to: `/random?url=https%3A%2F%2Fi.redd.it%2F...`
3. Server logs show: 🔍 Looking for meme...
4. Server logs show: ✅ Found meme in cache
5. Page displays THAT SPECIFIC meme

❌ **Wrong flow:**
1. Click meme on trending page
2. Browser navigates to: `/random` (no URL)
3. Server shows no 🔍 messages
4. Random meme is selected and displayed
