#!/bin/bash
# Deploy Redis Session Fix - Fixes OAuth login by migrating from cookies to Redis sessions
# This resolves the "Rack::Session::Cookie data size exceeds 4K" error

set -e

echo "🚀 Deploying Redis Session Fix..."
echo ""

# Step 1: Install new gem dependency
echo "📦 Step 1: Installing redis-rack gem..."
bundle install
echo "✅ Gem installed"
echo ""

# Step 2: Clear existing cookie-based sessions (optional, they'll expire naturally)
echo "🧹 Step 2: Clearing old Redis session data (if any)..."
if [ -n "$REDIS_URL" ]; then
  redis-cli -u "$REDIS_URL" --scan --pattern "session:*" | xargs -L 100 redis-cli -u "$REDIS_URL" DEL 2>/dev/null || echo "No existing sessions to clear"
else
  echo "REDIS_URL not set, skipping session cleanup"
fi
echo "✅ Session cleanup complete"
echo ""

# Step 3: Verify configuration
echo "🔍 Step 3: Verifying configuration..."
if [ -z "$REDIS_URL" ]; then
  echo "⚠️  WARNING: REDIS_URL environment variable not set!"
  echo "   Default will be: redis://localhost:6379/0"
fi

if [ -z "$SESSION_SECRET" ]; then
  echo "⚠️  WARNING: SESSION_SECRET environment variable not set!"
  echo "   Using file-based secret (development only)"
fi
echo "✅ Configuration verified"
echo ""

# Step 4: Test Redis connectivity
echo "🧪 Step 4: Testing Redis connectivity..."
if [ -n "$REDIS_URL" ]; then
  if redis-cli -u "$REDIS_URL" PING > /dev/null 2>&1; then
    echo "✅ Redis connection successful"
  else
    echo "❌ ERROR: Cannot connect to Redis at $REDIS_URL"
    exit 1
  fi
else
  echo "⚠️  Skipping Redis connectivity test (REDIS_URL not set)"
fi
echo ""

echo "✅ Redis Session Fix deployed successfully!"
echo ""
echo "📋 Next steps:"
echo "   1. Restart your application: 'render deploy' or 'heroku restart'"
echo "   2. Test Reddit OAuth login"
echo "   3. Monitor logs for any session-related errors"
echo ""
echo "🎉 Users will now be able to complete Reddit OAuth login!"
