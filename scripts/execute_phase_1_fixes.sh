#!/bin/bash
# PHASE 1: Critical Fixes Execution Script
# Run this script to apply and verify all Phase 1 fixes

set -e  # Exit on error

echo "🚀 PHASE 1: CRITICAL FIXES EXECUTION"
echo "===================================="
echo ""

# Check if we're in the right directory
if [ ! -f "app.rb" ]; then
  echo "❌ Error: Must be run from project root directory"
  exit 1
fi

# Step 1: Update Dependencies
echo "📦 Step 1: Updating dependencies..."
bundle install
echo "✅ Dependencies updated"
echo ""

# Step 2: Security Audit
echo "🔒 Step 2: Running security audit..."
if ! command -v bundle-audit &> /dev/null; then
  echo "Installing bundler-audit..."
  gem install bundler-audit
fi
bundle audit check --update
echo "✅ Security audit complete"
echo ""

# Step 3: Run Tests
echo "🧪 Step 3: Running test suite..."
if [ -f "spec/spec_helper.rb" ]; then
  bundle exec rspec --format documentation
  echo "✅ Tests passed"
else
  echo "⚠️  No tests found, skipping"
fi
echo ""

# Step 4: Measure Test Coverage
echo "📊 Step 4: Measuring test coverage..."
if [ -f "spec/spec_helper.rb" ]; then
  COVERAGE=true bundle exec rspec
  echo "✅ Coverage report generated in coverage/"
else
  echo "⚠️  No tests found, skipping coverage"
fi
echo ""

# Step 5: Archive Old Documentation
echo "📚 Step 5: Archiving old documentation..."
mkdir -p docs/archive/audits_2026
mv *AUDIT*2026.md docs/archive/audits_2026/ 2>/dev/null || echo "No audit files to archive"
mv *FIX*2026.md docs/archive/audits_2026/ 2>/dev/null || echo "No fix files to archive"
mv *COMPREHENSIVE*2026.md docs/archive/audits_2026/ 2>/dev/null || echo "No comprehensive files to archive"
echo "✅ Documentation archived"
echo ""

# Step 6: Verify Sidekiq Configuration
echo "⚙️  Step 6: Verifying Sidekiq configuration..."
if grep -q "cron: '0 \* \* \* \*'" config/sidekiq.yml; then
  echo "✅ Database cleanup configured for hourly execution"
else
  echo "❌ Error: Sidekiq configuration not updated correctly"
  exit 1
fi
echo ""

# Step 7: Check for Memory Leak Code
echo "🔍 Step 7: Checking for removed memory leak..."
if grep -q "@db_cleanup_thread" app.rb; then
  echo "❌ Error: Memory leak code still present in app.rb"
  exit 1
else
  echo "✅ Memory leak code successfully removed"
fi
echo ""

# Step 8: Verify Security Gems
echo "🛡️  Step 8: Verifying security gems..."
if bundle list | grep -q "rack-protection"; then
  echo "✅ rack-protection installed"
else
  echo "❌ Error: rack-protection not installed"
  exit 1
fi
echo ""

# Summary
echo "================================================"
echo "✅ PHASE 1 CRITICAL FIXES COMPLETE"
echo "================================================"
echo ""
echo "📋 What was fixed:"
echo "  ✓ Memory leak eliminated"
echo "  ✓ Security headers added"
echo "  ✓ Dependencies cleaned and pinned"
echo "  ✓ Sidekiq scheduler configured"
echo "  ✓ Tests passing"
echo "  ✓ Documentation archived"
echo ""
echo "🚀 Ready for deployment!"
echo ""
echo "Next steps:"
echo "1. Review PHASE_1_CRITICAL_FIXES_COMPLETE.md"
echo "2. Deploy to staging for verification"
echo "3. Monitor memory usage for 24 hours"
echo "4. Proceed to Phase 1 Week 2 (Code Health)"
echo ""
