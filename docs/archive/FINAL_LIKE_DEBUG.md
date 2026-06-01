# Final Like Debugging Guide

## The Code is Correct - Let's Debug Runtime

All code changes are correct:
- ✅ Route is registered  
- ✅ MemeService.toggle_like logic is sound
- ✅ Frontend JavaScript is correct
- ✅ No syntax errors

## Debug Steps

### 1. Check Server Logs (Most Important!)
When you click the like button, your server terminal should show:
```
✅ [LIKE] Incremented likes for: <url>
```

**If you see this message but counter stays 0**: Database issue  
**If you DON'T see this message**: Route not being called

### 2. Open Browser Console (F12 → Console)
Click the like button and check for:
```javascript
// Should see:
❤️ [LIKE] Updated: liked=true, count=1

// Should NOT see:
POST http://localhost:4567/like 404 (Not Found)
```

### 3. Check Network Tab (F12 → Network)
1. Open Network tab
2. Click like button
3. Find POST /like request
4. Check:
   - **Status**: Should be 200 (not 404)
   - **Response**: Should be `{"liked":true,"likes":1}`
   - **Request Payload**: Should have `url=...`

### 4. Database Check
```bash
# Check if meme_stats table exists and has data
sqlite3 memes.db "SELECT * FROM meme_stats LIMIT 5;"

# Check a specific meme's likes
sqlite3 memes.db "SELECT url, likes FROM meme_stats WHERE url LIKE '%test%';"
```

### 5. Verify Server Restart
```bash
# Make SURE old server is killed
lsof -ti:4567 | xargs kill -9

# Verify port is free
lsof -i:4567
# Should show nothing

# Start fresh
bundle exec ruby app.rb
```

## Common Issues

### Issue: Counter shows 0 but button changes color
**Cause**: Frontend updating UI but server returning 0  
**Fix**: Database issue - check meme_stats table exists

### Issue: Button doesn't respond at all
**Cause**: JavaScript error or route not loading  
**Fix**: Hard refresh (Cmd+Shift+R), check console for errors

### Issue: 404 errors in console
**Cause**: Route not registered or server not restarted  
**Fix**: Verify app.rb has both require and register lines

## Nuclear Option - Complete Reset

```bash
# 1. Kill everything
lsof -ti:4567 | xargs kill -9
pkill -f "ruby app.rb"

# 2. Verify changes in app.rb
grep -n "require_relative './routes/memes'" app.rb
grep -n "register Routes::Memes" app.rb

# 3. Check database
sqlite3 memes.db ".tables"  # Should show meme_stats

# 4. Start server with debug output
bundle exec ruby app.rb 2>&1 | tee server.log

# 5. Test in NEW browser window (or incognito)
open -na "Google Chrome" --args --incognito http://localhost:4567/random

# 6. Click like, then check server.log for messages
```

## What to Report Back

If still not working, please provide:
1. **Server log** output when clicking like
2. **Browser console** messages when clicking like  
3. **Network tab** response for POST /like
4. Output of: `sqlite3 memes.db "SELECT COUNT(*) FROM meme_stats;"`

This will help identify if it's:
- Route issue (404)
- Database issue (can't write)
- Response issue (returns wrong data)
- Frontend issue (doesn't update UI)
