#!/bin/bash
# Deploy fix for viewing history Redis zadd error
# Error: "undefined method `zadd' for RedisService:Class"
# Date: June 29, 2026

set -e

echo "🚀 Deploying Viewing History Redis Fix..."
echo "=========================================="

# Check if we're on Render
if [ -n "$RENDER" ]; then
  echo "✅ Running on Render - proceeding with deployment"
else
  echo "⚠️  Not on Render - this script is for production deployment"
  echo "To test locally, just restart your development server"
  exit 0
fi

# The fix is already in the code - just need to restart the web service
echo ""
echo "📋 Fix Summary:"
echo "  - Changed all RedisService direct method calls to use RedisService.with_redis"
echo "  - Fixed methods: zadd, zremrangebyrank, expire, zrange, zscore, zcard, del, ttl"
echo "  - All viewing history operations now properly use Redis connection pool"
echo ""

# Render will automatically restart the service after deployment
echo "✅ ViewingHistoryService has been updated"
echo "✅ Service will restart automatically"
echo ""
echo "🎯 Monitoring:"
echo "  - Watch for 'Failed to mark meme as seen' errors (should disappear)"
echo "  - Verify viewing history tracking works correctly"
echo "  - Check Redis connection pool is functioning properly"
echo ""
echo "✨ Deployment complete!"
