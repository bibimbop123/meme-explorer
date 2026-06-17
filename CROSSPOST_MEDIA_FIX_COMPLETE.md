# Crosspost Media Extraction Fix - COMPLETE

**Date:** June 17, 2026  
**Issue:** Crossposts showing "content not available"  
**Status:** ✅ FIXED

## Problem

Crossposts were appearing in the feed but showing "content not available" because:
1. The crosspost post itself doesn't have a direct `url` field with the image
2. The actual media is stored in `crosspost_parent_list[0]` (the original post)
3. The parser was only looking at the crosspost post data, not the original

## Solution

Updated `lib/services/turbocharged_reddit_fetcher.rb` to:

### Key Changes

```ruby
# BEFORE: Only looked at current post data
post_data = post["data"]
image_url = post_data["url"]  # Empty for crossposts!

# AFTER: Extract from original if crosspost
if post_data["is_crosspost"] && post_data["crosspost_parent_list"]&.any?
  original_post = post_data["crosspost_parent_list"].first
  source_data = original_post  # Use original for media
  is_crosspost = true
else
  source_data = post_data
  is_crosspost = false
end

image_url = source_data["url"]  # Now gets original image!
```

### What Was Fixed

1. **Media Extraction**: Now extracts image URL from `crosspost_parent_list[0]` when present
2. **Gallery Support**: Handles gallery posts from original post in crossposts
3. **Metadata Added**: Marks crossposts with `is_crosspost` flag and `original_subreddit`
4. **Context Preserved**: Keeps crosspost title/subreddit while using original media

### Files Modified

- ✅ `lib/services/turbocharged_reddit_fetcher.rb` - Updated `parse_reddit_response` method
- ✅ Backup created: `backups/crosspost_fix_20260617/turbocharged_reddit_fetcher.rb.backup`

---

## How To Apply & Test

### Step 1: Clear the Cache

The old cached data still has broken crosspost entries. Clear it:

```bash
# Option A: Clear Redis cache
redis-cli FLUSHDB

# Option B: Clear specific keys
redis-cli DEL cache:api_memes:latest

# Option C: Use the refresh script
ruby scripts/manual_cache_refresh.rb
```

### Step 2: Restart Your Server

```bash
# Development
./scripts/start_dev_server.sh

# Or manual restart
pkill -f puma
bundle exec puma -C config/puma.rb

# Production (Render)
# Will auto-deploy on git push
```

### Step 3: Test Crossposts

1. **Visit your site** and browse memes
2. **Look for crosspost indicators** (if displayed):
   - Badge or icon showing it's a crosspost
   - "Originally from r/subredditname" text
3. **Verify images load** - crossposts should now show properly!

### Step 4: Verify in Logs

Check that crossposts are being parsed:

```bash
# Development logs
tail -f log/development.log | grep -i crosspost

# Check meme count
# Before fix: Fewer memes (crossposts skipped due to no URL)
# After fix: More memes (crossposts included with media)
```

---

## Technical Details

### Crosspost Data Structure

When Reddit provides a crosspost, the data looks like:

```json
{
  "data": {
    "title": "Check out this meme!",
    "subreddit": "memes",
    "is_crosspost": true,
    "url": "",  // EMPTY or points to crosspost, not original
    "crosspost_parent": "t3_abc123",
    "crosspost_parent_list": [
      {
        "title": "Original title",
        "subreddit": "dankmemes",
        "url": "https://i.redd.it/xyz123.jpg",  // THE ACTUAL IMAGE
        "is_gallery": false,
        "gallery_data": {...},
        "media_metadata": {...}
      }
    ]
  }
}
```

### The Fix Logic

```ruby
# 1. Detect crosspost
if post_data["is_crosspost"] && post_data["crosspost_parent_list"]&.any?
  original_post = post_data["crosspost_parent_list"].first
  
  # 2. Use original for media extraction
  source_data = original_post
  is_crosspost = true
  original_subreddit = original_post["subreddit"]
else
  # Regular post
  source_data = post_data
  is_crosspost = false
end

# 3. Extract media from correct source
is_gallery = source_data["is_gallery"] == true
gallery_images = is_gallery ? extract_gallery_images(source_data) : nil
image_url = source_data["url"]  # Now from original!

# 4. Build meme with metadata
meme = {
  "title" => post_data["title"],  # Keep crosspost title
  "url" => image_url,              # Use original media
  "subreddit" => post_data["subreddit"],  # Where it was crossposted
  "is_crosspost" => is_crosspost,
  "original_subreddit" => original_subreddit  # Where it came from
}
```

---

## Display Options (Optional)

You can now add crosspost indicators to your views:

### Simple Badge

```erb
<!-- In views/meme_page.erb or similar -->
<% if meme['is_crosspost'] %>
  <span class="crosspost-badge">
    Crosspost from r/<%= meme['original_subreddit'] %>
  </span>
<% end %>
```

### CSS Styling

```css
.crosspost-badge {
  background: #0079d3;
  color: white;
  padding: 4px 8px;
  border-radius: 8px;
  font-size: 11px;
  display: inline-block;
  margin: 4px 0;
}
```

---

## Expected Results

### Before Fix
- Crossposts showed "content not available"
- Some memes skipped entirely
- Smaller meme pool

### After Fix
- ✅ Crossposts display correctly with images
- ✅ Gallery crossposts work
- ✅ Larger, more diverse meme pool
- ✅ Metadata available for attribution

---

## Monitoring

### Check Success Rate

```bash
# Count total memes vs crossposts
redis-cli GET cache:api_memes:latest | jq '. | length'
redis-cli GET cache:api_memes:latest | jq '[.[] | select(.is_crosspost == true)] | length'

# Expected: 10-30% of memes might be crossposts depending on subreddits
```

### Watch for Errors

```bash
# Look for any parsing errors
tail -f log/development.log | grep -i "error"

# Check image loading issues
tail -f log/development.log | grep -i "broken"
```

---

## Rollback (If Needed)

If something goes wrong, restore the backup:

```bash
cp backups/crosspost_fix_20260617/turbocharged_reddit_fetcher.rb.backup \
   lib/services/turbocharged_reddit_fetcher.rb
   
redis-cli FLUSHDB
# Restart server
```

---

## Additional Notes

### Crosspost Filtering

- `api_cache_service.rb` and `random_selector_service.rb` have crosspost filters
- These filters are currently **active** and skip crossposts
- If you want to **show all crossposts**, comment out those filter lines
- See `CROSSPOST_FILTER_IMPLEMENTATION.md` for details

### Why Some Crossposts Still Get Through

Even with filters, some crossposts might appear if:
1. Filter runs after caching (some already in cache)
2. Metadata incomplete (Reddit API doesn't always set all flags)
3. The fix ensures these display correctly instead of failing

---

## Summary

**Problem:** Crossposts → "content not available"  
**Root Cause:** Image URL in `crosspost_parent_list`, not on post directly  
**Fix:** Extract media from original post within crosspost data  
**Result:** Crossposts now display correctly with proper images  

**Files Changed:**
- `lib/services/turbocharged_reddit_fetcher.rb`

**Next Steps:**
1. Clear cache (redis-cli FLUSHDB)
2. Restart server
3. Verify crossposts display with images
4. (Optional) Add crosspost badges to UI

✅ **Fix is complete and ready to test!**
