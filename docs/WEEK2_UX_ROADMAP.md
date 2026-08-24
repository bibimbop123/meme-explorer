# Week 2: UX Improvements Roadmap

## Priority 1: Fix Content Repetition

**Problem**: Users see same memes repeatedly
**Solution**: Implement better diversity tracking
**Files to modify**:
- `lib/services/diversity_engine_service.rb`
- `lib/services/meme_selection_service.rb`
- `lib/services/viewing_history_service.rb`

**Implementation**:
```ruby
# Increase viewing history tracking from 50 to 200 memes
# Add subreddit diversity scoring
# Implement temporal diversity (avoid same meme type back-to-back)
```

## Priority 2: Mobile Navigation

**Current Score**: 6/10
**Target**: 9/10

**Improvements Needed**:
1. Swipe gestures (left = prev, right = next)
2. Floating action button for like/save
3. One-handed navigation zone
4. Reduced tap targets needed

**Files to create/modify**:
- `public/js/modules/meme-gestures.js` (new)
- `public/css/mobile-optimizations-v3.css`
- `views/random.erb` (add gesture hints)

## Priority 3: Keyboard Shortcuts

**Shortcuts to add**:
- `j` = next meme
- `k` = previous meme
- `l` = like current meme
- `s` = save/bookmark
- `Shift+S` = share
- `?` = show shortcuts help

**Implementation**: `public/js/modules/keyboard-navigation.js`

## Priority 4: Fast Image Loading

**Current State**: Images load slowly, no progressive enhancement
**Target**: <1s image display with blur-up

**Improvements**:
1. Implement WebP format with fallbacks
2. Add blur-up placeholders (LQIP)
3. Preload next 2 images
4. Use Intersection Observer for lazy loading

## Priority 5: CLS Fixes

**Current CLS**: ~0.3
**Target**: <0.1

**Issues to fix**:
1. Reserve space for ads before they load
2. Set image dimensions explicitly
3. Preload critical fonts
4. Avoid DOM injections after initial render

## Success Metrics

- [ ] No meme repeats in 50 swipes
- [ ] Mobile score 90+
- [ ] CLS < 0.1
- [ ] All keyboard shortcuts working
- [ ] Images load <1s
