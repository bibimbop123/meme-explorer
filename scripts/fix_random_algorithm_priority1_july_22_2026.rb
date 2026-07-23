#!/usr/bin/env ruby
# Fix Random Algorithm - Priority 1 Critical Issues
# Date: July 22, 2026
# Based on: RANDOM_ALGORITHM_COMPREHENSIVE_AUDIT_SENIOR_DEV_JULY_22_2026.md

require 'fileutils'

puts "=" * 80
puts "RANDOM ALGORITHM PRIORITY 1 FIXES"
puts "=" * 80
puts ""

# Track all changes
changes = []

# ============================================================================
# FIX 1: Syntax Error in MemeSelectionService (Missing `end` on line 83)
# ============================================================================
puts "Fix 1: Fixing MemeSelectionService syntax error..."

file_path = 'lib/services/meme_selection_service.rb'
content = File.read(file_path)

# Add missing `end` after select_random_meme method
fixed_content = content.sub(
  /def select_random_meme\(memes, session_id: nil, preferences: \{\}, \*\*_opts\)\n\s+select\(memes,\n\s+strategy:\s+:intelligent,\n\s+session_id:\s+session_id,\n\s+preferences: preferences\)\n\n\s+# Main selection interface/m,
  "def select_random_meme(memes, session_id: nil, preferences: {}, **_opts)\n    select(memes,\n           strategy:    :intelligent,\n           session_id:  session_id,\n           preferences: preferences)\n  end\n\n  # Main selection interface"
)

if fixed_content != content
  File.write(file_path, fixed_content)
  changes << "✅ Fixed MemeSelectionService syntax error (added missing `end`)"
  puts "   ✓ Added missing `end` statement"
else
  puts "   ⚠ No changes needed (already fixed or pattern not found)"
end

# ============================================================================
# FIX 2: Syntax Error in ContextualScoringService (Missing `end` on line 126)
# ============================================================================
puts "\nFix 2: Fixing ContextualScoringService syntax error..."

file_path = 'lib/services/contextual_scoring_service.rb'
content = File.read(file_path)

# Add missing `end` after calculate_contextual_boost method  
fixed_content = content.sub(
  /combined_boost\n\s+rescue => e\n\s+AppLogger\.warn\("\[ContextualScoring\] Error calculating boost: #\{e\.message\}"\)\n\s+1\.0 # Fail gracefully\n\n\s+# Get current time period\n\s+def get_time_period/m,
  "combined_boost\n    rescue => e\n      AppLogger.warn(\"[ContextualScoring] Error calculating boost: \#{e.message}\")\n      1.0 # Fail gracefully\n    end\n\n    # Get current time period\n    def get_time_period"
)

if fixed_content != content
  File.write(file_path, fixed_content)
  changes << "✅ Fixed ContextualScoringService syntax error (added missing `end`)"
  puts "   ✓ Added missing `end` statement"
else
  puts "   ⚠ No changes needed (already fixed or pattern not found)"
end

# ============================================================================
# FIX 3: SimpleMemeSelector Logic Bug (Line 42-52 scope issue)
# ============================================================================
puts "\nFix 3: Fixing SimpleMemeSelector logic bug..."

file_path = 'lib/services/simple_meme_selector.rb'
content = File.read(file_path)

# Fix the scope issue - move the empty check outside reject block
fixed_content = content.sub(
  /# 1. Filter out previously seen memes\n\s+seen = ViewingHistoryService\.get_seen_memes\(session_id\)\n\s+unseen = all_memes\.reject do \|meme\|\n\s+meme_id = meme\['url'\] \|\| meme\[:url\] \|\| meme\['id'\] \|\| meme\[:id\]\n\s+seen\.include\?\(meme_id\.to_s\)\n\s+\n\s+# 2. Reset if everything has been seen\n\s+if unseen\.empty\?\s+# ← This check is INSIDE the reject block! 🔥\n\s+AppLogger\.info\("\[SimpleMemeSelector\] User #\{session_id\} has seen all #\{all_memes\.size\} memes - resetting history"\)\n\s+ViewingHistoryService\.clear_history\(session_id\)\n\s+unseen = all_memes\n\s+end/m,
  "# 1. Filter out previously seen memes\n      seen = ViewingHistoryService.get_seen_memes(session_id)\n      unseen = all_memes.reject do |meme|\n        meme_id = meme['url'] || meme[:url] || meme['id'] || meme[:id]\n        seen.include?(meme_id.to_s)\n      end\n      \n      # 2. Reset if everything has been seen\n      if unseen.empty?\n        AppLogger.info(\"[SimpleMemeSelector] User \#{session_id} has seen all \#{all_memes.size} memes - resetting history\")\n        ViewingHistoryService.clear_history(session_id)\n        unseen = all_memes\n      end"
)

if fixed_content != content
  File.write(file_path, fixed_content)
  changes << "✅ Fixed SimpleMemeSelector logic bug (moved empty check outside reject block)"
  puts "   ✓ Moved empty check outside reject block"
else
  puts "   ⚠ No changes needed (already fixed or pattern not found)"
end

# ============================================================================
# FIX 4: Thread Leak in RedisService
# ============================================================================
puts "\nFix 4: Fixing RedisService thread leak..."

file_path = 'lib/services/redis_service.rb'
content = File.read(file_path)

# Replace Thread.new with Concurrent::ScheduledTask
fixed_content = content.sub(
  /# Schedule availability re-check after 30 seconds \(named thread — intentional long-lived\)\n\s+@reconnect_thread = Thread\.new do\n\s+Thread\.current\.name = 'redis-reconnect'\n\s+sleep 30\n\s+refresh_availability!\n\s+AppLogger\.info\("Redis availability re-checked", available: @redis_available\)\n\s+end\n\s+@reconnect_thread\.abort_on_exception = false/m,
  "# Schedule availability re-check after 30 seconds using Concurrent::ScheduledTask\n      Concurrent::ScheduledTask.execute(30) do\n        refresh_availability!\n        AppLogger.info(\"Redis availability re-checked\", available: @redis_available)\n      end"
)

if fixed_content != content
  File.write(file_path, fixed_content)
  changes << "✅ Fixed RedisService thread leak (replaced Thread.new with Concurrent::ScheduledTask)"
  puts "   ✓ Replaced Thread.new with Concurrent::ScheduledTask"
else
  puts "   ⚠ No changes needed (already fixed or pattern not found)"
end

# ============================================================================
# Summary
# ============================================================================
puts "\n" + "=" * 80
puts "SUMMARY"
puts "=" * 80

if changes.empty?
  puts "No changes were made. Files may already be fixed or patterns not found."
  puts "\nPlease manually verify the following files:"
  puts "  - lib/services/meme_selection_service.rb"
  puts "  - lib/services/contextual_scoring_service.rb"
  puts "  - lib/services/simple_meme_selector.rb"
  puts "  - lib/services/redis_service.rb"
else
  puts "\nChanges Applied:"
  changes.each { |change| puts "  #{change}" }
  
  puts "\n✅ Priority 1 fixes completed!"
  puts "\nNext Steps:"
  puts "  1. Test the application: bundle exec ruby app.rb"
  puts "  2. Verify no syntax errors: ruby -c lib/services/*.rb"
  puts "  3. Run tests if available: bundle exec rspec"
  puts "  4. Review RANDOM_ALGORITHM_COMPREHENSIVE_AUDIT_SENIOR_DEV_JULY_22_2026.md for Priority 2 fixes"
end

puts "\n" + "=" * 80
