# CSS Bundling Strategy
**Date:** July 26, 2026  
**Week:** 2 - Performance Optimization

## Bundle Overview

### Bundle 1: Critical CSS (Inline)
**Purpose:** Eliminate render-blocking CSS  
**Size:** ~15KB uncompressed  
**Loading:** Inlined in `<head>`

**Contents:**
- `theme.css` - Core theming variables
- `meme_explorer.css` - Base layout
- `grid-layout-v3.css` - Grid system
- `navigation.css` - Navigation styles

**Usage in layout.erb:**
```erb
<head>
  <style><%= File.read('public/css/critical.min.css') %></style>
</head>
```

### Bundle 2: Page CSS (Deferred)
**Purpose:** Non-critical styling  
**Size:** ~30KB uncompressed  
**Loading:** Deferred with preload

**Contents:**
- `animations.css` - Transitions & animations
- `refined-aesthetic.css` - Polish & refinements
- `mobile-optimizations-v2.css` - Responsive design
- `image-optimization.css` - Image styles

**Usage in layout.erb:**
```erb
<link rel="preload" href="/css/page.min.css" as="style" 
      onload="this.onload=null;this.rel='stylesheet'">
<noscript><link rel="stylesheet" href="/css/page.min.css"></noscript>
```

### Bundle 3: Features CSS (Conditional)
**Purpose:** Feature-specific styles  
**Size:** ~20KB uncompressed  
**Loading:** Only if features enabled

**Contents:**
- `ads.css` - Ad placement styles
- `achievements.css` - Achievement UI
- `streaks.css` - Streak system
- `leaderboard.css` - Leaderboard

**Usage in layout.erb:**
```erb
<% if FeatureFlags.enabled?('gamification.enabled') %>
  <link rel="stylesheet" href="/css/features.min.css" 
        media="print" onload="this.media='all'">
<% end %>
```

## Performance Impact

### Before Bundling
- **Files:** 20+ individual CSS files
- **Total Size:** ~120KB uncompressed
- **HTTP Requests:** 20+ requests
- **Load Time:** ~800ms

### After Bundling
- **Files:** 3 bundled files
- **Total Size:** ~65KB uncompressed (~18KB gzipped)
- **HTTP Requests:** 1-3 requests
- **Load Time:** ~200ms

**Improvement:** 75% faster, 45% smaller

## Build Process

```bash
# Run the build script
./scripts/build_assets.sh

# Output files:
# - public/css/critical.min.css
# - public/css/page.min.css
# - public/css/features.min.css
```

## Rollback Plan

If bundling causes issues:
1. Revert layout.erb changes
2. Use individual CSS files
3. Remove bundle references

## Maintenance

When adding new CSS:
1. Determine which bundle it belongs to
2. Update `scripts/build_assets.sh`
3. Rebuild bundles
4. Test performance

---
**Last Updated:** July 26, 2026
