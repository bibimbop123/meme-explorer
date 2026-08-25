#!/usr/bin/env ruby
# Turbo Fetch Reddit Memes - Bypass rate limit with smart delays
# Run this to force-fetch fresh memes from Reddit

require_relative '../config/application'
require_relative '../lib/services/reddit_fetcher_service'
require 'net/http'
require 'json'

# Obtain an OAuth access token via client-credentials grant
def get_reddit_oauth_token
  client_id = ENV['REDDIT_CLIENT_ID']
  client_secret = ENV['REDDIT_CLIENT_SECRET']
  user_agent = ENV['REDDIT_USER_AGENT'] || 'MemeExplorer/1.0'

  unless client_id && client_secret
    puts "❌ ERROR: REDDIT_CLIENT_ID and REDDIT_CLIENT_SECRET not set"
    return nil
  end

  uri = URI('https://www.reddit.com/api/v1/access_token')
  request = Net::HTTP::Post.new(uri)
  request.basic_auth(client_id, client_secret)
  request['User-Agent'] = user_agent
  request.set_form_data('grant_type' => 'client_credentials')

  response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true,
                              open_timeout: 5, read_timeout: 5) do |http|
    http.request(request)
  end

  if response.code == '200'
    JSON.parse(response.body)['access_token']
  else
    puts "❌ Failed to get OAuth token (HTTP #{response.code})"
    nil
  end
rescue => e
  puts "❌ Error fetching OAuth token: #{e.message}"
  nil
end

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

access_token = get_reddit_oauth_token

unless access_token
  puts "\n❌ Could not obtain Reddit OAuth token. Aborting."
  exit 1
end

puts "✅ Got OAuth token"

fetcher = RedditFetcherService.new(auth_strategy: :oauth, access_token: access_token)
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
