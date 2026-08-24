#!/usr/bin/env ruby
# Memory Usage Profiler

require 'objspace'

puts "\n" + "=" * 60
puts "💾 MEMORY USAGE PROFILER"
puts "=" * 60

# Measure before loading
ObjectSpace.garbage_collect
before = `ps -o rss= -p #{Process.pid}`.to_i / 1024.0

puts "\nMemory before loading app: #{before.round(1)} MB"

# Load the app
require_relative '../app'

# Measure after loading
ObjectSpace.garbage_collect
after = `ps -o rss= -p #{Process.pid}`.to_i / 1024.0

puts "Memory after loading app:  #{after.round(1)} MB"
puts "\n📊 Increase: #{(after - before).round(1)} MB"
puts

if (after - before) < 300
  puts "✅ EXCELLENT: Under 300 MB"
elsif (after - before) < 500
  puts "⚠️  NEEDS IMPROVEMENT: 300-500 MB"
else
  puts "🚨 CRITICAL: Over 500 MB"
end

puts "\nTarget: <300 MB increase"
puts "=" * 60
