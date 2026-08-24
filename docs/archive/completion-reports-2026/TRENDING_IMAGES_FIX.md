# Trending Memes Images Fix

## Issue
Trending memes page was not displaying meme images - only showing fallback images.

## Root Cause
The JavaScript (`public/js/trending.js`) expected an `image_url` field in the API response, but the `TrendingService` was only returning a `url` field from the database.

**Database Schema:**
```sql
CREATE TABLE meme_stats (
  url TEXT UNIQUE NOT NULL,  -- Image URL stored here
  title TEXT,
  subreddit VARCHAR(255),
  likes INTEGER DEFAULT 0,
  views INTEGER DEFAULT 0,
  ...
);
```

**JavaScript Expected:**
```javascript
const imageUrl = meme.image_url || `/images/${meme.subreddit || 'dank'}1.jpeg`;
```

**API Was Returning:**
```json
{
  "url": "https://i.redd.it/...",
  "title": "...",
  // Missing: "image_url" field
}
```

## Solution
Updated `lib/services/trending_service.rb` to alias the `url` column as `image_url` in SQL queries:

### Changes Made:

1. **get_trending_memes method:**
```sql
SELECT 
  url,
  url AS image_url,  -- Added this alias
  title,
  subreddit,
  views,
  likes,
  ...
```

2. **get_trending_by_category method:**
```sql
SELECT 
  m.url,
  m.url AS image_url,  -- Added this alias
  m.title,
  m.subreddit,
  ...
```

## Testing
To verify the fix works:

1. **Start the server:**
   ```bash
   bundle exec ruby app.rb
   ```

2. **Visit the trending page:**
   ```
   http://localhost:8080/trending
   ```

3. **Check the API response:**
   ```bash
   curl http://localhost:8080/api/v1/trending?time_window=24h
   ```

4. **Expected response:**
   ```json
   {
     "success": true,
     "data": [
       {
         "url": "https://i.redd.it/xyz123.jpg",
         "image_url": "https://i.redd.it/xyz123.jpg",
         "title": "Funny meme",
         "subreddit": "memes",
         "likes": 42,
         "views": 100
       }
     ]
   }
   ```

## Files Modified
- `lib/services/trending_service.rb`

## Impact
- ✅ Trending memes now display actual images from Reddit
- ✅ No database migration required (just SQL query change)
- ✅ Backward compatible (still returns `url` field)
- ✅ Fallback mechanism in JavaScript still works if image fails to load

## Deployment
Simply restart the application - no migration needed:
```bash
# Local
bundle exec ruby app.rb

# Production (Render)
git add lib/services/trending_service.rb TRENDING_IMAGES_FIX.md
git commit -m "Fix trending memes not showing images"
git push origin main
```
