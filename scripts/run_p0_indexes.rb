#!/usr/bin/env ruby
# Run P0 critical index migrations

require_relative '../db/setup'

puts "Running P0 critical index migrations..."

sql = File.read('db/migrations/add_p0_critical_indexes.sql')

# Split on semicolons and execute each statement
sql.split(';').each do |stmt|
  next if stmt.strip.empty? || stmt.strip.start_with?('--')
  
  begin
    DB.execute(stmt)
    puts "✓ Executed: #{stmt.strip.split("\n").first}"
  rescue => e
    puts "⚠️  Warning: #{e.message}"
  end
end

puts "\n✅ P0 index migrations complete!"
