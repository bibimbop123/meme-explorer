#!/usr/bin/env ruby
# Performance Benchmark: Original vs Turbocharged Reddit Fetcher
# Run: ruby scripts/benchmark_fetchers.rb

require 'bundler/setup'
require 'yaml'
require 'benchmark'
require_relative '../lib/services/reddit_fetcher_service'
require_relative '../lib/services/turbocharged_reddit_fetcher'

puts "=" * 80
puts "REDDIT FETCHER PERFORMANCE BENCHMARK"
puts "=" * 80
puts ""

# Load test subreddits
subreddits_data = YAML.load_file('data/subreddits.yml')
test_subreddits = subreddits_data['tier_1'].first(30) # Test with 30 subreddits

puts "Test Configuration:"
puts "  • Subreddits: #{test_subreddits.size}"
puts "  • Posts per subreddit: 20"
puts "  • Total expected requests (original): #{test_subreddits.size}"
puts "  • Total expected requests (turbo): ~#{(test_subreddits.size / 10.0).ceil}"
puts ""

# Setup OAuth token if available
client_id = ENV['REDDIT_CLIENT_ID'].to_s.strip
client_secret = ENV['REDDIT_CLIENT_SECRET'].to_s.strip

access_token = nil
auth_strategy = :static

if !client_id.empty? && !client_secret.empty?
  begin
    require 'oauth2'
    client = OAuth2::Client.new(
      client_id,
      client_secret,
      site: "https://www.reddit.com",
      authorize_url: "/api/v1/authorize",
      token_url: "/api/v1/access_token"
    )
    token = client.client_credentials.get_token(scope: "read")
    access_token = token.token
    auth_strategy = :oauth
    puts "✅ OAuth authentication enabled"
  rescue => e
    puts "⚠️  OAuth failed, using static auth: #{e.message}"
  end
else
  puts "ℹ️  No OAuth credentials, using static auth"
end

puts ""
puts "-" * 80
puts "BENCHMARK 1: ORIGINAL FETCHER"
puts "-" * 80

original_memes = []
original_time = Benchmark.realtime do
  fetcher = RedditFetcherService.new(
    auth_strategy: auth_strategy,
    access_token: access_token
  )
  original_memes = fetcher.fetch_memes(test_subreddits, limit: 20)
end

puts ""
puts "Results:"
puts "  • Duration: #{original_time.round(2)}s"
puts "  • Memes fetched: #{original_memes.size}"
puts "  • Rate: #{(original_memes.size / original_time).round(1)} memes/sec"
puts ""

# Give Reddit API a breather
puts "Waiting 5 seconds before next test..."
sleep 5

puts ""
puts "-" * 80
puts "BENCHMARK 2: TURBOCHARGED FETCHER"
puts "-" * 80

turbo_memes = []
turbo_time = Benchmark.realtime do
  fetcher = TurbochargedRedditFetcher.new(
    auth_strategy: auth_strategy,
    access_token: access_token
  )
  turbo_memes = fetcher.fetch_memes(test_subreddits, limit: 20)
end

puts ""
puts "Results:"
puts "  • Duration: #{turbo_time.round(2)}s"
puts "  • Memes fetched: #{turbo_memes.size}"
puts "  • Rate: #{(turbo_memes.size / turbo_time).round(1)} memes/sec"
puts ""

# Performance comparison
puts "=" * 80
puts "PERFORMANCE COMPARISON"
puts "=" * 80
puts ""

speedup = original_time / turbo_time
time_saved = original_time - turbo_time
percentage_faster = ((speedup - 1) * 100).round(1)

puts "Speed Improvement:"
puts "  • Speedup: #{speedup.round(2)}x faster"
puts "  • Time saved: #{time_saved.round(2)}s (#{percentage_faster}% faster)"
puts "  • Original: #{original_time.round(2)}s"
puts "  • Turbocharged: #{turbo_time.round(2)}s"
puts ""

puts "Throughput Comparison:"
original_rate = (original_memes.size / original_time).round(1)
turbo_rate = (turbo_memes.size / turbo_time).round(1)
puts "  • Original: #{original_rate} memes/sec"
puts "  • Turbocharged: #{turbo_rate} memes/sec"
puts "  • Improvement: #{((turbo_rate / original_rate - 1) * 100).round(1)}% more throughput"
puts ""

puts "Quality Preservation:"
puts "  • Original memes: #{original_memes.size}"
puts "  • Turbo memes: #{turbo_memes.size}"
puts "  • Difference: #{(turbo_memes.size - original_memes.size).abs} memes"
puts "  • Variety maintained: #{turbo_memes.size >= (original_memes.size * 0.9) ? '✅ YES' : '⚠️  REVIEW NEEDED'}"
puts ""

# Projected savings for production use
puts "Projected Production Impact (500 meme fetch):"
projection_multiplier = 500.0 / original_memes.size
original_projected = original_time * projection_multiplier
turbo_projected = turbo_time * projection_multiplier
puts "  • Original: ~#{original_projected.round(1)}s"
puts "  • Turbocharged: ~#{turbo_projected.round(1)}s"
puts "  • Time saved per fetch: ~#{(original_projected - turbo_projected).round(1)}s"
puts "  • Daily savings (10 fetches): ~#{((original_projected - turbo_projected) * 10 / 60).round(1)} minutes"
puts ""

puts "=" * 80
puts "RECOMMENDATION"
puts "=" * 80

if speedup >= 3.0
  puts "🚀 EXCELLENT: #{speedup.round(1)}x speedup achieved!"
  puts "   Strong recommendation to use TurbochargedRedditFetcher in production."
elsif speedup >= 2.0
  puts "✅ GOOD: #{speedup.round(1)}x speedup achieved."
  puts "   Recommended to use TurbochargedRedditFetcher for better performance."
elsif speedup >= 1.5
  puts "👍 MODERATE: #{speedup.round(1)}x speedup achieved."
  puts "   Consider using TurbochargedRedditFetcher for improved efficiency."
else
  puts "⚠️  LIMITED: #{speedup.round(1)}x speedup may indicate network issues or rate limiting."
  puts "   Review logs and consider retesting."
end

puts ""
puts "=" * 80
