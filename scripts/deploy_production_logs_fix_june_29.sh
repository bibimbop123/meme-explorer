#!/bin/bash
# Deploy Production Logs Fix - June 29, 2026
# Fixes: /api/vitals 404, pool categorization, log noise

set -e  # Exit on error

echo "🚀 Deploying Production Logs Fix - June 29, 2026"
echo "=================================================="

# Run the fix script
echo ""
echo "📝 Step 1: Applying fixes..."
ruby scripts/fix_production_logs_june_29.rb

# Make sure the script succeeded
if [ $? -ne 0 ]; then
  echo "❌ Fix script failed! Aborting deployment."
  exit 1
fi

# Commit changes
echo ""
echo "📦 Step 2: Committing changes..."
git add -A
git commit -m "Fix production logs: /api/vitals 404, pool categorization, log noise - June 29, 2026

- Register /api/vitals route properly with module structure
- Relax pool filters for trending/surprise (fixes empty pools)  
- Add engagement metadata to fetched memes
- Reduce log noise for expected conditions (Sidekiq warnings)
- Optimize bootstrap pool categorization

Resolves: 404 errors, empty pool warnings, 1.5s bootstrap time"

# Push to production
echo ""
echo "🚢 Step 3: Deploying to production..."
git push origin main

echo ""
echo "⏳ Step 4: Waiting for Render deployment..."
echo "   Monitor at: https://dashboard.render.com"
echo ""
echo "✅ Deployment initiated!"
echo ""
echo "📊 Expected improvements:"
echo "  • No more /api/vitals 404 errors"
echo "  • Trending/surprise pools will have content"
echo "  • Reduced log noise (Sidekiq warnings -> debug)"
echo "  • Better meme categorization with metadata"
echo "  • Faster bootstrap with relaxed filters"
echo ""
echo "🔍 Monitor logs to verify:"
echo "  render logs --tail"
