#!/usr/bin/env ruby
# Run P1 performance index migrations

require_relative '../db/setup'

puts "=" * 80
puts "Running P1 Performance Index Migrations"
puts "=" * 80
puts ""

sql = File.read('db/migrations/add_p1_performance_indexes.sql')

# Split on semicolons and execute each statement
statements = sql.split(';').map(&:strip).reject { |s| s.empty? || s.start_with?('--') }

success_count = 0
error_count = 0

statements.each do |stmt|
  begin
    DB.execute(stmt)
    # Extract index name for logging
    index_name = stmt[/CREATE INDEX[^)]*idx_\w+/i]
    puts "✓ Created: #{index_name}" if index_name
    success_count += 1
  rescue => e
    puts "⚠️  Warning: #{e.message}"
    error_count += 1
  end
end

puts ""
puts "=" * 80
puts "Migration Complete!"
puts "  ✓ Success: #{success_count} indexes"
puts "  ⚠️  Errors: #{error_count}" if error_count > 0
puts "=" * 80
