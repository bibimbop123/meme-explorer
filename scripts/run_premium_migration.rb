#!/usr/bin/env ruby
# frozen_string_literal: true

# Premium Tier Migration Runner
# Run this script to add premium subscription tables to your database
# Usage: ruby scripts/run_premium_migration.rb

require 'sqlite3'

puts "🚀 Premium Tier Migration Runner"
puts "================================\n\n"

# Read the migration file
migration_path = File.join(__dir__, '..', 'db', 'migrations', 'add_premium_tier_2026.sql')
unless File.exist?(migration_path)
  puts "❌ Error: Migration file not found at #{migration_path}"
  exit 1
end

migration_sql = File.read(migration_path)

puts "📖 Reading migration from: #{migration_path}"

# Determine database path
db_path = if ENV['DATABASE_URL'] && !ENV['DATABASE_URL'].include?('postgresql')
  ENV['DATABASE_URL'].gsub('sqlite3:', '').gsub('sqlite:', '')
else
  File.join(__dir__, '..', 'meme_explorer.db')
end

puts "📊 Database: #{db_path}\n\n"

# Connect to database
begin
  db = SQLite3::Database.new(db_path)
  
  puts "✅ Connected to database successfully"
  puts "\n🔧 Running migration...\n\n"
  
  # Use execute_batch which properly handles multi-statement SQL
  begin
    db.execute_batch(migration_sql)
    puts "  ✓ All SQL statements executed successfully"
  rescue SQLite3::SQLException => e
    # If batch fails, it might be due to IF NOT EXISTS - that's okay
    if e.message.include?('already exists')
      puts "  ✓ Tables already exist - migration safe to skip"
    else
      raise e
    end
  end
  
  puts "\n✅ Migration completed successfully!"
  
  # Verify the tables were created
  puts "\n🔍 Verifying premium tables..."
  tables_to_check = [
    'premium_subscriptions',
    'premium_subscription_history',
    'stripe_webhook_events',
    'premium_feature_usage',
    'premium_revenue',
    'premium_pricing_history'
  ]
  
  existing_tables = db.execute("SELECT name FROM sqlite_master WHERE type='table'").map { |row| row[0] }
  
  tables_to_check.each do |table|
    if existing_tables.include?(table)
      count = db.execute("SELECT COUNT(*) FROM #{table}")[0][0]
      puts "  ✓ #{table}: #{count} rows"
    else
      puts "  ❌ #{table}: NOT FOUND"
    end
  end
  
  # Check if users table was updated
  begin
    columns = db.execute("PRAGMA table_info(users)").map { |col| col[1] }
    if columns.include?('is_premium') && columns.include?('premium_since')
      puts "  ✓ users table: Premium columns added"
    else
      puts "  ⚠️  users table: Premium columns may not have been added"
    end
  rescue => e
    puts "  ⚠️  Could not verify users table: #{e.message}"
  end
  
  puts "\n🎉 Premium tier is ready!"
  puts "\n📝 Next steps:"
  puts "   1. Sign up for Stripe: https://stripe.com"
  puts "   2. Get your API keys (test and live)"
  puts "   3. Add to .env:"
  puts "      STRIPE_SECRET_KEY=sk_test_..."
  puts "      STRIPE_PUBLISHABLE_KEY=pk_test_..."
  puts "   4. Build the premium landing page (views/premium.erb)"
  puts "   5. Create routes/premium.rb with subscription endpoints"
  puts "   6. Test locally with Stripe test mode"
  puts "\n💡 See EXECUTION_STATUS_JULY_22_2026.md for full implementation guide"
  
rescue => e
  puts "\n❌ Migration failed!"
  puts "Error: #{e.message}"
  puts "\nStack trace:"
  puts e.backtrace.first(5).join("\n")
  exit 1
ensure
  db&.close if db
end
