#!/usr/bin/env ruby
require_relative '../config/application'

puts "🔧 Applying Phase 1 Critical Indexes..."
puts "Reading migration file..."

migration_file = File.join(__dir__, '..', 'db', 'migrations', 'phase1_critical_indexes_2026.sql')
sql = File.read(migration_file)

puts "Executing index creation (this may take several minutes)..."

begin
  # Split SQL into individual statements (PostgreSQL can't handle all at once with CONCURRENTLY)
  statements = sql.split(/;\s*$/).map(&:strip).reject(&:empty?)
  
  created_count = 0
  statements.each do |statement|
    next if statement.start_with?('--')  # Skip comments
    next if statement.include?('SELECT')  # Skip analysis queries for now
    
    begin
      DB.execute(statement)
      created_count += 1 if statement.include?('CREATE INDEX')
      print "."
    rescue => e
      # Some indexes might already exist, that's okay
      puts "\n⚠️  Warning: #{e.message}" unless e.message.include?('already exists')
    end
  end
  
  puts "\n✅ Successfully created/verified #{created_count} indexes"
  puts "\n📊 Run this query to check index usage:"
  puts "   SELECT schemaname, tablename, indexname FROM pg_stat_user_indexes ORDER BY idx_scan DESC LIMIT 10;"
rescue => e
  puts "\n❌ Error: #{e.message}"
  puts e.backtrace.first(5)
  exit 1
end
