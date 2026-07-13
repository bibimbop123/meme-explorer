#!/bin/bash
# Deploy Redis Service Fix - July 13, 2026
# Fixes the critical bug in RedisService.get() that was returning empty values

set -e

echo "=================================================================================="
echo "🚀 DEPLOYING REDIS SERVICE FIX - July 13, 2026"
echo "=================================================================================="
echo ""

echo "📝 What this fixes:"
echo "   - RedisService.get() was using || operator which treated empty strings as falsy"
echo "   - This caused all Redis reads to return nil/default instead of actual values"
echo "   - Meme pools were populated but couldn't be read back"
echo ""

echo "🔄 Step 1: Committing Redis Service fix..."
git add lib/services/redis_service.rb
git commit -m "Fix critical RedisService.get() bug - remove || operator

The || operator in get() was causing empty strings and other falsy
values to be replaced with defaults. Changed to explicit nil check.

This fixes the empty meme pools issue where pools were populated
but couldn't be retrieved."

echo ""
echo "🔄 Step 2: Pushing to production..."
git push origin main

echo ""
echo "⏳ Step 3: Waiting for Render to deploy (60 seconds)..."
sleep 60

echo ""
echo "🔄 Step 4: Re-populating meme pools with working RedisService..."
echo "   Run this command in Render shell:"
echo ""
echo "   bundle exec ruby scripts/fix_empty_redis_pools_july_13_2026.rb"
echo ""

echo "=================================================================================="
echo "✅ DEPLOYMENT COMPLETE"
echo "=================================================================================="
echo ""
echo "📊 Next Steps:"
echo "   1. Run the pool population script in production shell (command above)"
echo "   2. Run diagnostic: bundle exec ruby scripts/diagnose_redis_pools_july_13.rb"
echo "   3. Monitor logs - should see '✅ Retrieved X memes from Redis pool'"
echo "   4. No more '⚠️ Redis pool empty' warnings!"
echo ""
echo "🎯 Expected Result:"
echo "   - All 6 pool types populated and readable"
echo "   - 3-5ms faster /random responses"
echo "   - No more fallback to filtering"
echo ""
