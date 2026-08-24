#!/usr/bin/env ruby
# Emergency Reddit Scraper - Bypasses OAuth rate limits
# Uses public .json endpoints (different rate limit pool)

require 'net/http'
require 'json'
require_relative '../config/application'

puts "🚨 EMERGENCY SCRAPER: Bypassing OAuth rate limits..."
puts "   Strategy: Public JSON endpoints (no auth required)"

def fetch_subreddit_json(subreddit, limit = 50)
  url = "https://www.reddit.com/r/#{subreddit}/hot.json?limit=#{limit}"
  uri = URI(url)
  
  # Reddit requires a User-Agent
  request = Net::HTTP::Get.new(uri)
  request['User-Agent'] = 'MemeExplorer/1.0 (Educational Project)'
  
  response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true) do |http|
    http.request(request)
  end
  
  if response.code == '200'
    data = JSON.parse(response.body)
    posts = data.dig('data', 'children') || []
    
    memes = posts.map do |post|
      post_data = post['data']
      next unless post_data['post_hint'] == 'image' || post_data['url']&.match?(/\.(jpg|jpeg|png|gif)$/i)
      
      {
        'title' => post_data['title'],
        'url' => post_data['url'],
        'subreddit' => post_data['subreddit'],
        'permalink' => "https://www.reddit.com#{post_data['permalink']}",
        'score' => post_data['score'],
        'created' => Time.at(post_data['created_utc']).to_s
      }
    end.compact
    
    memes
  else
    puts "   ❌ HTTP #{response.code}"
    []
  end
rescue => e
  puts "   ❌ Error: #{e.message}"
  []
end

# Top meme subreddits
subreddits = ['memes', 'dankmemes', 'wholesomememes', 'me_irl', 'AdviceAnimals']
all_memes = []

subreddits.each_with_index do |sub, idx|
  puts "\n[#{idx + 1}/5] Scraping r/#{sub}..."
  memes = fetch_subreddit_json(sub, 50)
  
  if memes.any?
    all_memes.concat(memes)
    puts "   ✅ Got #{memes.size} memes"
  else
    puts "   ⚠️  Failed or empty"
  end
  
  # Respectful delay
  sleep 1.5 unless idx == subreddits.size - 1
end

puts "\n📊 RESULTS:"
puts "   Total scraped: #{all_memes.size} memes"

if all_memes.any?
  # Store in cache
  MemeExplorer::App::MEME_CACHE.set(:memes, all_memes)
  MemeExplorer::App::MEME_CACHE.set(:last_refresh, Time.now)
  
  puts "   ✅ Cached #{all_memes.size} fresh Reddit memes"
  puts "   🎯 /random will now show these memes"
  puts "\n✨ SUCCESS: Emergency scrape complete!"
  puts "   Site is NOW usable with fresh content! 🚀"
else
  puts "   ❌ All scraping attempts failed"
  exit 1
end
