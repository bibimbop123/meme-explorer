#!/bin/bash
# Post-deployment script for Render.com
# This runs automatically after each deployment

set -e

echo "🚀 Running post-deployment tasks..."

# Wait for server to be ready
echo "⏳ Waiting 10 seconds for server to be fully ready..."
sleep 10

# Trigger cache refresh automatically
echo "🔄 Triggering automatic cache refresh..."
response=$(curl -X POST \
  -w "\n%{http_code}" \
  -s \
  -m 30 \
  https://meme-explorer.onrender.com/admin/refresh-cache \
  -H "Content-Type: application/json" 2>&1 || echo "000")

http_code=$(echo "$response" | tail -n1)

if [ "$http_code" = "200" ] || [ "$http_code" = "202" ]; then
  echo "✅ Cache refresh triggered successfully (HTTP $http_code)"
else
  echo "⚠️  Cache refresh request returned HTTP $http_code"
  echo "Response: $response"
  echo "ℹ️  This is not critical - cache will be populated on startup via config.ru"
fi

echo "✅ Post-deployment tasks complete"
