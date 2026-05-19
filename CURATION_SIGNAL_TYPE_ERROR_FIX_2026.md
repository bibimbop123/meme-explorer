# Curation Signal TypeError Fix - May 19, 2026

## Problem

Production error occurring on `/random` page:

```
2026-05-19 21:37:36 - TypeError - no implicit conversion of Symbol into Integer:
    return false unless user[:favorite_subreddits]
                             ^^^^^^^^^^^^^^^^^^^^
/opt/render/project/src/lib/services/curation_signals_service.rb:210:in `[]'
```

## Root Cause

The `generate_curation_signal` method in `app.rb` was passing `session[:user_id]` (an integer) to `refined_curation_signal`, which eventually calls `CurationSignalsService.generate(meme, user)`.

The service expected `user` to be a Hash/object with keys like `:favorite_subreddits`, but was receiving an integer (user ID). When Ruby tried to execute `user[:favorite_subreddits]`, it interpreted it as array indexing on an integer, causing the TypeError.

### Call Chain
1. `views/random.erb` → calls `generate_curation_signal(meme)`
2. `app.rb#generate_curation_signal` → calls `refined_curation_signal(meme, session[:user_id])`
3. `refined_meme_helper.rb#refined_curation_signal` → calls `CurationSignalsService.generate(meme, user)`
4. `curation_signals_service.rb` → tries to access `user[:favorite_subreddits]` ❌

## Solution

Changed `app.rb` line ~621 to pass `nil` instead of `session[:user_id]`:

```ruby
# BEFORE (BROKEN)
def generate_curation_signal(meme)
  signal = refined_curation_signal(meme, session[:user_id])
  # ...
end

# AFTER (FIXED)
def generate_curation_signal(meme)
  # Pass nil for user since we don't have user hash/object loaded
  # The service handles nil gracefully and will skip personalized signals
  signal = refined_curation_signal(meme, nil)
  # ...
end
```

## Why This Works

The `CurationSignalsService` already handles `nil` user gracefully:

```ruby
# From curation_signals_service.rb line 65
signals.concat(taste_signals(meme, user)) if user

# From line 158-160
def self.taste_signals(meme, user)
  signals = []
  return signals unless user && meme  # Returns empty array if user is nil
  # ...
end
```

When `user` is `nil`:
- No personalized taste signals are generated
- Only non-personalized signals (quality, rarity, vintage, cultural) are shown
- No errors occur

## Alternative Solution (For Future Enhancement)

If personalized signals are needed in the future, you would need to:

1. **Create a `current_user` helper** that loads the full user hash:
```ruby
def current_user
  return nil unless session[:user_id]
  @current_user ||= UserService.get_full_profile(session[:user_id])
end
```

2. **Update the call** to use the full user object:
```ruby
def generate_curation_signal(meme)
  signal = refined_curation_signal(meme, current_user)
  # ...
end
```

3. **Ensure UserService returns proper hash** with keys like:
   - `:favorite_subreddits`
   - `:preferred_categories`
   - Recent activity data

## Testing

To verify the fix:

1. Visit `/random` page (should load without errors)
2. Check that curation signals still display (non-personalized ones)
3. No TypeError in logs

## Files Modified

- `app.rb` (line ~621) - Changed `session[:user_id]` to `nil`

## Impact

- ✅ Fixes production TypeError
- ✅ Page loads successfully
- ⚠️ Personalized curation signals temporarily disabled (were never working anyway due to the bug)
- ✅ All other curation signals (quality, rarity, vintage, cultural) still work

## Future Considerations

If you want to re-enable personalized signals:
1. Implement the "Alternative Solution" above
2. Ensure `UserService` or similar loads full user profile with preferences
3. Test that the user object has the expected structure

## Deployment

This is a hot-fix that should be deployed immediately as it fixes a production error. No database changes required.

```bash
git add app.rb CURATION_SIGNAL_TYPE_ERROR_FIX_2026.md
git commit -m "Fix: TypeError in curation_signals_service - pass nil instead of user_id"
git push origin main
```

---

**Fixed by:** AI Assistant  
**Date:** May 19, 2026  
**Severity:** P1 (Production Error)  
**Status:** ✅ Resolved
