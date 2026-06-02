#!/usr/bin/env ruby
# Script to fix app.class:: references to MemeExplorer::App::
# This fixes the NameError: uninitialized constant Class::MEME_CACHE issue

require 'fileutils'

# Files to fix
files_to_fix = [
  'routes/admin.rb',
  'routes/battles.rb',
  'routes/admin_routes.rb',
  'routes/memes.rb',
  'routes/metrics_routes.rb',
  'routes/profile_routes.rb',
  'routes/trending_routes.rb',
  'routes/home.rb'
]

puts "🔧 Fixing app.class:: references to MemeExplorer::App::"
puts "=" * 60

files_to_fix.each do |file_path|
  full_path = File.join(Dir.pwd, file_path)
  
  unless File.exist?(full_path)
    puts "⚠️  File not found: #{file_path}"
    next
  end
  
  content = File.read(full_path)
  original_content = content.dup
  
  # Replace all instances of app.class:: with MemeExplorer::App::
  content.gsub!(/app\.class::/, 'MemeExplorer::App::')
  
  if content != original_content
    # Create backup
    backup_path = "#{full_path}.backup_#{Time.now.to_i}"
    FileUtils.cp(full_path, backup_path)
    
    # Write fixed content
    File.write(full_path, content)
    
    changes_count = original_content.scan(/app\.class::/).length
    puts "✅ #{file_path}: Fixed #{changes_count} reference(s)"
    puts "   Backup: #{File.basename(backup_path)}"
  else
    puts "⏭️  #{file_path}: No changes needed"
  end
end

puts "=" * 60
puts "✅ All constant references have been fixed!"
puts ""
puts "Summary:"
puts "  - Changed: app.class::MEME_CACHE → MemeExplorer::App::MEME_CACHE"
puts "  - Changed: app.class::DB → MemeExplorer::App::DB"
puts "  - Changed: app.class::METRICS → MemeExplorer::App::METRICS"
puts "  - Changed: app.class::POPULAR_SUBREDDITS → MemeExplorer::App::POPULAR_SUBREDDITS"
puts "  - Changed: app.class::MEMES → MemeExplorer::App::MEMES"
puts ""
puts "⚠️  Please test the application before deploying to production."
