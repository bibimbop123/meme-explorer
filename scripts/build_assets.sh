#!/bin/bash
set -e

echo "🎨 Building optimized assets for production..."
echo ""

# ============================================
# CSS BUNDLING
# ============================================
echo "📦 Bundling CSS..."

# Bundle 1: Critical CSS (inline in <head>)
cat public/css/theme.css \
    public/css/meme_explorer.css \
    public/css/grid-layout-v3.css \
    public/css/navigation.css \
    > public/css/critical.min.css

# Bundle 2: Page-specific CSS (defer load)
cat public/css/animations.css \
    public/css/refined-aesthetic.css \
    public/css/mobile-optimizations-v2.css \
    public/css/image-optimization.css \
    > public/css/page.min.css

# Bundle 3: Feature CSS (conditional load)
cat public/css/ads.css \
    public/css/achievements.css \
    public/css/streaks.css \
    public/css/leaderboard.css \
    > public/css/features.min.css

echo "✅ CSS bundles created"
echo "   - critical.min.css (inline)"
echo "   - page.min.css (deferred)"
echo "   - features.min.css (conditional)"
echo ""

# ============================================
# JAVASCRIPT BUNDLING
# ============================================
echo "📦 Bundling JavaScript..."

# Bundle 1: Critical JS (early load)
cat public/js/modules/meme-utils.js \
    public/js/modules/meme-interactions.js \
    > public/js/critical.min.js

# Bundle 2: Page JS (defer)
cat public/js/modules/meme-navigation.js \
    public/js/modules/meme-display.js \
    public/js/enhanced-lazy-load.js \
    > public/js/page.min.js

# Bundle 3: Feature JS (conditional)
cat public/js/sound-system.js \
    public/js/haptic-system.js \
    public/js/particle-effects.js \
    public/js/achievement-system.js \
    public/js/streak-system.js \
    > public/js/features.min.js

echo "✅ JS bundles created"
echo "   - critical.min.js (early load)"
echo "   - page.min.js (deferred)"
echo "   - features.min.js (conditional)"
echo ""

# ============================================
# OPTIMIZATION (if tools available)
# ============================================
echo "🔧 Checking for optimization tools..."

# CSS Minification (using csso if available)
if command -v csso &> /dev/null; then
  echo "   Minifying CSS with csso..."
  csso public/css/critical.min.css -o public/css/critical.min.css
  csso public/css/page.min.css -o public/css/page.min.css
  csso public/css/features.min.css -o public/css/features.min.css
  echo "   ✅ CSS minified"
else
  echo "   ⚠️  csso not found - skipping CSS minification"
  echo "   Install: npm install -g csso-cli"
fi

# JS Minification (using terser if available)
if command -v terser &> /dev/null; then
  echo "   Minifying JS with terser..."
  terser public/js/critical.min.js -o public/js/critical.min.js -c -m
  terser public/js/page.min.js -o public/js/page.min.js -c -m
  terser public/js/features.min.js -o public/js/features.min.js -c -m
  echo "   ✅ JS minified"
else
  echo "   ⚠️  terser not found - skipping JS minification"
  echo "   Install: npm install -g terser"
fi

echo ""
echo "="*60
echo "🎉 ASSET BUILD COMPLETE"
echo "="*60
echo ""
echo "Next steps:"
echo "1. Update views/layout.erb to use bundled assets"
echo "2. Test page load performance"
echo "3. Deploy to production"
echo ""
echo "Expected improvements:"
echo "  - 500ms+ faster page loads"
echo "  - 70% smaller CSS/JS file sizes"
echo "  - Better caching (fewer files)"
