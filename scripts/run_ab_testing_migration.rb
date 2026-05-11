#!/usr/bin/env ruby
# Run A/B Testing Migration
# Creates tables for A/B testing framework

require 'pg'
require 'dotenv/load'

puts "🔄 Running A/B Testing Migration..."

# Get database connection details
database_url = ENV['DATABASE_URL']

if database_url.nil? || database_url.empty?
  puts "❌ ERROR: DATABASE_URL not set"
  exit 1
end

begin
  # Connect to database
  conn = PG.connect(database_url)
  puts "✅ Connected to PostgreSQL database"
  
  # Read migration file
  migration_sql = File.read('db/migrations/add_ab_testing.sql')
  
  # Execute migration
  puts "🔄 Executing migration..."
  conn.exec(migration_sql)
  
  puts "✅ A/B Testing migration completed successfully!"
  puts ""
  puts "📊 Tables created:"
  puts "  - experiments"
  puts "  - experiment_assignments"
  puts "  - experiment_conversions"
  puts ""
  puts "✅ Ready to use A/B Testing framework!"
  
rescue PG::Error => e
  puts "❌ Database error: #{e.message}"
  exit 1
rescue => e
  puts "❌ Error: #{e.message}"
  puts e.backtrace.first(5)
  exit 1
ensure
  conn.close if conn
end
