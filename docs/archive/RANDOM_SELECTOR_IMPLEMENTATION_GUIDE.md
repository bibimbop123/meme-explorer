# Random Selector Service - Implementation & Configuration Guide

## Overview

The `RandomSelectorService` provides intelligent random meme selection with engagement-based weighting, content filtering, and session tracking. This guide explains configuration, usage, and customization.

## Quick Start

```ruby
meme = RandomSelectorService.select_random_meme(
  memes_array,
  session_id: 'user_session_123',
  preferences: { excluded_categories: ['lgbtq', 'trans'] }
)
```

## Configuration

### Excluded Categories
Default: `['lgbtq', 'trans', 'political_extreme']`

Edit `lib/services/random_selector_service.rb` line 6 to customize.

### Humor Type Weights
```ruby
HUMOR_WEIGHTS = {
  'dank' => 1.0,
  'funny' => 1.2,      # 20% more likely
  'wholesome' => 0.9,
  'absurdist' => 1.1,
  'dark' => 0.95
}
```

Adjust to prefer certain humor types.

### Freshness Bonus
- 0-1 days: 1.15× boost
- 2-7 days: 1.08× boost
- 8+ days: 1.0× (no boost)

Edit lines 92-100 to adjust.

### Session Buffer
Current: Last 10 memes. Edit line 142 to change.

## Algorithm

Weight = (1.0 + likes × 0.01) × humor_multiplier × freshness_bonus

1. Filter excluded categories
2. Filter recently shown memes
3. Calculate weight for each remaining meme
4. Perform weighted random selection
5. Track in session

## Performance

- Time: O(n) linear
- Space: O(1) constant
- DB queries: 0
- No performance degradation

## Integration in Routes

```ruby
app.get "/random" do
  memes = ApiCacheService.fetch_and_cache_memes(...)
  
  session_id = session.object_id.to_s
  user_prefs = { excluded_categories: ['lgbtq', 'trans'] }
  @meme = RandomSelectorService.select_random_meme(memes, session_id: session_id, preferences: user_prefs)
  
  erb :random
end
```

## Testing

Run tests to verify:
- Categories are filtered
- Engagement-based weighting works
- Session repetition is prevented
- No nil memes returned
