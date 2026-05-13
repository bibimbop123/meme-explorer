#!/usr/bin/env ruby
# Run iFunny Features Migration
# Adds tables for smart pools, collaborative filtering, and session learning

require 'sqlite3'
require 'pg' rescue nil

# Determine database type
DB_PATH = File.expand_path('../memes.db', __dir__)
USE_POSTGRES = ENV['DATABASE_URL'] && !ENV['DATABASE_URL'].empty?

def run_migration
  puts "🚀 Running iFunny Features Migration..."
  puts "   Database: #{USE_POSTGRES ? 'PostgreSQL' : 'SQLite'}"
  
  if USE_POSTGRES
    run_postgres_migration
  else
    run_sqlite_migration
  end
  
  puts "✅ Migration complete!"
end

def run_postgres_migration
  require 'pg'
  
  db = PG.connect(ENV['DATABASE_URL'])
  
  migration_file = File.expand_path('../db/migrations/add_ifunny_features.sql', __dir__)
  sql = File.read(migration_file)
  
  db.exec(sql)
  db.close
  
  puts "   ✓ PostgreSQL tables created"
rescue => e
  puts "❌ PostgreSQL migration failed: #{e.message}"
  exit 1
end

def run_sqlite_migration
  db = SQLite3::Database.new(DB_PATH)
  
  # Read and modify SQL for SQLite compatibility
  migration_file = File.expand_path('../db/migrations/add_ifunny_features.sql', __dir__)
  sql = File.read(migration_file)
  
  # Convert PostgreSQL syntax to SQLite
  sql = convert_to_sqlite(sql)
  
  # Execute each statement
  sql.split(';').each do |statement|
    next if statement.strip.empty?
    next if statement.strip.start_with?('--')
    next if statement.include?('CREATE MATERIALIZED VIEW')
    next if statement.include?('CREATE OR REPLACE FUNCTION')
    next if statement.include?('LANGUAGE plpgsql')
    next if statement.include?('COMMENT ON')
    
    begin
      db.execute(statement)
    rescue SQLite3::Exception => e
      # Skip if table already exists
      unless e.message.include?('already exists')
        puts "   ⚠️  Warning: #{e.message}"
      end
    end
  end
  
  db.close
  
  puts "   ✓ SQLite tables created"
rescue => e
  puts "❌ SQLite migration failed: #{e.message}"
  puts e.backtrace.first(5)
  exit 1
end

def convert_to_sqlite(sql)
  # Convert PostgreSQL types to SQLite
  sql.gsub!('SERIAL PRIMARY KEY', 'INTEGER PRIMARY KEY AUTOINCREMENT')
  sql.gsub!('TIMESTAMP WITH TIME ZONE', 'TIMESTAMP')
  sql.gsub!('CURRENT_TIMESTAMP', "datetime('now')")
  sql.gsub!('INTERVAL', '')
  sql.gsub!(/'(\d+) days'/, "'-\\1 days'")
  sql.gsub!('JSONB', 'TEXT')
  sql.gsub!('::FLOAT', '')
  sql.gsub!('::TEXT', '')
  
  # Remove PostgreSQL-specific clauses
  sql.gsub!(/ON CONFLICT.*?DO UPDATE SET.*?;/m) do |match|
    # Convert to INSERT OR REPLACE for simple cases
    match
  end
  
  sql
end

# Run migration
run_migration
