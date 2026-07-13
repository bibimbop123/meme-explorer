#!/bin/bash
# Redis Comprehensive Fix Deployment Script
# July 13, 2026 - Senior Ruby Developer
# 
# This script deploys the comprehensive Redis architecture fix
# that resolves empty pool warnings and improves caching reliability

set -e  # Exit on error

echo "🔧 =================================================="
echo "🔧  REDIS COMPREHENSIVE FIX DEPLOYMENT"
echo "🔧 =================================================="
echo ""

# Step 1: Verify we're in the correct directory
if [ ! -f "Gemfile" ]; then
    echo "❌ Error: Must run from project root directory"
    exit 1
fi

echo "✅ Step 1: Verified project root"
echo ""

# Step 2: Check Redis connectivity
echo "📊 Step 2: Checking Redis connectivity..."
if bundle exec ruby -e "require './app'; puts RedisService.ping ? '✅ Redis connected' : '❌ Redis unavailable'"; then
    echo ""
else
    echo "❌ Error: Redis not available. Check REDIS_URL environment variable."
    exit 1
fi

# Step 3: Backup current Redis data (optional but recommended)
echo "💾 Step 3: Creating Redis backup..."
BACKUP_FILE="redis_backup_$(date +%Y%m%d_%H%M%S).json"
bundle exec ruby -e "
require './app'
backup = {
  timestamp: Time.now.to_i,
  pools: {}
}
[:fresh, :trending, :random, :surprise, :diverse].each do |pool|
  key = \"meme_pool:\#{pool}\"
  data = RedisService.get(key)
  backup[:pools][pool] = data if data
end
File.write('tmp/$BACKUP_FILE', backup.to_json)
puts \"✅ Backup saved to tmp/$BACKUP_FILE\"
"
echo ""

# Step 4: Run comprehensive fix script
echo "🔧 Step 4: Running comprehensive Redis fix..."
echo ""
bundle exec ruby scripts/comprehensive_redis_fix_july_13_2026.rb
echo ""

# Step 5: Verify all pools are populated
echo "✅ Step 5: Verifying pool health..."
bundle exec ruby -e "
require './app'

pools = [:fresh, :trending, :random, :surprise, :diverse]
all_healthy = true

pools.each do |pool|
  json_key = \"meme_pool:\#{pool}\"
  list_key = \"meme_pool:\#{pool}_ids\"
  
  json_count = begin
    JSON.parse(RedisService.get(json_key) || '[]').size
  rescue
    0
  end
  
  list_count = RedisService.llen(list_key)
  
  status = (json_count > 0 && list_count > 0) ? '✅' : '❌'
  puts \"  \#{status} \#{pool.to_s.ljust(10)}: JSON=\#{json_count}, Lists=\#{list_count}\"
  
  all_healthy = false if json_count == 0 || list_count == 0
end

puts \"\"
if all_healthy
  puts \"✅ All pools healthy!\"
else
  puts \"⚠️  Some pools unhealthy. Check logs above.\"
  exit 1
end
"
echo ""

# Step 6: Trigger background refresh
echo "🔄 Step 6: Triggering background pool refresh..."
if bundle exec ruby -e "
require './app'
if defined?(MemePoolRefreshWorker)
  MemePoolRefreshWorker.perform_async(true)
  puts '✅ Background refresh queued'
else
  puts '⚠️  Sidekiq not available, skipping'
end
"; then
    echo ""
else
    echo "⚠️  Warning: Could not queue background refresh"
    echo ""
fi

# Step 7: Summary
echo "🎉 =================================================="
echo "🎉  DEPLOYMENT COMPLETE!"
echo "🎉 =================================================="
echo ""
echo "Summary:"
echo "  ✅ Redis connectivity verified"
echo "  ✅ Backup created: tmp/$BACKUP_FILE"
echo "  ✅ Comprehensive fix applied"
echo "  ✅ All 5 pools populated"
echo "  ✅ Dual-format storage active"
echo "  ✅ TTL extended to 6 hours"
echo ""
echo "Next steps:"
echo "  1. Monitor production logs for 'empty pool' warnings"
echo "  2. Check user feedback on content diversity"
echo "  3. Review pool analytics after 24 hours"
echo ""
echo "📝 Full documentation: REDIS_COMPREHENSIVE_AUDIT_FIX_JULY_13_2026.md"
echo ""
