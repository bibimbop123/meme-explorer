#!/usr/bin/env ruby
# frozen_string_literal: true

require_relative '../config/application'

puts "=" * 60
puts "Running Observability Migrations (Phase 2)"
puts "=" * 60
puts

begin
  # Run Performance Metrics Migration
  puts "Creating performance_metrics table..."
  migration_sql = File.read(File.join(__dir__, '../db/migrations/add_performance_metrics.sql'))
  DB.run(migration_sql)
  puts "✓ performance_metrics table created"
  puts
  
  # Run Ad Impressions Migration
  puts "Creating ad_impressions table..."
  migration_sql = File.read(File.join(__dir__, '../db/migrations/add_ad_impressions.sql'))
  DB.run(migration_sql)
  puts "✓ ad_impressions table created"
  puts
  
  # Verify tables exist
  puts "Verifying tables..."
  if DB.table_exists?(:performance_metrics)
    puts "✓ performance_metrics exists"
  else
    puts "✗ performance_metrics missing"
  end
  
  if DB.table_exists?(:ad_impressions)
    puts "✓ ad_impressions exists"
  else
    puts "✗ ad_impressions missing"
  end
  
  puts
  puts "=" * 60
  puts "Migration Complete!"
  puts "=" * 60
  puts
  puts "Next steps:"
  puts "1. Restart your application"
  puts "2. Monitor /admin/performance dashboard"
  puts "3. Check /admin/revenue dashboard"
  puts "4. Review logs for performance metrics"
  
rescue => e
  puts "✗ Migration failed: #{e.message}"
  puts e.backtrace.first(5).join("\n")
  exit 1
end
