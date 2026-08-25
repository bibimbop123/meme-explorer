#!/usr/bin/env ruby
# Reddit OAuth Monitor - Shows countdown to rate limit reset with live testing

require 'bundler/setup'
require 'net/http'
require 'json'
require 'time'

# Load environment
require 'dotenv/load' if File.exist?('.env')

puts "🔍 REDDIT OAUTH RATE LIMIT MONITOR"
puts "=" * 60
puts ""

# Reddit OAuth config
CLIENT_ID = ENV['REDDIT_CLIENT_ID']
CLIENT_SECRET = ENV['REDDIT_CLIENT_SECRET']
USER_AGENT = ENV['REDDIT_USER_AGENT'] || 'MemeExplorer/1.0'

if !CLIENT_ID || !CLIENT_SECRET
  puts "❌ ERROR: REDDIT_CLIENT_ID and REDDIT_CLIENT_SECRET not set"
  puts "   Check your .env file"
  exit 1
end

def get_oauth_token
  uri = URI('https://www.reddit.com/api/v1/access_token')
  request = Net::HTTP::Post.new(uri)
  request.basic_auth(CLIENT_ID, CLIENT_SECRET)
  request['User-Agent'] = USER_AGENT
  request.set_form_data('grant_type' => 'client_credentials')
  
  response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true,  
                              open_timeout: 5, read_timeout: 5) do |http|
    http.request(request)
  end
  
  if response.code == '200'
    data = JSON.parse(response.body)
    data['access_token']
  else
    nil
  end
rescue => e
  nil
end

def test_reddit_api(token)
  return {status: :no_token, code: nil} unless token
  
  uri = URI('https://oauth.reddit.com/r/memes/hot.json?limit=1')
  request = Net::HTTP::Get.new(uri)
  request['Authorization'] = "Bearer #{token}"
  request['User-Agent'] = USER_AGENT
  
  response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true,
                              open_timeout: 5, read_timeout: 5) do |http|
    http.request(request)
  end
  
  {status: :success, code: response.code.to_i}
rescue => e
  {status: :error, code: nil, error: e.message}
end

# Initial test
puts "🧪 Testing Reddit OAuth..."
token = get_oauth_token

if token
  puts "✅ Got OAuth token"
  result = test_reddit_api(token)
  
  case result[:code]
  when 200
    puts "🎉 REDDIT API WORKING!"
    puts "   Status: #{result[:code]} OK"
    puts "   You can fetch memes now!"
    puts ""
    puts "Run: bundle exec ruby scripts/turbo_fetch_reddit.rb"
    exit 0
  when 429
    puts "⏰ RATE LIMITED (429)"
    puts "   Reddit is still blocking requests"
  when 403
    puts "🚫 FORBIDDEN (403)"
    puts "   OAuth credentials may be banned"
  else
    puts "⚠️  UNEXPECTED STATUS: #{result[:code]}"
  end
else
  puts "❌ Failed to get OAuth token"
  puts "   Your credentials may be invalid"
  exit 1
end

puts ""
puts "=" * 60
puts "⏱️  COUNTDOWN TO RATE LIMIT RESET"
puts "=" * 60
puts ""

# Reddit rate limits reset every hour from first request
# Conservative estimate: check every 5 minutes
start_time = Time.now
next_check = start_time + 300  # Check in 5 minutes

# Reddit typically resets on the hour, so calculate next hour
next_hour = Time.now + (3600 - (Time.now.to_i % 3600))
estimated_reset = next_hour

puts "Current time:      #{Time.now.strftime('%I:%M:%S %p')}"
puts "Estimated reset:   #{estimated_reset.strftime('%I:%M:%S %p')}"
puts "Time remaining:    ~#{((estimated_reset - Time.now) / 60).to_i} minutes"
puts ""
puts "Checking every 5 minutes... (Press Ctrl+C to stop)"
puts ""

# Live monitoring loop
check_count = 0
loop do
  sleep_time = [(next_check - Time.now), 1].max
  sleep(sleep_time)
  
  check_count += 1
  now = Time.now
  time_str = now.strftime('%I:%M:%S %p')
  
  token =get_oauth_token
  if token
    result = test_reddit_api(token)
    
    case result[:code]
    when 200
      puts "\n🎉 SUCCESS at #{time_str}!"
      puts "   Reddit OAuth is working again!"
      puts ""
      puts "Run this command to fetch memes:"
      puts "   bundle exec ruby scripts/turbo_fetch_reddit.rb"
      exit 0
    when 429
      remaining = ((estimated_reset - now) / 60).to_i
      puts "[#{time_str}] Still rate-limited (429) - ~#{remaining} min remaining"
    when 403
      puts "[#{time_str}] Forbidden (403) - credentials may be permanently banned"
      puts "   Consider creating new Reddit OAuth app"
      sleep(300)  # Check less frequently for 403
    else
      puts "[#{time_str}] Status: #{result[:code]}"
    end
  else
    puts "[#{time_str}] Failed to get token"
  end
  
  next_check = now + 300  # Check again in 5 minutes
  
  # Update estimate if we've passed the hour mark
  if now > estimated_reset
    estimated_reset = now + 3600
  end
end
