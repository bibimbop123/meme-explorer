#!/usr/bin/env ruby
# Boot Time Profiler

require 'benchmark'

puts "\n" + "=" * 60
puts "⏱️  BOOT TIME PROFILER"
puts "=" * 60

time = Benchmark.realtime do
  require_relative '../app'
end

puts "\n📊 Results:"
puts "  Total boot time: #{time.round(2)}s"
puts

if time < 2.0
  puts "  ✅ EXCELLENT: Under 2 seconds"
elsif time < 5.0
  puts "  ⚠️  NEEDS IMPROVEMENT: 2-5 seconds"
else
  puts "  🚨 CRITICAL: Over 5 seconds"
end

puts "\nTarget: <2 seconds"
puts "=" * 60
