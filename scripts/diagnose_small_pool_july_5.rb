#!/usr/bin/env ruby
# frozen_string_literal: true

puts "🔍 [CRITICAL] Diagnosing Why Pool is Only 90 Memes..."
puts ""

# Check current configuration
puts "📊 Current Configuration Check:"
puts "================================"

file_content = File.read('lib/services/meme_pool_manager.rb')

if file_content =~ /TIER_1_SUBS\s*=\s*(\d+)/
  tier1 = $1.to_i
  puts "✅ TIER_1_SUBS = #{tier1}"
else
  puts "❌ TIER_1_SUBS not found!"
end

if file_content =~ /BOOTSTRAP_LIMIT\s*=\s*(\d+)/
  limit = $1.to_i
  puts "✅ BOOTSTRAP_LIMIT = #{limit}"
else
  puts "❌ BOOTSTRAP_LIMIT not found!"
end

if file_content =~ /LOW_THRESHOLD_PERCENT\s*=\s*(\d+)/
  threshold = $1.to_i
  puts "✅ LOW_THRESHOLD_PERCENT = #{threshold}%"
else
  puts "❌ LOW_THRESHOLD_PERCENT not found!"
end

puts ""
puts "🎯 Expected Pool Size: #{tier1 * 15}-#{tier1 * 20} memes"
puts "📊 Actual Pool Size: 90 memes"
puts ""

puts "🔍 Possible Causes:"
puts "1. Validation is rejecting most memes"
puts "2. Deduplication is removing duplicates"
puts "3. Subreddit fetches are returning fewer memes"
puts "4. There's a hard limit somewhere in the code"
puts ""

# Check for any hard limits
puts "🔎 Checking for Hard Limits in Code:"
puts "====================================="

if file_content =~ /\.take\((\d+)\)/
  puts "⚠️  Found .take(#{$1}) - limiting results!"
end

if file_content =~ /\.first\((\d+)\)/
  puts "⚠️  Found .first(#{$1}) - limiting results!"
end

if file_content =~ /MAX_POOL_SIZE\s*=\s*(\d+)/
  puts "⚠️  Found MAX_POOL_SIZE = #{$1}"
end

puts ""
puts "💡 SOLUTION: Need to investigate TurboFetcher and validation pipeline"
puts "The issue is likely in how memes are validated/filtered after fetching"
