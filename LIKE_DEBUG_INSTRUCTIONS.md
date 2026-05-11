# Like Button Debug Instructions

## The counter isn't incrementing. Let's diagnose:

### Step 1: Check Browser Console
1. Open browser DevTools (F12 or Cmd+Option+I on Mac)
2. Go to Console tab
3. Click the like button
4. Look for errors or messages

**What to look for:**
- ❌ Red error messages (JavaScript errors)
- `❤️ [LIKE] Updated: liked=true, count=X` (success message)
- Network errors (fetch failed)

### Step 2: Check Network Tab
1. Open DevTools → Network tab
2. Click the like button
3. Look for POST request to `/like`

**Expected:**
- POST http://localhost:4567/like
- Status: 200 OK
- Response: `{"liked":true,"likes":1}`

**If you don't see the POST request:**
- The JavaScript isn't working
- Check Console for errors

### Step 3: Check Server Logs
```bash
tail -f /tmp/meme_server.log
```

Click the like button and watch for:
- `✅ [LIKE] Incremented likes for: [URL]`
- `❌ Like toggle error: ...`

### Step 4: Manual Test
Test the endpoint directly with curl:
```bash
curl -X POST http://localhost:4567/like \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "url=https://test.jpg" \
  -c cookies.txt \
  -b cookies.txt
```

**Expected response:**
```json
{"liked":true,"likes":1}
```

### Common Issues:

#### Issue 1: JavaScript Not Loaded
- **Symptom**: No POST request in Network tab
- **Solution**: Hard refresh (Cmd+Shift+R or Ctrl+Shift+R)

#### Issue 2: CORS/Session Issues  
- **Symptom**: POST returns 400 or 500
- **Solution**: Check if cookies are enabled

#### Issue 3: Database Error
- **Symptom**: Server logs show SQL errors
- **Solution**: Check database connection

### Quick Fix: Clear Everything
```bash
# Kill and restart server
lsof -ti:4567 | xargs kill -9
cd /Users/brian/DiscoveryPartnersInstitute/meme-explorer
bundle exec ruby app.rb

# Clear browser cache
- Open DevTools → Application → Storage → Clear site data
- Hard refresh page (Cmd+Shift+R)
```

## Report Back
Please tell me what you see in:
1. **Browser Console** (any errors?)
2. **Network Tab** (is POST /like being sent?)
3. **Response** (what does the server return?)
