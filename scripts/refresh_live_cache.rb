#!/usr/bin/env ruby
# Refresh cache while server is running via HTTP endpoint

require 'net/http'
require 'json'

puts "🔄 Triggering cache refresh on running server..."

begin
  uri = URI('http://localhost:8080/admin/refresh-cache')
  response = Net::HTTP.post(uri, '', {'Content-Type' => 'application/json'})
  
  if response.code == '200'
    result = JSON.parse(response.body)
    puts "✅ Cache refreshed successfully!"
    puts "   API memes: #{result['api_count']}"
    puts "   Local memes: #{result['local_count']}"
    puts "   Total: #{result['total']}"
  else
    puts "❌ Failed: #{response.code} - #{response.body}"
  end
rescue Errno::ECONNREFUSED
  puts "❌ Server not running! Start it first with: bundle exec puma"
rescue => e
  puts "❌ Error: #{e.message}"
end
