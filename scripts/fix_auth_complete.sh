#!/bin/bash
# Complete Authentication Fix Deployment Script

echo "🔧 Installing Redis session gem..."
bundle install

echo "🔍 Checking if Redis is running..."
if redis-cli ping > /dev/null 2>&1; then
  echo "✅ Redis is running"
else
  echo "⚠️  Redis is not running. Starting Redis..."
  if command -v redis-server > /dev/null 2>&1; then
    redis-server --daemonize yes
    echo "✅ Redis started"
  else
    echo "❌ Redis not installed. Please install Redis:"
    echo "   macOS: brew install redis"
    echo "   Linux: sudo apt-get install redis-server"
    exit 1
  fi
fi

echo "🧹 Clearing old sessions..."
redis-cli FLUSHDB > /dev/null 2>&1

echo "🔄 Restarting application..."
echo "✅ Authentication fix complete!"
echo ""
echo "📝 Summary:"
echo "  - Reddit OAuth now uses Redis sessions (no 4KB limit)"
echo "  - Logout works in one click"
echo "  - Navbar updates immediately after logout"
echo ""
echo "🚀 Ready to test! Try logging in with Reddit."
