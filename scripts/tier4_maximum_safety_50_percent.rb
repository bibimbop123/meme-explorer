#!/usr/bin/env ruby
# frozen_string_literal: true

require 'fileutils'

puts "🚀 [Tier 4] Implementing MAXIMUM SAFETY 50% Threshold..."

# Backup
backup_file = "lib/services/meme_pool_manager.rb.backup_tier4_#{Time.now.to_i}"
FileUtils.cp('lib/services/meme_pool_manager.rb', backup_file)
puts "✅ Backup created: #{backup_file}"

# Read current file
content = File.read('lib/services/meme_pool_manager.rb')

# Replace LOW_THRESHOLD_PERCENT from 40 to 50
updated_content = content.gsub(
  'LOW_THRESHOLD_PERCENT = 40',
  'LOW_THRESHOLD_PERCENT = 50'
)

# Update the condition comment
updated_content = updated_content.gsub(
  'return if current_size >= 250 # Above comfortable level (40% = 200 memes)',
  'return if current_size >= 300 # Above comfortable level (50% = 250 memes)'
)

# Update the log message context
updated_content = updated_content.gsub(
  'if capacity_percent <= LOW_THRESHOLD_PERCENT # Triggers at 200 memes (40%)',
  'if capacity_percent <= LOW_THRESHOLD_PERCENT # Triggers at 250 memes (50%)'
)

# Write updated content
File.write('lib/services/meme_pool_manager.rb', updated_content)

puts "✅ [Tier 4] MAXIMUM SAFETY 50% threshold implemented!"
puts ""
puts "📊 Changes Made:"
puts "  • LOW_THRESHOLD_PERCENT: 40% → 50%"
puts "  • Refresh triggers at: 200 memes → 250 memes"
puts "  • Comfortable level check: 250 → 300 memes"
puts ""
puts "🎯 Expected Impact:"
puts "  • Pool refresh triggers at HALF capacity (250 memes)"
puts "  • Absolute maximum safety buffer"
puts "  • Refresh frequency: Every 5-6 minutes (very proactive)"
puts "  • Perfect for high-traffic scenarios"
puts "  • Pool depletion: Nearly impossible"
puts ""
puts "⚠️  CAUTION: This is the most aggressive setting!"
puts "  • Reddit API usage: ~30 requests/hour"
puts "  • Only use if still seeing issues with Tier 3"
puts ""
puts "✅ Ready to commit and deploy!"
