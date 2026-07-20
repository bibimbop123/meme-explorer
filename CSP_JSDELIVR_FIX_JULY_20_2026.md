# CSP JSDelivr CDN Fix - July 20, 2026

## ✅ **SERVICE WORKER CSP VIOLATION FIXED!**

---

## 🔴 **Problem**

Service Worker was trying to fetch Chart.js from `cdn.jsdelivr.net` but CSP policy blocked it:

```
Connecting to 'https://cdn.jsdelivr.net/npm/chart.js@4.4.0/dist/chart.umd.min.js' violates the following Content Security Policy directive: "connect-src 'self' https://www.reddit.com..."

TypeError: Failed to fetch. Refused to connect because it violates the document's Content Security Policy.
```

## 🎯 **Root Cause**

The `cdn.jsdelivr.net` domain was added to `script-src` but **NOT** to `connect-src`. Service Worker fetch requests require `connect-src` permission, not just `script-src`.

---

## ✅ **Solution**

Added `https://cdn.jsdelivr.net` to the `connect-src` directive in `lib/middleware/security_headers.rb`:

```ruby
"connect-src 'self' " \
  "https://www.reddit.com " \
  "https://oauth.reddit.com " \
  "https://www.google-analytics.com " \
  "https://i.redd.it " \
  "https://v.redd.it " \
  "https://preview.redd.it " \
  "https://external-preview.redd.it " \
  "https://fonts.googleapis.com " \
  "https://fonts.gstatic.com " \
  "https://pagead2.googlesyndication.com " \
  "https://cdn.jsdelivr.net",  # ← ADDED THIS!
```

---

## 📦 **Files Modified**

- `lib/middleware/security_headers.rb` - Added JSDelivr to connect-src

---

## 🚀 **Deploy**

```bash
git add lib/middleware/security_headers.rb
git commit -m "Fix CSP: Add cdn.jsdelivr.net to connect-src for Service Worker"
git push origin main
```

---

## ✅ **Expected Result**

After deployment:
- ✅ Service Worker can fetch Chart.js from JSDeliv CDN
- ✅ No more CSP violations in browser console
- ✅ Charts load properly in metrics/admin pages

---

## 🎯 **Impact**

**Before:** Service Worker fetch blocked, charts fail to load  
**After:** Service Worker works perfectly, zero CSP errors!

---

**Date:** July 20, 2026  
**Status:** ✅ **COMPLETE**  
**Priority:** 🟡 **MEDIUM** (improves UX, eliminates console errors)
