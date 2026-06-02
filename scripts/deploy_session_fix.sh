#!/bin/bash
# Deploy Session Metrics Fix
# Fixes the "undefined method `[]' for Rack::Session::SessionId" error

set -e

echo "🚀 Deploying Session Metrics Fix..."
echo "=================================="

# Check if we're in the right directory
if [ ! -f "app.rb" ]; then
  echo "❌ Error: Must run from project root directory"
  exit 1
fi

# Backup the routes file (just in case)
echo "📦 Creating backup..."
cp routes/session_metrics.rb routes/session_metrics.rb.backup_$(date +%s)

# The fix has already been applied to routes/session_metrics.rb
echo "✅ Fix applied to routes/session_metrics.rb"
echo ""
echo "📝 Changes made:"
echo "   - Line 26: Added .to_s to session_id assignment"
echo "   - Line 70: Added .to_s to session_id assignment"
echo ""

# Test if the app can start
echo "🧪 Testing application startup..."
if bundle exec ruby -c app.rb > /dev/null 2>&1; then
  echo "✅ Syntax check passed"
else
  echo "❌ Syntax check failed"
  exit 1
fi

# Restart the application (if using systemd or similar)
echo ""
echo "🔄 To apply changes, restart your application:"
echo "   - Render.com: Will auto-deploy on git push"
echo "   - Local: ctrl+C and restart the server"
echo "   - Production: 'sudo systemctl restart meme-explorer' (or your service name)"
echo ""

echo "✨ Deployment preparation complete!"
echo ""
echo "📊 What this fixes:"
echo "   - SESSION END errors"
echo "   - SESSION METRICS errors"
echo "   - 'undefined method []' for Rack::Session::SessionId"
echo ""
echo "🎯 Root cause: Rack sessions return SessionId objects that need"
echo "   to be converted to strings before using string operations."
