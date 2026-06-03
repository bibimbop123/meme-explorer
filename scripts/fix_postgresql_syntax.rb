#!/usr/bin/env ruby
# frozen_string_literal: true

##
# PostgreSQL Syntax Fix Script
# Converts SQLite-specific syntax to PostgreSQL-compatible syntax
# Run this before deploying to production

require 'fileutils'

puts "🔧 PostgreSQL Syntax Fixer"
puts "=" * 50

# Files to fix
files_to_fix = [
  'lib/services/meme_service.rb',
  'lib/services/user_service.rb',
  'app.rb'
]

# Backup directory
backup_dir = "backups/postgres_syntax_fix_#{Time.now.strftime('%Y%m%d_%H%M%S')}"
FileUtils.mkdir_p(backup_dir)

files_to_fix.each do |file_path|
  next unless File.exist?(file_path)
  
  puts "\n📝 Processing: #{file_path}"
  
  # Backup original
  backup_path = File.join(backup_dir, file_path.gsub('/', '_'))
  FileUtils.cp(file_path, backup_path)
  puts "  ✅ Backed up to: #{backup_path}"
  
  content = File.read(file_path)
  original_content = content.dup
  changes = 0
  
  # Fix 1: INSERT OR IGNORE → INSERT ... ON CONFLICT DO NOTHING
  if content.gsub!(/INSERT OR IGNORE INTO (\w+) \(([\w, ]+)\) VALUES \(([\?, ]+)\)/) do
    table = $1
    columns = $2
    values = $3
    
    # Extract primary key column (usually first column or 'id')
    first_col = columns.split(',').first.strip
    conflict_col = first_col == 'id' ? 'id' : first_col
    
    changes += 1
    "INSERT INTO #{table} (#{columns}) VALUES (#{values}) ON CONFLICT (#{conflict_col}) DO NOTHING"
  end
    puts "  🔄 Fixed INSERT OR IGNORE statements"
  end
  
  # Fix 2: For meme_stats, use url as conflict column
  if content.gsub!(/INSERT INTO meme_stats \(([\w, ]+)\) VALUES \(([\?, ]+)\) ON CONFLICT \(\w+\) DO NOTHING/) do
    columns = $1
    values = $2
    changes += 1
    "INSERT INTO meme_stats (#{columns}) VALUES (#{values}) ON CONFLICT (url) DO NOTHING"
  end
    puts "  🔄 Fixed meme_stats conflict column"
  end
  
  # Fix 3: datetime() functions → date_trunc or interval syntax
  # This is trickier as it needs context
  if content.include?("datetime(")
    puts "  ⚠️  WARNING: File contains datetime() functions - needs manual review"
    puts "     PostgreSQL uses date_trunc() or CURRENT_TIMESTAMP - INTERVAL"
  end
  
  if changes > 0
    File.write(file_path, content)
    puts "  ✅ Applied #{changes} fixes to #{file_path}"
  else
    puts "  ℹ️  No changes needed for #{file_path}"
  end
end

puts "\n" + "=" * 50
puts "✅ PostgreSQL syntax fixes complete!"
puts "📁 Backups saved to: #{backup_dir}"
puts "\n🚀 Next steps:"
puts "  1. Review changes with: git diff"
puts "  2. Run tests: bundle exec rspec"
puts "  3. Deploy to production"
puts "  4. Run migrations: scripts/run_production_migration.rb"
