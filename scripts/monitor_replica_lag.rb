#!/usr/bin/env ruby
# frozen_string_literal: true

# Monitor Database Replica Lag
# Usage: ruby scripts/monitor_replica_lag.rb

require_relative '../config/application'

puts "Database Replica Monitoring"
puts "=" * 60
puts ""

if ENV['DATABASE_REPLICA_URL']
  puts "Primary Database: #{ENV['DATABASE_URL'][0..50]}..."
  puts "Replica Database: #{ENV['DATABASE_REPLICA_URL'][0..50]}..."
  puts ""
  
  loop do
    begin
      lag = DatabaseRouter.replica_lag
      
      if lag
        status = case lag
                when 0..1 then "✅ Excellent"
                when 1..5 then "✓ Good"
                when 5..10 then "⚠️  Warning"
                else "❌ Critical"
                end
        
        puts "[#{Time.now.strftime('%H:%M:%S')}] Replica Lag: #{lag.round(2)}s #{status}"
      else
        puts "[#{Time.now.strftime('%H:%M:%S')}] ❌ Unable to check replica lag"
      end
      
      # Check if replica is enabled
      if DatabaseRouter.instance_variable_get(:@replica_disabled)
        puts "[#{Time.now.strftime('%H:%M:%S')}] ⚠️  Replica is DISABLED"
      end
      
    rescue => e
      puts "[#{Time.now.strftime('%H:%M:%S')}] ❌ Error: #{e.message}"
    end
    
    sleep 10
  end
else
  puts "❌ No replica configured (DATABASE_REPLICA_URL not set)"
  puts ""
  puts "To configure a replica:"
  puts "  1. Set up a read replica in your database provider"
  puts "  2. Add DATABASE_REPLICA_URL to your environment"
  puts "  3. Restart the application"
end
