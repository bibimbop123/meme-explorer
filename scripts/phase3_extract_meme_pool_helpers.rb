#!/usr/bin/env ruby
# Phase 3: Extract Meme Pool Helpers from app.rb
# This script removes the meme pool helper methods from app.rb since they're now in lib/helpers/meme_pool_helpers.rb

require 'fileutils'

APP_RB = 'app.rb'
BACKUP_DIR = 'backups/phase3_meme_pool_helpers'

puts "🔧 Phase 3 - Step 1: Extracting Meme Pool Helpers"
puts "=" * 60

# Create backup
FileUtils.mkdir_p(BACKUP_DIR)
backup_file = "#{BACKUP_DIR}/app_#{Time.now.strftime('%Y%m%d_%H%M%S')}.rb"
FileUtils.cp(APP_RB, backup_file)
puts "✅ Backup created: #{backup_file}"

# Read app.rb
content = File.read(APP_RB)
original_lines = content.lines.count
puts "📊 Original file: #{original_lines} lines"

# Methods to remove (with their line ranges based on subagent analysis)
methods_to_remove = [
  { name: 'get_intelligent_pool', start: 586, end: 630 },
  { name: 'apply_user_preferences', start: 633, end: 658 },
  { name: 'get_time_based_pools', start: 817, end: 838 },
  { name: 'get_trending_pool', start: 1035, end: 1045 },
  { name: 'get_fresh_pool', start: 1047, end: 1053 },
  { name: 'get_exploration_pool', start: 1055, end: 1061 },
  { name: 'random_memes_pool', start: 1065, end: 1106 }
]

# Step 1: Add require statement after other helper requires
require_line = 'require_relative "./lib/helpers/meme_pool_helpers"'
unless content.include?(require_line)
  # Find the line with app_helpers require
  content.sub!(/require_relative "\.\/lib\/helpers\/app_helpers"/, 
                "require_relative \"./lib/helpers/app_helpers\"\n#{require_line}")
  puts "✅ Added require statement for meme_pool_helpers"
end

# Step 2: Register the helper module
register_line = '  helpers MemePoolHelpers'
unless content.include?(register_line)
  # Add after "helpers AppHelpers"
  content.sub!(/helpers AppHelpers/, "helpers AppHelpers\n#{register_line}")
  puts "✅ Registered MemePoolHelpers module"
end

# Step 3: Remove methods in reverse order (to maintain line numbers)
lines = content.lines
methods_to_remove.reverse.each do |method|
  # Find the method start
  method_line = lines.find_index { |line| line.include?("def #{method[:name]}") }
  
  if method_line
    # Find the method end (matching 'end' with proper indentation)
    indent = lines[method_line][/^\s*/]
    end_line = method_line
    open_blocks = 1
    
    (method_line + 1...lines.length).each do |i|
      line = lines[i]
      open_blocks += 1 if line =~ /\b(def|do|begin|class|module|if|unless|while|until|for|case)\b/
      open_blocks -= 1 if line.strip == 'end' || line =~ /^#{indent}end\s*$/
      
      if open_blocks == 0
        end_line = i
        break
      end
    end
    
    # Remove the method (including any blank lines after)
    while end_line + 1 < lines.length && lines[end_line + 1].strip.empty?
      end_line += 1
    end
    
    lines.slice!(method_line..end_line)
    puts "✅ Removed #{method[:name]} (#{end_line - method_line + 1} lines)"
  else
    puts "⚠️  Method #{method[:name]} not found"
  end
end

# Write back
content = lines.join
File.write(APP_RB, content)

new_lines = content.lines.count
removed_lines = original_lines - new_lines

puts "\n" + "=" * 60
puts "📊 Results:"
puts "   Original: #{original_lines} lines"
puts "   New:      #{new_lines} lines"
puts "   Removed:  #{removed_lines} lines"
puts "\n✅ Phase 3 Step 1 Complete!"
puts "   Meme Pool Helpers extracted to lib/helpers/meme_pool_helpers.rb"
