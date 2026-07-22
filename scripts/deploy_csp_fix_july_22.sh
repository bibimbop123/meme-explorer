#!/bin/bash
# Deploy CSP fix for imgur.com and cdn.jsdelivr.net
# July 22, 2026

set -e  # Exit on error

echo "======================================================================"
echo "DEPLOYING CSP FIX FOR IMGUR AND JSDELIVR"
echo "======================================================================"
echo ""

# Step 1: Show what changed
echo "Step 1: Changes to be deployed..."
echo "  - Service worker cache bumped to v2.1"
echo "  - CSP includes cdn.jsdelivr.net and i.imgur.com in connect-src"
echo "  - Service worker refresh helper added"
echo ""

# Step 2: Git status check
echo "Step 2: Checking git status..."
git status --short
echo ""

# Step 3: Add files
echo "Step 3: Adding files to git..."
git add public/service-worker.js
git add public/js/sw-refresh.js
git add lib/middleware/security_headers.rb
git add CSP_IMGUR_JSDELIVR_FIX_JULY_22_2026.md
git add scripts/fix_csp_imgur_jsdelivr_july_22.rb
git add scripts/deploy_csp_fix_july_22.sh
echo "  ✓ Files staged"
echo ""

# Step 4: Commit
echo "Step 4: Creating commit..."
git commit -m "Fix CSP for imgur.com and cdn.jsdelivr.net

- Bump service worker cache to v2.1 to force client refresh
- Ensure connect-src includes cdn.jsdelivr.net for Chart.js
- Ensure connect-src includes i.imgur.com for image loading
- Add sw-refresh.js helper for manual service worker reset
- Fixes console errors about CSP violations

Resolves: Service worker fetch() blocked by CSP for external CDNs"
echo "  ✓ Changes committed"
echo ""

# Step 5: Push to origin
echo "Step 5: Pushing to GitHub..."
git push origin main
echo "  ✓ Pushed to GitHub"
echo ""

echo "======================================================================"
echo "DEPLOYMENT COMPLETE"
echo "======================================================================"
echo ""
echo "What happens next:"
echo "  1. Render will automatically detect the push"
echo "  2. Build and deploy will start (~2-3 minutes)"
echo "  3. New service worker (v2.1) will be registered on client visits"
echo "  4. CSP will allow imgur.com and cdn.jsdelivr.net connections"
echo ""
echo "Verification:"
echo "  1. Visit your site in incognito mode (clean service worker)"
echo "  2. Open DevTools Console"
echo "  3. Verify no CSP errors for imgur.com or cdn.jsdelivr.net"
echo "  4. Check that Chart.js loads from CDN"
echo "  5. Check that imgur images display correctly"
echo ""
echo "If users still see CSP errors after deployment:"
echo "  - Direct them to visit: https://your-site.com/?refresh_sw=1"
echo "  - Or run in console: navigator.serviceWorker.getRegistrations().then(r => r.forEach(reg => reg.unregister())).then(() => location.reload())"
echo ""
echo "See CSP_IMGUR_JSDELIVR_FIX_JULY_22_2026.md for full documentation"
echo ""
