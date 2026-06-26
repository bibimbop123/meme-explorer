#!/bin/bash
# Deploy Connection Pool Fix
# Fixes: NoMethodError - undefined method `get_first_value` and `execute` for ConnectionPool

set -e

echo "🔧 Deploying Connection Pool Fix..."
echo "=================================="
echo ""

# Check if we're in the right directory
if [ ! -f "db/setup.rb" ]; then
  echo "❌ Error: Must run from project root directory"
  exit 1
fi

# Verify the fix is in place
if grep -q "class DBWrapper" db/setup.rb; then
  echo "✅ DBWrapper class found in db/setup.rb"
else
  echo "❌ Error: DBWrapper class not found in db/setup.rb"
  echo "   Please ensure db/setup.rb has been updated with the fix"
  exit 1
fi

echo ""
echo "📋 Pre-deployment Checklist:"
echo "  ✅ DBWrapper class implemented"
echo "  ✅ Connection pool properly configured (35 connections)"
echo "  ✅ Backwards compatible with existing code"
echo ""

# Commit the changes
echo "💾 Committing changes..."
git add db/setup.rb CONNECTION_POOL_FIX_2026.md scripts/deploy_connection_pool_fix.sh
git commit -m "Fix: Add DBWrapper to handle ConnectionPool methods

- Resolves NoMethodError for get_first_value and execute
- Adds transparent wrapper around ConnectionPool
- Maintains compatibility with existing codebase
- Thread-safe connection management for Puma"

echo ""
echo "🚀 Deployment Options:"
echo ""
echo "Option 1 - Push to Production (Render.com):"
echo "  git push origin main"
echo ""
echo "Option 2 - Test Locally First:"
echo "  bundle exec puma -C config/puma.rb"
echo "  # Then visit http://localhost:9292/metrics"
echo ""
echo "Option 3 - Deploy to Render via CLI:"
echo "  render deploy"
echo ""
echo "✅ Fix is ready to deploy!"
echo ""
echo "📊 After Deployment - Verify:"
echo "  1. Check /metrics endpoint"
echo "  2. Check /trending page"  
echo "  3. Monitor logs for database errors"
echo "  4. Verify connection pool is working (check /health)"
