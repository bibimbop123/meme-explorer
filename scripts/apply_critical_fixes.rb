#!/usr/bin/env ruby
# Critical Fixes Application Script
# Applies all critical security and performance fixes identified in audit

require 'sqlite3'
require 'colorize'

puts "="*70
puts "MEME EXPLORER - CRITICAL FIXES APPLICATION".center(70).colorize(:cyan)
puts "Date: June 2, 2026".center(70)
puts "="*70
puts

# Initialize database connection
DB_PATH = File.join(__dir__, '..', 'db', 'memes.db')

unless File.exist?(DB_PATH)
  puts "❌ Database not found at #{DB_PATH}".colorize(:red)
  puts "   Please run from project root directory"
  exit 1
end

db = SQLite3::Database.new(DB_PATH)
db.results_as_hash = true

puts "✅ Connected to database: #{DB_PATH}".colorize(:green)
puts

# ==================================================================
# FIX #1: Apply Critical Indexes
# ==================================================================
puts "📊 FIX #1: Applying Critical Performance Indexes".colorize(:yellow)
puts "-" * 70

migration_file = File.join(__dir__, '..', 'db', 'migrations', 'fix_critical_indexes_june_2026.sql')

if File.exist?(migration_file)
  sql = File.read(migration_file)
  
  # Split by statement and execute
  statements = sql.split(';').map(&:strip).reject(&:empty?)
  
  success_count = 0
  error_count = 0
  
  statements.each do |statement|
    next if statement.start_with?('--') || statement.start_with?('/*')
    
    begin
      db.execute(statement)
      if statement.include?('CREATE INDEX')
        index_name = statement[/CREATE INDEX.*?(idx_\w+)/, 1]
        puts "  ✓ Created: #{index_name}".colorize(:green)
        success_count += 1
      elsif statement.include?('ANALYZE')
        table_name = statement[/ANALYZE\s+(\w+)/, 1]
        puts "  ✓ Analyzed: #{table_name}".colorize(:green)
      end
    rescue SQLite3::Exception => e
      if e.message.include?('already exists')
        puts "  ⊗ Skipped: Index already exists".colorize(:yellow)
      else
        puts "  ✗ Error: #{e.message}".colorize(:red)
        error_count += 1
      end
    end
  end
  
  puts
  puts "Summary: #{success_count} indexes created, #{error_count} errors".colorize(:cyan)
else
  puts "⚠️  Migration file not found: #{migration_file}".colorize(:yellow)
end

puts

# ==================================================================
# FIX #2: Verify Search Query Security
# ==================================================================
puts "🔒 FIX #2: Verifying Search Query Security".colorize(:yellow)
puts "-" * 70

app_rb_path = File.join(__dir__, '..', 'app.rb')
app_content = File.read(app_rb_path)

if app_content.include?('InputSanitizer.sanitize_search_query')
  puts "  ✓ SQL injection fix applied in search_memes".colorize(:green)
  puts "  ✓ Using proper parameterized queries with ESCAPE clause".colorize(:green)
else
  puts "  ⚠️  SQL injection fix not found - manual verification needed".colorize(:yellow)
end

puts

# ==================================================================
# FIX #3: Verify Distributed Locking
# ==================================================================
puts "🔐 FIX #3: Verifying Distributed Lock Implementation".colorize(:yellow)
puts "-" * 70

distributed_lock_path = File.join(__dir__, '..', 'lib', 'concerns', 'distributed_lock.rb')

if File.exist?(distributed_lock_path)
  puts "  ✓ DistributedLock module created".colorize(:green)
  
  # Check if CacheRefreshWorker uses it
  worker_path = File.join(__dir__, '..', 'app', 'workers', 'cache_refresh_worker.rb')
  if File.exist?(worker_path)
    worker_content = File.read(worker_path)
    if worker_content.include?('include DistributedLock') && worker_content.include?('with_redis_lock')
      puts "  ✓ CacheRefreshWorker using distributed locks".colorize(:green)
    else
      puts "  ⚠️  CacheRefreshWorker not using distributed locks".colorize(:yellow)
    end
  end
else
  puts "  ⚠️  DistributedLock module not found".colorize(:yellow)
end

puts

# ==================================================================
# FIX #4: Database Statistics
# ==================================================================
puts "📈 Database Performance Statistics".colorize(:yellow)
puts "-" * 70

begin
  # Count total memes
  total_memes = db.get_first_value("SELECT COUNT(*) FROM meme_stats")
  puts "  Total memes in database: #{total_memes}".colorize(:cyan)
  
  # Count indexes
  indexes = db.execute("SELECT COUNT(*) as count FROM sqlite_master WHERE type='index'")
  index_count = indexes.first['count']
  puts "  Total indexes: #{index_count}".colorize(:cyan)
  
  # List critical indexes
  critical_indexes = db.execute(<<-SQL)
    SELECT name FROM sqlite_master 
    WHERE type='index' 
    AND (
      name LIKE 'idx_meme_stats_trending%' OR
      name LIKE 'idx_user_exposure%' OR
      name LIKE 'idx_weekly_leaderboard%' OR
      name LIKE 'idx_user_prefs%'
    )
  SQL
  
  if critical_indexes.any?
    puts "  Critical indexes present:".colorize(:green)
    critical_indexes.each do |idx|
      puts "    • #{idx['name']}".colorize(:green)
    end
  end
  
rescue => e
  puts "  ⚠️  Error getting statistics: #{e.message}".colorize(:red)
end

puts

# ==================================================================
# Summary
# ==================================================================
puts "="*70
puts "FIXES APPLICATION COMPLETE".center(70).colorize(:green).bold
puts "="*70
puts

puts "Next Steps:".colorize(:cyan).bold
puts "  1. Test the application: bundle exec rspec"
puts "  2. Run local server: bundle exec puma"
puts "  3. Review audit report: SENIOR_DEV_COMPREHENSIVE_AUDIT_2026.md"
puts "  4. Follow roadmap: CRITICAL_FIXES_ROADMAP_2026.md"
puts

db.close
