# Chart.js CDN CSP Fix - July 22, 2026

## Issue
Chart.js from `cdn.jsdelivr.net` is being blocked by Content Security Policy:
```
Connecting to 'https://cdn.jsdelivr.net/npm/chart.js@4.4.0/dist/chart.umd.min.js' violates the following Content Security Policy directive: "connect-src 'self' https://www.reddit.com https://oauth.reddit.com..."
```

## Root Cause
The CSP configuration in `lib/middleware/security_headers.rb` already includes `cdn.jsdelivr.net` in both:
- `script-src` (line 92) - allows loading the script
- `connect-src` (line 122) - allows service worker to fetch it

**The server just needs to be restarted to pick up these changes.**

## Solution

### Option 1: Server Restart (Immediate Fix)
If running locally:
```bash
# Stop the server (Ctrl+C)
# Then restart:
bundle exec puma -C config/puma.rb
```

If on Render:
```bash
# Trigger a restart via the Render dashboard
# OR force a redeploy
git commit --allow-empty -m "Force redeploy to apply CSP changes"
git push origin main
```

### Option 2: Verify CSP is Applied
After restart, verify the CSP header includes cdn.jsdelivr.net:
```bash
curl -I https://your-domain.com | grep -i content-security
```

## Files Verified
- ✅ `lib/middleware/security_headers.rb` - Already includes cdn.jsdelivr.net
- ✅ `views/metrics.erb` - Loads Chart.js from cdn.jsdelivr.net
- ✅ `public/service-worker.js` - Intercepts fetch requests

## Current CSP Configuration (Already Correct)

```ruby
# Script sources - line 88-92
"script-src 'self' 'unsafe-inline' 'wasm-unsafe-eval' " \
  "https://pagead2.googlesyndication.com " \
  "https://www.googletagmanager.com " \
  "https://www.google-analytics.com " \
  "https://cdn.jsdelivr.net",

# Connection sources - line 109-122  
"connect-src 'self' " \
  "https://www.reddit.com " \
  "https://oauth.reddit.com " \
  "https://www.google-analytics.com " \
  "https://i.redd.it " \
  "https://v.redd.it " \
  "https://preview.redd.it " \
  "https://external-preview.redd.it " \
  "https://i.imgur.com " \
  "https://imgur.com " \
  "https://fonts.googleapis.com " \
  "https://fonts.gstatic.com " \
  "https://pagead2.googlesyndication.com " \
  "https://cdn.jsdelivr.net",
```

## Why This Happens
1. Service worker intercepts fetch requests for Chart.js
2. CSP is enforced on service worker fetch operations
3. Without `cdn.jsdelivr.net` in `connect-src`, the fetch is blocked
4. The CSP middleware needs to be loaded into the running server

## Status
✅ **Code is already fixed** - just needs server restart
- CSP configuration is correct
- All necessary directives are in place
- No code changes needed

## Testing After Restart
1. Open browser console
2. Navigate to /metrics page  
3. Should see: "✅ Service Worker registered"
4. Should NOT see: "Failed to fetch" for Chart.js
5. Charts should render properly

## Related Files
- `lib/middleware/security_headers.rb` - CSP configuration
- `views/metrics.erb` - Uses Chart.js
- `public/service-worker.js` - Intercepts fetches
- `app.rb` - Loads SecurityHeaders middleware

## Prevention
This wouldn't be an issue if:
- Server was restarted after the CSP update (line 122 was added July 20, 2026)
- Hot-reloading applied to middleware changes (doesn't by default in Sinatra)

## Next Steps
**Simply restart your development server or redeploy to production.**
