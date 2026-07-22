#!/usr/bin/env ruby
# Add role column to users table
# Date: July 22, 2026

require_relative '../app'

puts "🔧 Adding role column to users table..."

begin
  # Read and execute the migration
  migration_sql = File.read('db/migrations/add_role_column_july_22_2026.sql')
  
  # Split by semicolon and execute each statement
  migration_sql.split(';').each do |statement|
    next if statement.strip.empty? || statement.strip.start_with?('--')
    
    MemeExplorer::App::DB.execute(statement.strip)
  end
  
  puts "✅ Role column added successfully!"
  
  # Verify the column exists
  result = MemeExplorer::App::DB.execute(
    "SELECT column_name, data_type, column_default 
     FROM information_schema.columns 
     WHERE table_name = 'users' AND column_name = 'role'"
  )
  
  if result && result.first
    puts "\n📋 Column details:"
    puts "   Name: #{result.first['column_name']}"
    puts "   Type: #{result.first['data_type']}"
    puts "   Default: #{result.first['column_default']}"
  end
  
  puts "\n✅ Migration complete! You can now run: ruby scripts/make_admin.rb"
  
rescue => e
  puts "❌ Error: #{e.message}"
  puts e.backtrace.first(5)
  exit 1
end
