#!/usr/bin/env ruby
# COMPREHENSIVE HOTFIX: Comment out ALL missing files from app.rb

require 'fileutils'

APP_RB = File.join(__dir__, '..', 'app.rb')

puts "🔥 COMPREHENSIVE HOTFIX: Finding ALL missing requires"
puts "=" * 70

content = File.read(APP_RB)
original_content = content.dup

# Find all require_relative lines
require_lines = content.scan(/^require_relative\s+"([^"]+)"/)

missing_files = []
existing_files = []

require_lines.each do |match|
  path = match[0]
  # Convert relative path to actual file path
  full_path = File.join(__dir__, '..', path + '.rb')
  
  if File.exist?(full_path)
    existing_files << path
  else
    missing_files << path
    puts "❌ MISSING: #{path}.rb"
  end
end

puts "\n📊 SUMMARY:"
puts "  Total requires: #{require_lines.length}"
puts "  Existing files: #{existing_files.length}"
puts "  Missing files: #{missing_files.length}"

if missing_files.empty?
  puts "\n✅ No missing files found!"
  exit 0
end

puts "\n🔧 Commenting out missing files..."

missing_files.each do |path|
  pattern = /^(\s*)(require_relative\s+"#{Regexp.escape(path)}")/
  if content.match?(pattern)
    content.gsub!(pattern, "\\1# \\2  # Removed during Elon audit - file not found")
    puts "✅ Commented out: #{path}"
  end
end

# Write back
File.write(APP_RB, content)

puts "\n" + ("=" * 70)
puts "🎉 COMPREHENSIVE HOTFIX COMPLETE"
puts "Fixed #{missing_files.length} missing requires"
puts "\nMissing files were:"
missing_files.each { |f| puts "  - #{f}.rb" }
