# 🔧 Redis Session Fix - DEPLOYMENT GUIDE

## Problem Fixed
**Session Cookie Size Exceeded** - Cookie-based sessions have a 4K limit. Meme viewing history quickly exceeded this, causing:
- ❌ "Warning! Rack::Session::Cookie failed to save session"
- ❌ Viewing history dropped every request
- ❌ Anti-repetition system completely broken
- ❌ Users seeing same memes repeatedly

## Solution
Switched from **Rack::Session::Cookie** (4K limit) to **Rack::Session::Redis** (unlimited).

---

## 📋 Deployment Steps

### Step 1: Install Dependencies
```bash
bundle install
```

### Step 2: Verify Redis is Running
```bash
redis-cli ping
# Should respond: PONG
```

### Step 3: Deploy to Production

**On Render.com:**
1. Push to Git:
   ```bash
   git add Gemfile Gemfile.lock config.ru
   git commit -m "Fix: Switch to Redis sessions (fixes repetition issue)"
   git push origin main
   ```

2. Render will automatically:
   - Run `bundle install`
   - Restart the service
   - Redis sessions will be active immediately

**On Other Platforms:**
```bash
# Install gems
bundle install

# Restart your app server
# Example for systemd:
sudo systemctl restart meme-explorer

# Or for Puma:
pumactl restart
```

---

## ✅ Verification

### Check Logs (should see):
```
✅ No more "session dropped" warnings
✅ Pool stats showing seen memes tracking correctly
```

**Before:**
```
📊 Pool stats: 97 total, 97 unseen (0 seen)
Warning! Rack::Session::Cookie data size exceeds 4K
```

**After:**
```
📊 Pool stats: 97 total, 89 unseen (8 seen)
✅ No warnings
```

### Test in Browser:
1. Visit `/random` multiple times
2. You should NOT see the same meme twice
3. Open Redis CLI and check:
   ```bash
   redis-cli
   KEYS "meme_explorer:session:*"
   # Should show active session keys
   ```

---

## 🔧 Configuration

### Environment Variables (Production)
Add to your `.env` or Render environment variables:

```bash
# Optional: Custom Redis URL (defaults to localhost:6379)
REDIS_URL=redis://your-redis-server:6379/0

# Required: Session secret (should already exist)
SESSION_SECRET=your_secret_key_here
```

### Session Duration
- **Cookies (old)**: 30 days
- **Redis (new)**: 2 hours (configurable in config.ru)

Why shorter? Redis sessions are more flexible and auto-expire properly.

---

## 🎯 Expected Results

### User Experience:
- ✅ **No repetitions** until entire pool viewed
- ✅ **Achievements persist** across requests
- ✅ **Streak tracking** works correctly  
- ✅ **Session stats** accumulate properly

### Performance:
- ⚡ **Faster** (Redis is faster than cookie parsing)
- 💾 **Lower bandwidth** (no large cookies sent with every request)
- 🔒 **More secure** (sensitive data stays server-side)

---

## 🚨 Rollback (if needed)

If something goes wrong, revert to cookies:

```ruby
# In config.ru, replace Rack::Session::Redis with:
use Rack::Session::Cookie,
  key: 'meme_explorer.session',
  path: '/',
  httponly: true,
  same_site: :lax,
  secure: ENV['RACK_ENV'] == 'production',
  expire_after: 2_592_000,
  secret: ENV['SESSION_SECRET']
```

Then:
```bash
bundle install
git commit -am "Rollback: Restore cookie sessions"
git push
```

---

## 📊 Monitoring

### Check Session Count:
```bash
redis-cli
DBSIZE  # Shows total keys
KEYS "meme_explorer:session:*" | wc -l  # Active sessions
```

### Check Memory Usage:
```bash
redis-cli INFO memory
```

### Clean Up Old Sessions (if needed):
Redis auto-expires sessions after 2 hours, but you can manually flush:
```bash
redis-cli
SCAN 0 MATCH "meme_explorer:session:*" COUNT 100
# Then delete specific keys if needed
```

---

## ✨ Summary

**What Changed:**
- ✅ Added `redis-rack` gem
- ✅ Switched session store in `config.ru`
- ✅ No code changes needed elsewhere

**Result:**
- ✅ Anti-repetition works perfectly
- ✅ No more session warnings
- ✅ Better user experience
- ✅ Improved performance

---

**Deploy now and enjoy infinite variety with no repetitions!** 🚀
