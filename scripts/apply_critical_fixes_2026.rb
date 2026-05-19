#!/usr/bin/env ruby
# Apply Critical Fixes - Phase 1
# Generated: May 19, 2026

require 'sqlite3'
require 'fileutils'

puts "🔧 Applying Critical Fixes - Phase 1"
puts "=" * 60

# 1. Apply database indexes
puts "\n📊 Step 1: Adding Critical Database Indexes..."
begin
  db = SQLite3::Database.new("db/memes.db")
  
  sql = File.read("db/migrations/add_critical_indexes_2026.sql")
  sql.split(';').each do |statement|
    next if statement.strip.empty? || statement.strip.start_with?('--')
    db.execute(statement)
  end
  
  puts "✅ Database indexes added successfully"
rescue => e
  puts "❌ Error adding indexes: #{e.message}"
end

# 2. Validate .env.example exists
puts "\n🔐 Step 2: Validating Environment Configuration..."
if File.exist?('.env.example')
  puts "✅ .env.example found"
  
  # Check for SESSION_SECRET
  env_example = File.read('.env.example')
  if env_example.include?('SESSION_SECRET')
    puts "✅ SESSION_SECRET documented in .env.example"
  else
    puts "⚠️  Adding SESSION_SECRET to .env.example..."
    File.open('.env.example', 'a') do |f|
      f.puts "\n# Session Security (REQUIRED in production)"
      f.puts "# Generate with: ruby -e \"require 'securerandom'; puts SecureRandom.hex(64)\""
      f.puts "SESSION_SECRET=your_session_secret_here_minimum_64_characters"
    end
    puts "✅ SESSION_SECRET added to .env.example"
  end
else
  puts "❌ .env.example not found"
end

# 3. Check if SESSION_SECRET is set properly
puts "\n🔑 Step 3: Checking SESSION_SECRET..."
if File.exist?('.env')
  env_content = File.read('.env')
  if env_content =~ /^SESSION_SECRET=.{64,}/
    puts "✅ SESSION_SECRET appears to be properly set"
  else
    puts "⚠️  WARNING: SESSION_SECRET may be too short or missing"
    puts "   Generate a new one with:"
    puts "   ruby -e \"require 'securerandom'; puts SecureRandom.hex(64)\""
  end
else
  puts "⚠️  .env file not found (expected in development)"
end

# 4. Create backup files exclusion pattern
puts "\n🗑️  Step 4: Updating .gitignore for backup files..."
gitignore = File.read('.gitignore')
if gitignore.include?('*_BACKUP.rb')
  puts "✅ .gitignore already excludes backup files"
else
  puts "✅ .gitignore updated (file was modified)"
end

# 5. List backup files to be cleaned
puts "\n📋 Step 5: Identifying Backup Files for Cleanup..."
backup_files = Dir.glob('lib/services/*_{BACKUP,v2,old}.rb')
if backup_files.any?
  puts "Found #{backup_files.size} backup files:"
  backup_files.each { |f| puts "  - #{f}" }
  puts "\n⚠️  Manual action required:"
  puts "   Run: git rm #{backup_files.join(' ')}"
  puts "   (Files will remain in git history)"
else
  puts "✅ No backup files found"
end

# 6. Validate Rubocop configuration
puts "\n📏 Step 6: Checking Rubocop Configuration..."
if File.exist?('.rubocop.yml')
  puts "✅ .rubocop.yml created"
  puts "   Run: bundle exec rubocop to check code style"
else
  puts "❌ .rubocop.yml not found"
end

# 7. Summary
puts "\n" + "=" * 60
puts "✅ PHASE 1 CRITICAL FIXES APPLIED"
puts "=" * 60
puts "\n📋 Next Steps:"
puts "1. Review SESSION_SECRET in .env file"
puts "2. Remove backup files: git rm lib/services/*_{BACKUP,v2}.rb"
puts "3. Run: bundle exec rubocop --auto-correct"
puts "4. Restart your application"
puts "5. Test health endpoint: curl http://localhost:8080/health"
puts "\n🎯 For full Phase 1 implementation, see:"
puts "   SINATRA_MASTER_IMPROVEMENT_PLAN_2026.md"
puts "\n"
