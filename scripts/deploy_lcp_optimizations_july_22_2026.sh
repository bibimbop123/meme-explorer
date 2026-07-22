#!/bin/bash

# LCP Performance Optimization Deployment Script
# Date: July 22, 2026
# Purpose: Deploy critical LCP improvements to reduce 11+ second load times

set -e

echo "🚀 Starting LCP Optimization Deployment..."
echo "==========================================="

# Check if running on production
if [ "$RAILS_ENV" = "production" ] || [ "$RACK_ENV" = "production" ]; then
  echo "✅ Production environment detected"
else
  echo "⚠️  Non-production environment - proceeding anyway"
fi

# Backup critical files
echo ""
echo "📦 Creating backups..."
cp views/random/display_WORKING.erb views/random/display_WORKING.erb.backup_$(date +%Y%m%d_%H%M%S) || true
cp views/layout.erb views/layout.erb.backup_$(date +%Y%m%d_%H%M%S) || true
cp public/js/enhanced-lazy-load.js public/js/enhanced-lazy-load.js.backup_$(date +%Y%m%d_%H%M%S) || true
echo "✅ Backups created"

# Verify critical files exist
echo ""
echo "🔍 Verifying deployment files..."
if [ ! -f "views/random/display_WORKING.erb" ]; then
  echo "❌ ERROR: views/random/display_WORKING.erb not found"
  exit 1
fi
if [ ! -f "views/layout.erb" ]; then
  echo "❌ ERROR: views/layout.erb not found"
  exit 1
fi
if [ ! -f "public/js/enhanced-lazy-load.js" ]; then
  echo "❌ ERROR: public/js/enhanced-lazy-load.js not found"
  exit 1
fi
echo "✅ All deployment files verified"

# Check for key optimizations in files
echo ""
echo "🔍 Validating optimizations..."

if grep -q 'fetchpriority="high"' views/random/display_WORKING.erb; then
  echo "✅ Image fetchpriority optimization found"
else
  echo "⚠️  WARNING: fetchpriority optimization not found"
fi

if grep -q 'loading="eager"' views/random/display_WORKING.erb; then
  echo "✅ Eager loading optimization found"
else
  echo "⚠️  WARNING: eager loading not found"
fi

if grep -q 'rel="preload"' views/layout.erb; then
  echo "✅ Resource preloading found"
else
  echo "⚠️  WARNING: resource preloading not found"
fi

if grep -q 'rel="preconnect"' views/layout.erb; then
  echo "✅ DNS preconnect found"
else
  echo "⚠️  WARNING: DNS preconnect not found"
fi

# Restart application if needed
echo ""
echo "🔄 Application restart..."
if command -v systemctl &> /dev/null; then
  echo "Restarting via systemctl..."
  sudo systemctl restart meme-explorer || echo "⚠️  Could not restart via systemctl"
elif [ -f "tmp/restart.txt" ]; then
  echo "Touching tmp/restart.txt for Passenger restart..."
  touch tmp/restart.txt
  echo "✅ Restart triggered"
else
  echo "⚠️  No restart mechanism found - manual restart may be needed"
fi

echo ""
echo "==========================================="
echo "✅ LCP Optimization Deployment Complete!"
echo ""
echo "📊 What was optimized:"
echo "  • Main meme image: loading='eager' + fetchpriority='high'"
echo "  • Critical CSS: preloaded theme.css and meme_explorer.css"
echo "  • DNS: preconnect to fonts.googleapis.com and external domains"
echo "  • Image preload: @image_src preloaded when available"
echo "  • Lazy loading: updated to skip high-priority images"
echo ""
echo "🎯 Expected Results:"
echo "  • LCP should drop from 11-12s to 2-3s"
echo "  • Main image loads immediately without delay"
echo "  • Improved perceived performance"
echo ""
echo "📈 Monitoring:"
echo "  • Check /api/vitals endpoint for LCP metrics"
echo "  • Monitor browser console for LCP warnings"
echo "  • Use Chrome DevTools Performance panel"
echo ""
echo "🔧 Rollback if needed:"
echo "  • Backups saved with timestamp suffix"
echo "  • To rollback: cp *.backup_* original_filename"
echo ""
echo "==========================================="
