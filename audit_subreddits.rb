#!/usr/bin/env ruby

require 'yaml'
require 'net/http'
require 'uri'
require 'json'

# Load subreddits
subreddits_yaml = YAML.load_file('data/subreddits.yml')

# User agent rotation
user_agents = [
  "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36",
  "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36",
  "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36"
]

def is_valid_image_url(url)
  return false unless url
  url.match?(/^https?:\/\/(i\.redd\.it|imgur\.com|media\.reddit\.com|media\.|[a-z0-9\-]+\.(jpg|jpeg|png|gif|webp))/i)
end

def extract_image_url(post_data)
  # Direct i.redd.it
  return post_data["url"] if post_data["url"]&.match?(/^https:\/\/i\.redd\.it\//)
  
  # imgur
  return post_data["url"] if post_data["url"]&.match?(/^https:\/\/(i\.)?imgur\.com\//)
  
  # Other hosts
  return post_data["url"] if post_data["url"]&.match?(/^https:\/\/(media\.|external-)?[a-z0-9\-]+\.(jpg|jpeg|png|gif|webp)/i)
  
  # Preview
  if post_data["preview"]&.dig("images", 0, "source", "url")
    url = post_data["preview"]["images"][0]["source"]["url"]
    return url.gsub("&amp;", "&") if url
  end
  
  # Gallery
  if post_data["gallery_data"]&.dig("items")&.first
    gallery_id = post_data["gallery_data"]["items"].first["media_id"]
    if post_data["media_metadata"]&.dig(gallery_id, "s", "x")
      return post_data["media_metadata"][gallery_id]["s"]["x"]
    end
  end
  
  nil
end

results = {}

# Check each tier
['tier_1', 'tier_2', 'tier_3', 'tier_4', 'tier_5', 'tier_6', 'tier_7', 'tier_8', 'tier_9', 'tier_10'].each do |tier|
  tier_subs = subreddits_yaml[tier] || []
  results[tier] = { working: [], failed: [], no_images: [] }
  
  puts "\n📊 Testing #{tier.upcase} (#{tier_subs.size} subreddits)..."
  
  tier_subs.each_with_index do |sub, idx|
    begin
      url = "https://www.reddit.com/r/#{sub}/top.json?t=week&limit=10"
      uri = URI(url)
      
      response = Net::HTTP.start(uri.host, uri.port, use_ssl: true, read_timeout: 10, open_timeout: 10) do |http|
        request = Net::HTTP::Get.new(uri.request_uri)
        request["User-Agent"] = user_agents[idx % user_agents.size]
        request["Accept"] = "application/json"
        http.request(request)
      end
      
      if response.code == "200"
        data = JSON.parse(response.body)
        images_found = 0
        
        data["data"]["children"].each do |post|
          post_data = post["data"]
          next if post_data["is_video"] || post_data["is_self"]
          
          image_url = extract_image_url(post_data)
          images_found += 1 if image_url && is_valid_image_url(image_url)
        end
        
        if images_found > 0
          results[tier][:working] << "#{sub} (#{images_found} images)"
          print "✅ "
        else
          results[tier][:no_images] << sub
          print "❌ "
        end
      else
        results[tier][:failed] << "#{sub} (HTTP #{response.code})"
        print "⚠️ "
      end
      
      sleep 0.5  # Be respectful
    rescue => e
      results[tier][:failed] << "#{sub} (#{e.class})"
      print "❌ "
    end
  end
  
  puts "\n  ✅ Working: #{results[tier][:working].size}/#{tier_subs.size}"
  puts "  ❌ No Images: #{results[tier][:no_images].size}"
  puts "  ⚠️  Failed: #{results[tier][:failed].size}"
end

# Summary
puts "\n" + "="*60
puts "AUDIT SUMMARY"
puts "="*60

total_working = 0
total_no_images = 0
total_failed = 0

results.each do |tier, data|
  total_working += data[:working].size
  total_no_images += data[:no_images].size
  total_failed += data[:failed].size
end

puts "\n✅ WORKING SUBREDDITS (#{total_working}):"
results.each { |tier, data| data[:working].each { |sub| puts "  #{tier}: #{sub}" } }

puts "\n❌ NO IMAGES FOUND (#{total_no_images}):"
results.each { |tier, data| data[:no_images].each { |sub| puts "  #{tier}: #{sub}" } }

puts "\n⚠️  FAILED TO FETCH (#{total_failed}):"
results.each { |tier, data| data[:failed].each { |sub| puts "  #{tier}: #{sub}" } }

puts "\n" + "="*60
puts "TOTAL: #{total_working} working, #{total_no_images} no images, #{total_failed} failed"
putting "Success Rate: #{((total_working.to_f / (total_working + total_no_images + total_failed)) * 100).round(1)}%"
