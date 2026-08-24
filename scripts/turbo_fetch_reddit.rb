#!/usr/bin/env ruby
# Turbo Fetch Reddit Memes - Bypass rate limit with smart delays
# Run this to force-fetch fresh memes from Reddit

require_relative '../config/application'
require_relative '../lib/services/reddit_fetcher_service'

puts "🚀 TURBO FETCH: Fetching fresh Reddit memes..."
puts "   Strategy: 5 subreddits, 2-second delays, max quality"

# Top 5 subreddits with highest success rate
top_subreddits = [
  'memes',
  'dankmemes', 
  'me_irl',
  'wholesomememes',
  'AdviceAnimals'
]

fetcher = RedditFetcherService.new(auth_strategy: :oauth)
all_memes = []

top_subreddits.each_with_index do |sub, idx|
  puts "\n[#{idx + 1}/5] Fetching r/#{sub}..."
  begin
    memes = fetcher.fetch_memes([sub], limit: 50)
    if memes.any?
      all_memes.concat(memes)
      puts "   ✅ Got #{memes.size} memes"
    else
      puts "   ⚠️  Rate limited or empty"
    end
  rescue => e
    puts "   ❌ Error: #{e.message}"
  end
  
  # Smart delay: 2 seconds between requests
  sleep 2 unless idx == top_subreddits.size - 1
end

puts "\n📊 RESULTS:"
puts "   Total fetched: #{all_memes.size} memes"

if all_memes.any?
  # Store in cache
  require_relative '../lib/helpers/meme_pool_helpers'
  
  MemeExplorer::App::MEME_CACHE.set(:memes, all_memes)
  MemeExplorer::App::MEME_CACHE.set(:last_refresh, Time.now)
  
  puts "   ✅ Cached #{all_memes.size} fresh Reddit memes"
  puts "   🎯 /random will now show these memes"
  puts "\n✨ SUCCESS: Turbo fetch complete!"
else
  puts "   ❌ Reddit is heavily rate-limited (429)"
  puts "   ⏰ Wait 10-15 minutes and try again"
  puts "   OR use local memes for now"
  exit 1
end
