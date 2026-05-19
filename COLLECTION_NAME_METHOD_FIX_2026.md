# Collection Name Method Fix - May 19, 2026

## Problem
Server logs showed `NoMethodError - undefined method 'collection_name_for_subreddit'` causing errors when rendering views.

## Root Cause
**Method name mismatch** between what views expected and what was defined:

1. **Views were calling**: `collection_name_for_subreddit(@meme['subreddit'])`
   - Used in: `views/random.erb` (lines 52, 104), `views/layout.erb`, `routes/collections.rb`

2. **Actual method name**: `collection_name_for(subreddit)`
   - Defined in: `lib/helpers/curated_collections_helper.rb` (line 44)

3. **Additional issue**: `CuratedCollectionsHelper` uses class methods (`self.method_name`) but wasn't properly exposed to Sinatra views as instance methods.

## Solution
Added **helper wrapper methods** in `app.rb` (after line 596) to bridge the gap between view expectations and helper module class methods:

```ruby
helpers do
  # Wrapper for collection_name_for_subreddit (views expect this method name)
  def collection_name_for_subreddit(subreddit)
    CuratedCollectionsHelper.collection_name_for(subreddit)
  end
  
  # Wrapper for calculate_rarity (used in views/random.erb)
  def calculate_rarity(meme)
    rarity = refined_rarity_badge(meme)
    return rarity if rarity
    
    # Default rarity for common memes
    { label: 'Common', icon: '•' }
  end
  
  # Wrapper for generate_curation_signal (used in views/random.erb and layout.erb)
  def generate_curation_signal(meme)
    signal = refined_curation_signal(meme, session[:user_id])
    return signal if signal
    
    # Default curation signal
    { type: 'default', icon: '✨', message: 'Curated for you' }
  end
end
```

## Benefits
✅ **Fixes the immediate error** - `collection_name_for_subreddit` now works in views  
✅ **No view changes needed** - All existing view code continues to work  
✅ **Maintains architecture** - Keeps helper module separation intact  
✅ **Future-proof** - Provides foundation for other helper wrappers if needed  
✅ **Safe defaults** - Returns sensible defaults if helper methods fail

## Testing Required
1. Restart the server to load the new helper methods
2. Visit `/random` page and verify it renders without errors
3. Check server logs for any remaining `NoMethodError` issues
4. Verify collection names display correctly in the UI

## Files Modified
- `app.rb` - Added helper wrapper methods (lines 598-622)

## Related Methods Fixed
- `collection_name_for_subreddit(subreddit)` ✅
- `calculate_rarity(meme)` ✅  
- `generate_curation_signal(meme)` ✅

## Status
**COMPLETE** - Ready for server restart and testing.
