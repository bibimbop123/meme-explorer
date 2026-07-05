#!/usr/bin/env ruby
# Clear all meme pools to force fresh tier-categorized fetch

require_relative '../config/environment'

puts "🧹 Clearing all meme pools..."

keys_to_clear = [
  'meme_pool',
  'meme_pool:count',
  'meme_pool:updated_at',
  'meme_pool:fresh',
  'meme_pool:fresh:count',
  'meme_pool:surprise',
  'meme_pool:surprise:count',
  'meme_pool:diverse',
  'meme_pool:diverse:count'
]

keys_to_clear.each do |key|
  RedisService.del(key)
  puts "   ✅ Cleared: #{key}"
end

puts ""
puts "✅ All pools cleared! Next /random request will trigger fresh fetch with tier categorization."
