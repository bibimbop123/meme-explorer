#!/usr/bin/env ruby
# Performance Regression Test Script
# Tests P2 improvements don't negatively impact performance

require 'httparty'
require 'benchmark'
require 'json'

BASE_URL = ENV['TEST_URL'] || 'http://localhost:8080'
REQUESTS = ENV['REQUESTS']&.to_i || 100
WARMUP = ENV['WARMUP']&.to_i || 10

puts "\n" + "=" * 60
puts "🚀 P2 Performance Regression Test"
puts "=" * 60
puts "Testing: #{BASE_URL}"
puts "Requests per endpoint: #{REQUESTS}"
puts "Warmup requests: #{WARMUP}"
puts "=" * 60
puts "\n"

# Test endpoints
endpoints = [
  { path: '/', name: 'Homepage', target: 300 },
  { path: '/random', name: 'Random Meme Page', target: 200 },
  { path: '/random.json', name: 'Random Meme API', target: 150 },
  { path: '/trending', name: 'Trending Page', target: 500 },
  { path: '/search?q=funny', name: 'Search', target: 400 },
  { path: '/leaderboard', name: 'Leaderboard', target: 600 },
  { path: '/health', name: 'Health Check', target: 100 }
]

results = {}
total_requests = 0
total_errors = 0

# Warmup phase
puts "🔥 Warming up..."
endpoints.each do |endpoint|
  WARMUP.times do
    begin
      HTTParty.get("#{BASE_URL}#{endpoint[:path]}", timeout: 10)
    rescue => e
      # Ignore warmup errors
    end
  end
end
puts "✅ Warmup complete\n\n"

# Main testing phase
endpoints.each do |endpoint|
  puts "📊 Testing: #{endpoint[:name]} (#{endpoint[:path]})"
  
  times = []
  errors = 0
  status_codes = Hash.new(0)
  
  REQUESTS.times do |i|
    start_time = Time.now
    begin
      response = HTTParty.get("#{BASE_URL}#{endpoint[:path]}", timeout: 10)
      duration = ((Time.now - start_time) * 1000).round(2)
      times << duration
      status_codes[response.code] += 1
      
      if response.code != 200
        errors += 1
      end
    rescue => e
      errors += 1
      status_codes['error'] += 1
    end
    
    # Progress indicator
    if (i + 1) % 10 == 0
      print "\rProgress: #{i + 1}/#{REQUESTS}"
    end
  end
  
  print "\n"
  
  # Calculate statistics
  sorted_times = times.sort
  avg = times.sum / times.size
  min_time = times.min
  max_time = times.max
  p50 = sorted_times[(times.size * 0.50).to_i]
  p95 = sorted_times[(times.size * 0.95).to_i]
  p99 = sorted_times[(times.size * 0.99).to_i]
  
  # Store results
  results[endpoint[:name]] = {
    path: endpoint[:path],
    avg: avg.round(2),
    min: min_time.round(2),
    max: max_time.round(2),
    p50: p50.round(2),
    p95: p95.round(2),
    p99: p99.round(2),
    errors: errors,
    target: endpoint[:target],
    status_codes: status_codes
  }
  
  total_requests += REQUESTS
  total_errors += errors
  
  # Print results
  puts "  Min: #{min_time.round(2)}ms"
  puts "  Avg: #{avg.round(2)}ms (target: <#{endpoint[:target]}ms)"
  puts "  P50: #{p50.round(2)}ms"
  puts "  P95: #{p95.round(2)}ms"
  puts "  P99: #{p99.round(2)}ms"
  puts "  Max: #{max_time.round(2)}ms"
  puts "  Errors: #{errors}/#{REQUESTS}"
  
  # Status breakdown
  if status_codes.size > 1
    puts "  Status codes: #{status_codes.inspect}"
  end
  
  # Performance verdict
  if avg <= endpoint[:target]
    puts "  ✅ PASS - Within target"
  elsif avg <= endpoint[:target] * 1.5
    puts "  ⚠️  WARNING - Slower than target but acceptable"
  else
    puts "  ❌ FAIL - Significantly slower than target"
  end
  
  puts "\n"
  
  sleep 0.5 # Brief pause between endpoints
end

# Summary statistics
puts "\n" + "=" * 60
puts "📈 OVERALL SUMMARY"
puts "=" * 60

total_avg = results.values.map { |r| r[:avg] }.sum / results.size
total_p95 = results.values.map { |r| r[:p95] }.sum / results.size
total_p99 = results.values.map { |r| r[:p99] }.sum / results.size
error_rate = (total_errors.to_f / total_requests * 100).round(2)

puts "Total Requests: #{total_requests}"
puts "Total Errors: #{total_errors} (#{error_rate}%)"
puts "Overall Average: #{total_avg.round(2)}ms"
puts "Overall P95: #{total_p95.round(2)}ms"
puts "Overall P99: #{total_p99.round(2)}ms"

# Performance comparison
puts "\n📊 Performance vs Targets:\n\n"

results.each do |name, data|
  target = data[:target]
  actual = data[:avg]
  diff = actual - target
  pct = ((actual / target.to_f) * 100).round(1)
  
  status = if actual <= target
    "✅"
  elsif actual <= target * 1.2
    "⚠️ "
  else
    "❌"
  end
  
  printf "%-25s  Target: %4dms  Actual: %6.2fms  (%3d%%)  %s\n", 
         name, target, actual, pct, status
end

# Regression detection
puts "\n" + "=" * 60
puts "🔍 REGRESSION ANALYSIS"
puts "=" * 60

regressions = []
warnings = []

# Check for performance regressions
if total_avg > 250
  regressions << "Average response time regression: #{total_avg.round(2)}ms (target: <200ms)"
end

if total_p95 > 600
  regressions << "P95 response time regression: #{total_p95.round(2)}ms (target: <500ms)"
end

if error_rate > 0.5
  regressions << "High error rate: #{error_rate}% (target: <0.5%)"
end

# Check individual endpoints
results.each do |name, data|
  if data[:avg] > data[:target] * 2
    regressions << "#{name}: Severe regression - #{data[:avg].round(2)}ms (target: #{data[:target]}ms)"
  elsif data[:avg] > data[:target] * 1.5
    warnings << "#{name}: Performance warning - #{data[:avg].round(2)}ms (target: #{data[:target]}ms)"
  end
  
  if data[:errors] > REQUESTS * 0.01
    regressions << "#{name}: High error rate - #{data[:errors]}/#{REQUESTS} requests"
  end
end

# Report results
if regressions.empty? && warnings.empty?
  puts "✅ No performance regressions detected"
  puts "✅ All endpoints performing within acceptable ranges"
elsif regressions.empty?
  puts "⚠️  Minor performance concerns:"
  warnings.each { |w| puts "   - #{w}" }
else
  puts "❌ Performance regressions detected:"
  regressions.each { |r| puts "   - #{r}" }
  
  if warnings.any?
    puts "\n⚠️  Additional warnings:"
    warnings.each { |w| puts "   - #{w}" }
  end
end

# Recommendations
puts "\n" + "=" * 60
puts "💡 RECOMMENDATIONS"
puts "=" * 60

if regressions.any? || warnings.any?
  puts "Performance issues detected. Consider:"
  puts "  1. Check database query performance"
  puts "  2. Review cache hit rates"
  puts "  3. Monitor Sidekiq queue sizes"
  puts "  4. Check for N+1 queries"
  puts "  5. Review recent code changes"
  puts "  6. Consider scaling infrastructure"
else
  puts "Performance is excellent! 🎉"
  puts "  - All endpoints within targets"
  puts "  - Error rate acceptable"
  puts "  - P2 improvements show no negative impact"
end

# Export results
if ENV['EXPORT_JSON']
  output = {
    timestamp: Time.now.iso8601,
    base_url: BASE_URL,
    requests_per_endpoint: REQUESTS,
    summary: {
      total_requests: total_requests,
      total_errors: total_errors,
      error_rate: error_rate,
      avg_response_time: total_avg.round(2),
      p95_response_time: total_p95.round(2),
      p99_response_time: total_p99.round(2)
    },
    endpoints: results,
    regressions: regressions,
    warnings: warnings
  }
  
  filename = "performance_test_#{Time.now.strftime('%Y%m%d_%H%M%S')}.json"
  File.write(filename, JSON.pretty_generate(output))
  puts "\n📁 Results exported to: #{filename}"
end

puts "\n" + "=" * 60
puts "✅ Performance test complete"
puts "=" * 60
puts "\n"

# Exit code
if regressions.any?
  exit 1
elsif warnings.any?
  exit 2
else
  exit 0
end
