#!/usr/bin/env ruby
# Calculate leaderboard scores for all periods and types

require_relative '../db/setup'
require_relative '../lib/services/leaderboard_service'

puts "📊 Calculating leaderboard scores..."
puts "=" * 50

# Calculate for all periods
['weekly', 'monthly', 'all_time'].each do |type|
  puts "\n#{type.capitalize} Leaderboard:"
  puts "-" * 30
  
  begin
    LeaderboardService.calculate_scores(type.to_sym)
    
    # Show top 5
    top = LeaderboardService.get_leaderboard(type: type.to_sym, limit: 5)
    
    if top.empty?
      puts "  (No rankings yet - need activities to be tracked)"
    else
      top.each_with_index do |entry, i|
        username = entry['username'] || entry['email'] || "User #{entry['user_id']}"
        score = entry['total_score'] || 0
        rank = entry['rank'] || (i + 1)
        puts "  #{rank}. #{username}: #{score} points"
      end
    end
  rescue => e
    puts "  ⚠️ Error: #{e.message}"
    puts "  #{e.backtrace.first}"
  end
end

puts "\n" + "=" * 50
puts "✅ Score calculation complete!"
puts "\nNext steps:"
puts "  1. Visit /leaderboard to see results"
puts "  2. Like/save memes to generate activities"
puts "  3. Run this script again to see updated scores"
