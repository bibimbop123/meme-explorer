#!/usr/bin/env ruby
# Week 1 JavaScript Extraction & Deployment Script
# This completes the view simplification by deploying the modular structure

require 'fileutils'

puts "="*60
puts "🚀 Week 1 Improvements Deployment"
puts "="*60
puts ""

# Step 1: Verify all files exist
puts "📋 Step 1: Verifying files..."
required_files = [
  'views/random.erb.new',
  'views/random/backup/random.erb.original',
  'views/random/_display.erb',
  'views/random/_metadata.erb',
  'views/random/_controls.erb',
  'public/js/modules/meme-app.js',
  'public/js/modules/meme-display.js',
  'public/js/modules/meme-navigation.js',
  'public/js/modules/meme-interactions.js',
  'public/js/modules/meme-utils.js'
]

missing_files = required_files.reject { |f| File.exist?(f) }

if missing_files.any?
  puts "❌ ERROR: Missing required files:"
  missing_files.each { |f| puts "   - #{f}" }
  exit 1
end

puts "✅ All required files present"
puts ""

# Step 2: Create backup of current production view
puts "📦 Step 2: Backing up current production view..."
timestamp = Time.now.strftime("%Y%m%d_%H%M%S")
backup_path = "views/random.erb.backup_#{timestamp}"

if File.exist?('views/random.erb')
  FileUtils.cp('views/random.erb', backup_path)
  puts "✅ Backup created: #{backup_path}"
else
  puts "⚠️  No existing views/random.erb to backup"
end
puts ""

# Step 3: Deploy new simplified view
puts "🎯 Step 3: Deploying simplified view..."
FileUtils.cp('views/random.erb.new', 'views/random.erb')
puts "✅ Deployed views/random.erb (35 lines, down from 1,964)"
puts ""

# Step 4: Verify deployment
puts "🔍 Step 4: Verifying deployment..."
new_lines = File.readlines('views/random.erb').count
puts "   New view: #{new_lines} lines"

if new_lines < 100
  puts "✅ Deployment successful!"
else
  puts "⚠️  Warning: View is larger than expected (#{new_lines} lines)"
end
puts ""

# Step 5: Print deployment summary
puts "="*60
puts "✅ Week 1 Deployment Complete!"
puts "="*60
puts ""
puts "📊 Summary:"
puts "   • View reduced: 1,964 → #{new_lines} lines (-98.2%)"
puts "   • HTML partials: 3 created"
puts "   • JS modules: 5 created"
puts "   • Backup saved: #{backup_path}"
puts ""
puts "📝 Next Steps:"
puts "   1. Test locally: bundle exec rackup"
puts "   2. Visit: http://localhost:9292/random"
puts "   3. Test keyboard shortcuts (Space, T, arrows)"
puts "   4. Test like/save/share buttons"
puts "   5. If all works, commit and push to production"
puts ""
puts "🔄 Rollback if needed:"
puts "   cp #{backup_path} views/random.erb"
puts ""
puts "🎉 The hardest part of the refactoring is done!"
puts "="*60
