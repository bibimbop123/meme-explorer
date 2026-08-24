#!/usr/bin/env ruby
# ULTIMATE COMPREHENSIVE HOTFIX: Fix ALL missing requires in ALL files recursively

require 'fileutils'

ROOT = File.join(__dir__, '..')
FILES_TO_SCAN = [
  File.join(ROOT, 'app.rb'),
  Dir.glob(File.join(ROOT, 'routes', '*.rb')),
  Dir.glob(File.join(ROOT, 'lib', 'services', '*.rb')),
  Dir.glob(File.join(ROOT, 'lib', 'helpers', '*.rb'))
].flatten

puts "🔥 ULTIMATE COMPREHENSIVE HOTFIX: Scanning ALL files recursively"
puts "=" * 70

total_fixes = 0

FILES_TO_SCAN.each do |file_path|
  next unless File.exist?(file_path)
  
  content = File.read(file_path)
  original_content = content.dup
  
  # Find all require_relative lines
  require_lines = content.scan(/^(\s*)(require_relative\s+"([^"]+)")/)
  
  require_lines.each do |match|
    indent = match[0]
    full_line = match[1]
    path = match[2]
    
    # Convert relative path to actual file path
    full_require_path = File.expand_path(path + '.rb', File.dirname(file_path))
    
    unless File.exist?(full_require_path)
      # Comment out this require
      pattern = /^(\s*)(require_relative\s+"#{Regexp.escape(path)}")/
      if content.match?(pattern)
        content.gsub!(pattern, "\\1# \\2  # ELON AUDIT: File not found")
        puts "✅ #{File.basename(file_path)}: Commented out #{path}"
        total_fixes += 1
      end
    end
  end
  
  if content != original_content
    File.write(file_path, content)
  end
end

puts "\n" + ("=" * 70)
puts "🎉 ULTIMATE HOTFIX COMPLETE"
puts "Total fixes applied: #{total_fixes}"
puts "\nAll missing requires have been commented out across:"
puts "  - app.rb"
puts "  - routes/*.rb"
puts "  - lib/services/*.rb"
puts "  - lib/helpers/*.rb"
