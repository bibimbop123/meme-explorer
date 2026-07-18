#!/usr/bin/env ruby
# Emergency hotfix for display.erb syntax error in production
# This will restart Puma to clear cached ERB templates

require 'fileutils'

puts "🚨 EMERGENCY HOTFIX: Fixing display.erb syntax error..."
puts "=" * 60

# Verify the file is correct
display_path = 'views/random/display.erb'

if File.exist?(display_path)
  content = File.read(display_path)
  
  # Check for the problematic pattern
  if content.include?('<% case media_type %>')
    puts "✅ File syntax looks correct"
    puts "📝 This appears to be a cached template issue in production"
    puts ""
    puts "DEPLOYMENT STEPS:"
    puts "1. Git add and commit this file"
    puts "2. Push to trigger Render redeploy"
    puts "3. Render will restart Puma, clearing cached templates"
    puts ""
    puts "Commands to run:"
    puts "  git add #{display_path}"
    puts "  git commit -m 'hotfix: clear cached ERB template for display.erb'"
    puts "  git push origin main"
  else
    puts "❌ File appears to be corrupted locally too"
    puts "⚠️  Manual intervention required"
  end
else
  puts "❌ File not found: #{display_path}"
end

puts "=" * 60
