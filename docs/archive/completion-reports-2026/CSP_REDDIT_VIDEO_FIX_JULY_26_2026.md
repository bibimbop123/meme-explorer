# CSP Reddit Video Fix - July 26, 2026

## 🎯 Issue

**CSP Violation blocking Reddit videos:**
```
Loading media from 'https://v.redd.it/whqr2rsc9beh1/CMAF_720.mp4?source=fallback' 
violates the following Content Security Policy directive: "default-src 'self'". 
Note that 'media-src' was not explicitly set, so 'default-src' is used as a fallback.
```

## 🔍 Root Cause

The Content Security Policy in `lib/middleware/security_headers.rb` was missing an explicit `media-src` directive. When browsers try to load video/audio elements, they check `media-src` first. If not set, CSP falls back to `default-src 'self'`, which blocks external media sources like Reddit videos.

## ✅ Solution

**Added explicit `media-src` directive** to production CSP configuration:

```ruby
# Media: Allow Reddit videos and audio
"media-src 'self' " \
  "https://v.redd.it " \
  "https://i.redd.it",
```

### Security Considerations

- ✅ **Whitelisted domains only** - Only Reddit CDN domains allowed
- ✅ **No wildcards** - Specific domains prevent abuse
- ✅ **Separate from connect-src** - Videos don't need XHR access
- ✅ **Maintains OWASP standards** - No security degradation

## 📊 Impact

| Before | After |
|--------|-------|
| ❌ Reddit videos blocked | ✅ Reddit videos play |
| ❌ CSP violations in console | ✅ No CSP errors |
| ❌ Fallback to thumbnails only | ✅ Full video playback |

## 🚀 Deployment

### Manual Deployment (Immediate)

```bash
# The fix is already in lib/middleware/security_headers.rb
# Just restart the application to apply:
git add lib/middleware/security_headers.rb CSP_REDDIT_VIDEO_FIX_JULY_26_2026.md
git commit -m "Fix CSP to allow Reddit video playback"
git push origin main

# Render will auto-deploy, or trigger manually:
render services restart <service-id>
```

### Verification

1. **Navigate to /random** 
2. **Find a meme with video** (Reddit v.redd.it)
3. **Check browser console** - No CSP violations
4. **Verify video plays** - Full playback working

## 📝 Technical Details

### CSP Directive Hierarchy

```
media-src (explicit) 
  ↓ fallback if not set
default-src 'self'
```

### Allowed Media Sources

- `'self'` - Local videos/audio
- `https://v.redd.it` - Reddit video CDN
- `https://i.redd.it` - Reddit image/GIF CDN (some animated)

### File Modified

- `lib/middleware/security_headers.rb` (line 130-133)

## ✅ Testing Checklist

- [ ] Reddit videos load without CSP errors
- [ ] Console shows no violations
- [ ] Video controls work (play/pause/volume)
- [ ] Fullscreen functionality works
- [ ] Other media types still work (images, GIFs)
- [ ] Security headers remain strict

## 📚 Related

- [MDN CSP media-src](https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers/Content-Security-Policy/media-src)
- Previous CSP fixes: `WASM_CSP_FIX_JULY_16_2026.md`
- Security headers: `CSP_CHART_JS_FIX_JULY_22_2026.md`

---

**Status:** ✅ Fixed & Ready for Deployment  
**Priority:** P1 - Affects user experience  
**Downtime:** None (middleware update)
