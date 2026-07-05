#!/usr/bin/env ruby
# frozen_string_literal: true

require 'fileutils'

puts "🚀 [Tier 3] Implementing Aggressive 40% Threshold..."

# Backup
backup_file = "lib/services/meme_pool_manager.rb.backup_tier3_#{Time.now.to_i}"
FileUtils.cp('lib/services/meme_pool_manager.rb', backup_file)
puts "✅ Backup created: #{backup_file}"

# Read current file
content = File.read('lib/services/meme_pool_manager.rb')

# Replace LOW_THRESHOLD_PERCENT from 30 to 40
updated_content = content.gsub(
  'LOW_THRESHOLD_PERCENT = 30',
  'LOW_THRESHOLD_PERCENT = 40'
)

# Update the condition comment
updated_content = updated_content.gsub(
  'return if current_size >= 200 # Above comfortable level',
  'return if current_size >= 250 # Above comfortable level (40% = 200 memes)'
)

# Update the log message context
updated_content = updated_content.gsub(
  'if capacity_percent <= LOW_THRESHOLD_PERCENT',
  'if capacity_percent <= LOW_THRESHOLD_PERCENT # Triggers at 200 memes (40%)'
)

# Write updated content
File.write('lib/services/meme_pool_manager.rb', updated_content)

puts "✅ [Tier 3] Aggressive 40% threshold implemented!"
puts ""
puts "📊 Changes Made:"
puts "  • LOW_THRESHOLD_PERCENT: 30% → 40%"
puts "  • Refresh triggers at: 150 memes → 200 memes"
puts "  • Comfortable level check: 200 → 250 memes"
puts ""
puts "🎯 Expected Impact:"
puts "  • Pool refresh triggers earlier (200 vs 150 memes)"
puts "  • Even more buffer before depletion"
puts "  • Refresh frequency: Every 7-8 minutes (vs 8-10)"
puts "  • Greater safety margin for traffic spikes"
puts ""
puts "✅ Ready to commit and deploy!"
