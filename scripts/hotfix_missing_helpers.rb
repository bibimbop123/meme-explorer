#!/usr/bin/env ruby
# PRODUCTION HOTFIX: Comment out all missing helper files from app.rb

require 'fileutils'

APP_RB = File.join(__dir__, '..', 'app.rb')

# Missing helpers that need to be commented out
MISSING_HELPERS = [
  'gamification_helpers',
  'seo_helpers',
  'curated_collections_helper',
  'refined_meme_helper',
  'session_stats_helper'
]

puts "🔥 HOTFIX: Commenting out missing helpers from app.rb"
puts "=" * 60

content = File.read(APP_RB)
original_content = content.dup

# Comment out require_relative lines for missing helpers
MISSING_HELPERS.each do |helper|
  pattern = /^(\s*)(require_relative\s+"\.\/lib\/helpers\/#{helper}")/
  if content.match?(pattern)
    content.gsub!(pattern, "\\1# \\2  # Removed during Elon audit")
    puts "✅ Commented out require: lib/helpers/#{helper}.rb"
  end
end

# Comment out helpers registrations
MISSING_HELPERS.each do |helper|
  # Convert snake_case to CamelCase for module name
  module_name = helper.split('_').map(&:capitalize).join
  
  pattern = /^(\s*)(helpers\s+#{module_name})/
  if content.match?(pattern)
    content.gsub!(pattern, "\\1# \\2  # Removed during Elon audit")
    puts "✅ Commented out helper: #{module_name}"
  end
end

# Write back
if content != original_content
  File.write(APP_RB, content)
  puts "\n✅ app.rb updated successfully"
  puts "\nChanged lines:"
  puts content.scan(/^.*# Removed during Elon audit.*$/).join("\n")
else
  puts "\n⚠️  No changes needed"
end

puts "\n" + ("=" * 60)
puts "🎉 HOTFIX COMPLETE - Ready to push"
