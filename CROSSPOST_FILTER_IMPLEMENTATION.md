# Crosspost Filter Implementation

**Date:** May 12, 2026  
**Feature:** Skip crossposts in random meme selection

## Overview

Implemented filtering to skip Reddit crossposts in the random meme feed, ensuring users only see original content. Crossposts are posts that have been shared from one subreddit to another, and filtering them out improves content quality and reduces duplication.

## What Are Crossposts?

Reddit crossposts are when a user shares a post from one subreddit to another. The Reddit API provides metadata to identify these:
- `is_crosspost`: Boolean flag indicating if the post is a crosspost
- `crosspost_parent`: ID of the original post if this is a crosspost
- `crosspost_parent_list`: Array containing the chain of crosspost parents

## Implementation Details

### 1. API Cache Service (`lib/services/api_cache_service.rb`)

Added crosspost filtering at the data fetching layer - the earliest possible point:

#### Authenticated Fetch (Line 297)
```ruby
# Skip crossposts - we want original content only
next if post_data['is_crosspost'] || post_data['crosspost_parent']
```

#### Unauthenticated Fetch (Line 388)
```ruby
# Skip crossposts - we want original content only
next if post_data['is_crosspost'] || post_data['crosspost_parent']
```

**Why filter here?**
- Prevents crossposts from ever entering the cache
- Reduces storage overhead
- Ensures all downstream services work with original content only

### 2. Random Selector Service (`lib/services/random_selector_service.rb`)

Added a safety layer in the random meme selection algorithm:

#### New Filter Method (Line 663)
```ruby
# Filter crossposts - keep only original content
def filter_crossposts(memes)
  memes.reject do |meme|
    meme['is_crosspost'] || meme['crosspost_parent'] || meme['crosspost_parent_list']
  end
end
```

#### Applied in Selection Flow (Line 88)
```ruby
# STEP 2: Skip crossposts (safety filter - should already be filtered at API level)
filtered_memes = filter_crossposts(filtered_memes)
return nil if filtered_memes.empty?
```

**Why filter here too?**
- Defense-in-depth: catches any crossposts that might slip through
- Handles edge cases where crosspost metadata might be added later
- Future-proof against data source changes

## Benefits

### 1. **Better Content Quality**
- Users see original posts from their source communities
- Reduces seeing the same meme in different contexts

### 2. **Reduced Duplication**
- The same viral meme often gets crossposted to multiple subreddits
- Filtering crossposts naturally reduces this duplication

### 3. **Attribution to Original Creators**
- Original content gets prioritized over reposts
- Better engagement metrics on original posts

### 4. **Improved User Experience**
- Less repetitive content
- More diverse meme sources
- Cleaner feed

## Technical Notes

### Performance Impact
- **Minimal:** Filtering happens during iteration, no additional API calls
- **O(1) complexity:** Simple boolean checks per meme
- **Early filtering:** Reduces cache size and downstream processing

### Backward Compatibility
- Gracefully handles memes without crosspost metadata (local files, old data)
- Existing cached memes without crosspost flags are not affected
- No database migration required

### Testing Recommendations

1. **Monitor meme cache size:**
   - Check if filtering crossposts significantly reduces available memes
   - May need to fetch from more subreddits if pool shrinks

2. **Log crosspost filtering:**
   ```ruby
   puts "[FILTER] Skipped #{crosspost_count} crossposts"
   ```

3. **Verify with popular subreddits:**
   - High-volume subs like r/memes often have many crossposts
   - Test with subreddits known for original content

## Configuration

No configuration needed - filtering is automatic. If you need to disable it:

### Option 1: Environment Variable (Future Enhancement)
```ruby
# In api_cache_service.rb
SKIP_CROSSPOSTS = ENV.fetch('SKIP_REDDIT_CROSSPOSTS', 'true') == 'true'
next if SKIP_CROSSPOSTS && (post_data['is_crosspost'] || post_data['crosspost_parent'])
```

### Option 2: Algorithm Configuration
Add to `config/algorithm_config.yml`:
```yaml
content_filters:
  skip_crossposts: true
```

## Monitoring

### Key Metrics to Watch

1. **Filter Rate:**
   - What percentage of posts are crossposts?
   - Varies by subreddit (ranges from 5-30%)

2. **Cache Size:**
   - Monitor if available meme pool decreases significantly
   - May need to increase `MAX_SUBREDDITS` if pool is too small

3. **Content Diversity:**
   - Ensure filtering doesn't over-restrict content
   - Track subreddit distribution in served memes

## Future Enhancements

1. **Smart Crosspost Handling:**
   - Allow crossposts if the original is from a subreddit not in our fetch list
   - Detect and prefer original over crosspost when both are available

2. **Crosspost Analytics:**
   - Track which subreddits have the highest crosspost rates
   - Use data to optimize subreddit selection

3. **User Preference:**
   - Allow users to toggle crosspost filtering
   - Some users may prefer seeing content from their favorite subreddits even if crossposted

## Deployment

### No Special Steps Required
- Changes are code-only, no database migrations
- Will take effect on next cache refresh
- Existing cached memes remain until cache expires (1 hour TTL)

### Force Immediate Effect
```bash
# Clear Redis cache to force immediate re-fetch
redis-cli FLUSHDB

# Or restart the server
./restart_server.sh
```

## Related Files

- `lib/services/api_cache_service.rb` - Primary filtering at API level
- `lib/services/random_selector_service.rb` - Secondary safety filter
- `routes/random_meme.rb` - Random meme endpoint (unchanged)
- `lib/services/meme_service.rb` - May need similar filtering if used

## Summary

Crosspost filtering has been successfully implemented at two layers:
1. **API fetch layer** - Prevents crossposts from entering the system
2. **Selection layer** - Safety net to catch any that slip through

This ensures users get original, high-quality content while maintaining backward compatibility and performance.
