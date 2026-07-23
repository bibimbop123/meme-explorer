#!/usr/bin/env ruby
# Run Database Optimization Migrations
# Week 1 Days 3-4

require 'pg'

def run_migration
  conn = PG.connect(
    host: ENV['DATABASE_HOST'] || 'localhost',
    dbname: ENV['DATABASE_NAME'] || 'meme_explorer_production',
    user: ENV['DATABASE_USER'],
    password: ENV['DATABASE_PASSWORD']
  )
  
  puts "Connected to database: #{conn.db}"
  puts "Running critical indexes migration..."
  
  sql = File.read('db/migrations/add_critical_indexes_week1_2026.sql')
  conn.exec(sql)
  
  puts "✓ Migration completed successfully!"
  puts ""
  puts "Indexes created:"
  result = conn.exec("SELECT indexname FROM pg_indexes WHERE tablename IN ('memes', 'users', 'user_likes', 'viewing_history', 'sessions') ORDER BY indexname")
  result.each { |row| puts "  - #{row['indexname']}" }
  
rescue PG::Error => e
  puts "✗ Migration failed: #{e.message}"
  exit 1
ensure
  conn&.close
end

if __FILE__ == $0
  run_migration
end
