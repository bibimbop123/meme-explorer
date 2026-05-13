# Random Meme Duplicate Prevention Fix - May 2026

## Problem
Users were seeing the same memes repeatedly when refreshing or navigating the `/random` page because the route was simply doing `@meme = MEME_CACHE[:memes].sample` without any history tracking.

## Root Cause
The `/random` route (HTML page) was NOT tracking meme history in session, while the `/random.json` route (AJAX endpoint) WAS tracking history. This created an inconsistency where:
- Initial page load: No duplicate prevention ❌
- AJAX navigation (clicking "Next"): Duplicate prevention ✅

## Solution Implemented

### Changes to `routes/random_meme.rb`

Added session-based history tracking to the `/random` route to match the behavior of `/random.json`:

```ruby
# Initialize session history
session[:meme_history] ||= []

# Get meme pool
meme_pool = if app.class::MEME_CACHE[:memes].is_a?(Array) && !app.class::MEME_CACHE[:memes].empty?
  app.class::MEME_CACHE[:memes]
else
  random_memes_pool
end

# Find a meme that's different from recently shown ones
@meme = nil
attempts = 0
max_attempts = [meme_pool.size, 50].min

while attempts < max_attempts && @meme.nil?
  candidate = meme_pool.sample
  candidate_id = candidate["url"] || candidate["file"]
  
  # Check if not in recent history (last 50 memes)
  if candidate_id && !session[:meme_history].last(50).include?(candidate_id)
    @meme = candidate
  end
  attempts += 1
end

# If we couldn't find a fresh meme, just use a random one (pool exhausted)
@meme ||= meme_pool.sample
@meme ||= fallback_meme

# Track in session history
if @meme
  meme_identifier = @meme["url"] || @meme["file"]
  session[:meme_history] << meme_identifier if meme_identifier
  session[:meme_history] = session[:meme_history].last(100) # Keep last 100
end
```

## How It Works

1. **Session History**: Maintains `session[:meme_history]` array tracking the last 100 meme URLs shown to the user
2. **Smart Selection**: Attempts up to 50 times to find a meme NOT in the last 50 shown memes
3. **Graceful Degradation**: If pool is exhausted or all memes have been seen, falls back to random selection
4. **Memory Management**: Keeps only the last 100 memes in history to prevent session bloat

## Benefits

✅ **No More Immediate Duplicates**: Users won't see the same meme they just viewed  
✅ **50-Meme Buffer**: Tracks last 50 memes to ensure variety  
✅ **Consistent Behavior**: Both HTML and JSON endpoints now use the same logic  
✅ **Session-Based**: Works for all users (logged in or anonymous)  
✅ **Performance**: Fast lookup using Ruby array's `include?` method  

## Testing

To verify the fix:

1. Restart the server
2. Visit `/random` multiple times by refreshing
3. Click the "Next" button multiple times
4. Verify you don't see the same meme within 50 views

## Technical Details

- **Session Storage**: Uses Sinatra session (cookie-based or Redis-backed)
- **History Size**: 100 memes tracked, 50 checked for duplicates
- **Fallback**: If no fresh meme found after 50 attempts, shows random meme
- **Memory**: ~10KB per session for 100 URLs

## Code Location

File: `routes/random_meme.rb`  
Lines: 8-48 (GET `/random` route)

## Deployed
May 12, 2026

---

**Status**: ✅ FIXED - Duplicate memes should now be extremely rare (only after viewing 50+ memes)
