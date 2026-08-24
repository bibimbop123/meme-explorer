# Reddit OAuth Configuration Fix

## ❌ Current Error

```
bad request (reddit.com)
you sent an invalid request
— invalid redirect_uri parameter.
```

## 🎯 Root Cause

The `redirect_uri` in your production environment **doesn't match** what's configured in your Reddit app settings. Reddit requires **exact matching** including protocol (https vs http) and trailing slashes.

---

## ✅ How to Fix

### Step 1: Check Current Configuration

Your app is using: `settings.reddit_redirect_uri`

**Check what this is set to:**

```bash
# On Render, check environment variable:
# Go to Render Dashboard → Your Service → Environment → REDDIT_REDIRECT_URI
```

It should be:
```
https://meme-explorer.onrender.com/auth/reddit/callback
```

### Step 2: Update Reddit App Settings

1. **Go to Reddit:**
   - Navigate to: https://www.reddit.com/prefs/apps
   - Find your app (client ID: `UrNOxX8Lb6xlwnSwyScNuA`)

2. **Click "edit" on your app**

3. **Update the redirect URI:**
   
   Add this **exact URL**:
   ```
   https://meme-explorer.onrender.com/auth/reddit/callback
   ```

   ⚠️ **Important:**
   - Must be `https://` (not `http://`)
   - No trailing slash after `/callback`
   - Exact domain match: `meme-explorer.onrender.com`

4. **Save changes**

### Step 3: Verify Environment Variables

Ensure these are set in your Render environment:

```bash
REDDIT_OAUTH_CLIENT_ID=UrNOxX8Lb6xlwnSwyScNuA
REDDIT_OAUTH_CLIENT_SECRET=<your_secret>
REDDIT_REDIRECT_URI=https://meme-explorer.onrender.com/auth/reddit/callback
```

---

## 🔍 Common Mistakes

| ❌ Wrong | ✅ Correct |
|----------|-----------|
| `http://` (not secure) | `https://` |
| `localhost:3000` (dev URL) | `meme-explorer.onrender.com` |
| Trailing slash `/callback/` | No trailing slash `/callback` |
| `www.meme-explorer.onrender.com` | `meme-explorer.onrender.com` |

---

## 🧪 Testing After Fix

1. **Restart your Render service** (if you changed environment variables)

2. **Test the OAuth flow:**
   ```
   Visit: https://meme-explorer.onrender.com/auth/reddit
   ↓
   Redirected to Reddit authorization
   ↓
   Click "Allow"
   ↓
   Redirected back to: /auth/reddit/callback
   ↓
   User created/logged in
   ↓
   Redirected to: /profile
   ```

3. **Verify successful login:**
   - Check you're logged in
   - Check profile page shows Reddit username
   - Check session persists after refresh

---

## 📊 What Happens After Fix

Once the redirect URI matches:

1. ✅ Reddit accepts the OAuth request
2. ✅ User authorizes on Reddit
3. ✅ Reddit redirects back with authorization code
4. ✅ Your app exchanges code for access token
5. ✅ **Fixed `UserService.create_or_find_from_reddit()` returns user ID**
6. ✅ `session[:user_id]` is set correctly
7. ✅ User is logged in and can use all features

---

## 🔒 Security Notes

- **Never commit** `REDDIT_OAUTH_CLIENT_SECRET` to git
- Only add **production URLs** to Reddit app settings
- For local testing, add `http://localhost:3000/auth/reddit/callback`
- Keep separate Reddit apps for dev/staging/production

---

## 📝 Environment Variable Checklist

```bash
# Required in production (.env.production or Render environment)
REDDIT_OAUTH_CLIENT_ID=UrNOxX8Lb6xlwnSwyScNuA
REDDIT_OAUTH_CLIENT_SECRET=<get_from_reddit_app_settings>
REDDIT_REDIRECT_URI=https://meme-explorer.onrender.com/auth/reddit/callback
```

---

## 🎯 Quick Fix Summary

1. Go to https://www.reddit.com/prefs/apps
2. Edit your app
3. Set redirect URI to: `https://meme-explorer.onrender.com/auth/reddit/callback`
4. Save
5. Restart Render service (if env vars changed)
6. Test login

**That's it!** Reddit login will work after this configuration update.

---

## ✅ Code Fixes Already Applied

The authentication code bugs have been fixed:
- ✅ `UserService.create_or_find_from_reddit()` now returns user ID
- ✅ `UserService.create_email_user()` now returns user ID
- ✅ SearchService namespace resolved

Once you fix the redirect URI configuration, **everything will work!**

---

**Status:** Configuration issue - no code changes needed
**Next Step:** Update Reddit app redirect URI setting
**Expected Result:** Reddit OAuth login fully functional
