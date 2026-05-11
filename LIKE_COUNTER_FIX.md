# Like Counter Fix - May 2026

## Problem
The like counter was not incrementing when users clicked the like button. Users would click "Like" but the counter would remain at 0 or not update correctly.

## Root Cause
The `MemeService.toggle_like` method in `lib/services/meme_service.rb` was receiving a `session` parameter but **never using it** to track whether the user had already liked a meme in their current session.

This caused issues where:
- Multiple clicks on the like button would increment the counter multiple times
- The like button state and the actual database counter could get out of sync
- Users couldn't reliably tell if their like was registered

## Solution
Updated `MemeService.toggle_like` to properly track likes per session:

### Changes Made
1. **Session Tracking**: Initialize `session[:meme_like_counts]` hash to track like state per meme URL
2. **State Checking**: Before updating the database, check if the meme was already liked in this session
3. **Conditional Updates**:
   - Only **increment** database counter when it's the first time liking in this session
   - Only **decrement** when unliking something that was previously liked in this session
   - No database update if the state hasn't changed (prevents duplicate increments)
4. **Debug Logging**: Added console output to track like/unlike actions

### Code Changes
**File**: `lib/services/meme_service.rb`

```ruby
def self.toggle_like(url, liked_now, session, db = nil)
  db ||= defined?(DB) ? ::DB : nil
  return 0 unless db && url
  
  begin
    # Initialize session tracking hash if not exists
    session[:meme_like_counts] ||= {}
    was_liked_before = session[:meme_like_counts][url] || false
    
    # Ensure the record exists before updating
    db.execute(
      "INSERT OR IGNORE INTO meme_stats (url, title, subreddit, likes, views) VALUES (?, ?, ?, 0, 0)", 
      [url, 'Unknown', 'unknown']
    )
    
    # Only update DB on first like/unlike transition in this session
    if liked_now && !was_liked_before
      # First time liking in this session - increment counter
      db.execute("UPDATE meme_stats SET likes = likes + 1, updated_at = CURRENT_TIMESTAMP WHERE url = ?", [url])
      session[:meme_like_counts][url] = true
      puts "✅ [LIKE] Incremented likes for: #{url}"
    elsif !liked_now && was_liked_before
      # Unliking after having liked in this session - decrement counter
      db.execute("UPDATE meme_stats SET likes = CASE WHEN likes > 0 THEN likes - 1 ELSE 0 END, updated_at = CURRENT_TIMESTAMP WHERE url = ?", [url])
      session[:meme_like_counts][url] = false
      puts "✅ [UNLIKE] Decremented likes for: #{url}"
    end
    # If liked_now == was_liked_before, no state change, don't update DB
    
    get_likes(url, db)
  rescue => e
    puts "❌ Like toggle error: #{e.class} - #{e.message}"
    puts "   URL: #{url}, liked_now: #{liked_now}"
    0
  end
end
```

## Testing
To verify the fix works:

1. **Start the server**: `bundle exec ruby app.rb` or `rerun ruby app.rb`
2. **Navigate to a meme**: Go to `/random`
3. **Click the like button**: The counter should increment by 1
4. **Click again to unlike**: The counter should decrement by 1
5. **Click multiple times**: Counter should toggle between N and N+1 (not increment multiple times)

## Expected Behavior After Fix
- ✅ Like counter increments by 1 when first liked
- ✅ Like counter decrements by 1 when unliked
- ✅ Multiple rapid clicks don't cause duplicate increments
- ✅ Frontend UI accurately reflects the like state
- ✅ Database counter stays in sync with user's like state
- ✅ Session tracks which memes the user has liked

## Related Files
- `lib/services/meme_service.rb` - Fixed toggle_like method
- `routes/memes.rb` - POST /like endpoint that calls MemeService.toggle_like
- `views/random.erb` - Frontend JavaScript that handles like button clicks (lines 474-525)

## Notes
- The fix maintains compatibility with the existing like tracking system
- Session storage ensures each user's likes are tracked independently
- The solution prevents counter manipulation through rapid clicking
- Debug logging helps diagnose any future issues
