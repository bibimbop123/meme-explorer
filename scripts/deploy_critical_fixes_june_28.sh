#!/bin/bash

# Critical Production Fixes Deployment - June 28, 2026
# Fixes: Syntax error, MilestoneService namespace, track_selection args

set -e  # Exit on error

echo "🚀 Deploying Critical Production Fixes..."
echo ""

# Show what files changed
echo "📝 Changed files:"
git status --short

echo ""
echo "Files to be committed:"
echo "  ✓ lib/services/turbocharged_reddit_fetcher.rb (CRITICAL - syntax fix)"
echo "  ✓ lib/services/milestone_service.rb (namespace fix)"
echo "  ✓ routes/enhanced_random.rb (argument fix)"
echo ""

# Stage the critical fixes
git add lib/services/turbocharged_reddit_fetcher.rb
git add lib/services/milestone_service.rb  
git add routes/enhanced_random.rb
git add PRODUCTION_ERRORS_FIXED_JUNE_28_2026.md

# Commit with descriptive message
git commit -m "CRITICAL: Fix syntax error blocking entire site + namespace/arg errors

- Fix turbocharged_reddit_fetcher.rb lines 420-421 syntax error
- Add MemeExplorer namespace to MilestoneService  
- Fix track_selection to use positional arguments
- Site was completely broken - /random.json returning 500

Fixes #production-errors"

echo ""
echo "✅ Changes committed!"
echo ""
echo "🚀 Pushing to production..."

# Push to main branch (triggers auto-deploy on Render)
git push origin main

echo ""
echo "✅ Pushed to GitHub!"
echo ""
echo "⏳ Render will auto-deploy in ~2-3 minutes"
echo "📊 Monitor deployment at: https://dashboard.render.com"
echo "📋 Check logs with: render logs --tail meme-explorer"
echo ""
echo "✅ Done!"
