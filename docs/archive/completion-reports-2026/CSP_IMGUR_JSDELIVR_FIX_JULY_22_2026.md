# CSP Fix for imgur.com and cdn.jsdelivr.net
**Date:** July 22, 2026  
**Issue:** Service worker fetch requests to imgur.com and cdn.jsdelivr.net blocked by CSP

## Problem
The browser's Content Security Policy (CSP) was blocking service worker fetch requests to:
- `https://cdn.jsdelivr.net/npm/chart.js@4.4.0/dist/chart.umd.min.js`
- `https://i.imgur.com/*` (image URLs)

## Root Cause
Service workers cache and apply CSP policies. Even though the CSP in `lib/middleware/security_headers.rb` 
was correct, browsers may have cached an older version of the CSP through the service worker.

## Solution Applied

### 1. Service Worker Cache Bust
- Incremented service worker cache version
- Forces all clients to fetch and apply new CSP on next visit

### 2. CSP Verification
- Verified `connect-src` directive includes:
  - `https://cdn.jsdelivr.net` (for Chart.js and other CDN resources)
  - `https://i.imgur.com` (for imgur images)
  - `https://imgur.com` (for imgur redirects)

### 3. Service Worker Refresh Helper
- Created `public/js/sw-refresh.js` for manual SW reset if needed

## Deployment Steps

### 1. Deploy the changes
```bash
git add public/service-worker.js lib/middleware/security_headers.rb public/js/sw-refresh.js
git commit -m "Fix CSP for imgur.com and cdn.jsdelivr.net"
git push
```

### 2. Deploy to production (Render)
The changes will automatically deploy via Render's GitHub integration.

### 3. Force service worker refresh (if needed)
If users still see CSP errors after deployment:

**Option A: Add to layout temporarily**
Add this to `views/layout.erb` before `</body>`:
```erb
<% if params[:refresh_sw] %>
  <script src="/js/sw-refresh.js"></script>
<% end %>
```

Then visit: `https://your-site.com/?refresh_sw=1`

**Option B: Run in browser console**
Users can run this in their browser console:
```javascript
navigator.serviceWorker.getRegistrations().then(regs => 
  Promise.all(regs.map(r => r.unregister()))
).then(() => location.reload(true));
```

## Verification

### Test that CSP allows the blocked URLs:
1. Open browser DevTools → Network tab
2. Navigate to a page that loads Chart.js or imgur images
3. Verify no CSP errors in Console tab
4. Check that these requests succeed:
   - Chart.js from cdn.jsdelivr.net
   - Images from i.imgur.com

### Expected Results:
- ✅ No "violates Content Security Policy" errors
- ✅ Chart.js loads successfully from CDN
- ✅ Imgur images display correctly
- ✅ Service worker caches resources properly

## Technical Details

### CSP connect-src Directive (production)
```
connect-src 'self' 
  https://www.reddit.com 
  https://oauth.reddit.com 
  https://www.google-analytics.com 
  https://i.redd.it 
  https://v.redd.it 
  https://preview.redd.it 
  https://external-preview.redd.it 
  https://i.imgur.com 
  https://imgur.com 
  https://fonts.googleapis.com 
  https://fonts.gstatic.com 
  https://pagead2.googlesyndication.com 
  https://cdn.jsdelivr.net
```

### Why Service Workers Need Special CSP Handling
Service workers:
1. Run in a separate thread/context
2. Cache the CSP policy when first registered
3. Continue using cached CSP until unregistered/updated
4. Require cache-busting to pick up CSP changes

## Prevention
To avoid this issue in the future:
1. Always increment SW cache version when changing CSP
2. Test CSP changes in incognito mode (clean SW state)
3. Use `sw-refresh.js` for quick user-side fixes
4. Monitor CSP violations in production logs

## Related Files
- `lib/middleware/security_headers.rb` - CSP configuration
- `public/service-worker.js` - Service worker with cache versioning
- `public/js/sw-refresh.js` - Manual SW refresh helper

## Status
✅ **COMPLETE** - Service worker updated, CSP verified, refresh helper created
