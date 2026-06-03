#!/usr/bin/env ruby
# Phase 1: Quality Score Migration Runner
# Applies quality score tracking to database
# Created: June 3, 2026

require_relative '../lib/db_helpers'
require 'pg'

puts "🔧 Phase 1: Quality Score Migration"
puts "=" * 50

begin
  # Read migration file
  migration_file = File.read('db/migrations/add_quality_score_2026.sql')
  
  puts "📄 Migration file loaded: add_quality_score_2026.sql"
  
  # Execute migration
  puts "⚙️  Executing migration..."
  DB.execute_batch(migration_file)
  
  puts "✅ Migration completed successfully!"
  puts ""
  puts "📊 Quality score column added to meme_stats"
  puts "📈 Indexes created for performance optimization"
  puts "🎯 Existing memes set to default quality score (50.0)"
  
  # Verify the migration
  result = DB.execute("SELECT COUNT(*) as count FROM meme_stats WHERE quality_score IS NOT NULL").first
  puts ""
  puts "✅ Verification: #{result['count']} memes have quality scores"
  
rescue => e
  puts "❌ Migration failed: #{e.message}"
  puts e.backtrace.first(5).join("\n")
  exit 1
end
