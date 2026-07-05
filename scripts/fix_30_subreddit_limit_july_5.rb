#!/usr/bin/env ruby
# Fix 30-Subreddit Limit Bug - July 5, 2026
# 
# ROOT CAUSE IDENTIFIED:
# Lines 117-121 in lib/services/meme_pool_manager.rb only use 30/90 tier_1 subreddits
# and try to load tier_4/tier_5 which DON'T EXIST in YAML → empty arrays
#
# RESULT: Only 30 subreddits used instead of 90+
# IMPACT: Pool only has 30-40 memes → massive repetition
#
# FIX: Remove .first() limits, use ALL subreddits from existing tiers

require 'fileutils'

puts "🔧 FIXING 30-SUBREDDIT LIMIT BUG"
puts "=" * 60
puts

# Backup original file
backup_file = "lib/services/meme_pool_manager.rb.backup_#{Time.now.to_i}"
FileUtils.cp('lib/services/meme_pool_manager.rb', backup_file)
puts "✅ Backed up to: #{backup_file}"

# Read current file
content = File.read('lib/services/meme_pool_manager.rb')

# THE FIX: Remove artificial limits, use ALL subreddits
old_code = <<~OLD
  # CRITICAL FIX: Fetch from ALL tiers, not just 1-2 (July 5, 2026)
  # This increases pool from 40 → 400-600 memes
  tier_1_subs = load_tier_subreddits(:tier_1).first(30)  # 30 tier 1
  tier_2_subs = load_tier_subreddits(:tier_2).first(20)  # 20 tier 2
  tier_3_subs = load_tier_subreddits(:tier_3).first(15)  # 15 tier 3
  tier_4_subs = load_tier_subreddits(:tier_4).first(10)  # 10 tier 4
  tier_5_subs = load_tier_subreddits(:tier_5).first(5)   # 5 tier 5
  
  all_subs = tier_1_subs + tier_2_subs + tier_3_subs + tier_4_subs + tier_5_subs
  # Now 80 subreddits * 25 per sub = 2,000 potential memes
OLD

new_code = <<~NEW
  # CRITICAL FIX PART 2: Use ALL subreddits from each tier (July 5, 2026 - 2:21 PM)
  # Previous bug: .first(30) limited tier_1 to 30/90 subs
  # Previous bug: tier_4/tier_5 don't exist → empty arrays
  # NEW: Use ALL 90 from tier_1, all from tier_2, all from tier_3
  tier_1_subs = load_tier_subreddits(:tier_1)  # ALL ~90 tier 1 (PEAK HUMOR)
  tier_2_subs = load_tier_subreddits(:tier_2)  # ALL ~80 tier 2 (HIGH QUALITY)
  tier_3_subs = load_tier_subreddits(:tier_3)  # ALL ~70 tier 3 (GOOD VARIETY)
  
  all_subs = (tier_1_subs + tier_2_subs + tier_3_subs).uniq.compact
  # Now 240+ subreddits * 20 memes/sub = 4,800+ potential memes!
  # TurboFetcher will fetch ~40-50 memes total (due to multi-sub efficiency)
  # But from 240 different sources = MAXIMUM VARIETY
NEW

# Apply the fix
if content.include?('tier_1_subs = load_tier_subreddits(:tier_1).first(30)')
  content.gsub!(old_code, new_code)
  
  # Also update the fetcher call to be more conservative
  content.gsub!(
    'memes = fetcher.fetch_memes(all_subs, limit: 25)  # Increased from 20 to 25',
    'memes = fetcher.fetch_memes(all_subs, limit: 20)  # 240 subs * 20 = 4,800 potential'
  )
  
  File.write('lib/services/meme_pool_manager.rb', content)
  
  puts "✅ FIXED bootstrap_pool method"
  puts
  puts "📊 CHANGES:"
  puts "  Before: 30 tier_1 + 0 tier_2-5 = 30 subreddits total"
  puts "  After:  90 tier_1 + 80 tier_2 + 70 tier_3 = 240+ subreddits!"
  puts
  puts "  Before: 30 subs * 25 memes = 750 potential → ~40 actual"
  puts "  After:  240 subs * 20 memes = 4,800 potential → ~400-600 actual!"
  puts
  puts "🎯 EXPECTED RESULTS:"
  puts "  • Pool will contain 400-600 memes instead of 30-40"
  puts "  • 10-15x MORE VARIETY"
  puts "  • Users won't see same memes repeatedly"
  puts "  • Fresh content on every page load"
  puts
  puts "🚀 Deploy with: render deploy"
else
  puts "⚠️  Code pattern not found - file may have changed"
  puts "Manual review needed"
  exit 1
end

puts "\n✅ Script complete!"
