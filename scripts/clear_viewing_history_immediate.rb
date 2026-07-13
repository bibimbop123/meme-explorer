#!/usr/bin/env ruby
# Immediate Workaround: Clear all viewing history
# This resets all sessions so users can see the 10 memes "fresh" again

require 'bundler/setup'
require 'redis'

puts "🧹 CLEARING ALL VIEWING HISTORY"
puts "=" * 60

REDIS_URL = ENV['REDIS_URL'] || 'redis://localhost:6379'
redis = Redis.new(url: REDIS_URL)

# Get all viewing history keys
history_keys = redis.keys("viewing_history:*")

if history_keys.empty?
  puts "✅ No viewing history found (already clear)"
else
  puts "Found #{history_keys.size} sessions with viewing history"
  puts "Clearing..."
  
  history_keys.each do |key|
    redis.del(key)
    print "."
  end
  
  puts "\n✅ Cleared #{history_keys.size} viewing history records"
  puts "\n📝 Users will now see all 10 memes as 'new' again"
end

puts "\n" + "=" * 60
puts "✅ DONE! Refresh your browser to see memes again."
