#!/usr/bin/env ruby
# HOTFIX #10: Comment out ALL missing route registrations in app.rb

puts "🔥 HOTFIX #10: Finding and commenting out ALL missing route registrations..."

# Map of route names to their expected file paths
route_files = {
  'ABTesting' => 'routes/ab_testing.rb',
  'HealthRoutes' => 'routes/health.rb',
  'WebVitals' => 'routes/web_vitals.rb',
  'CollectionRoutes' => 'routes/collections.rb',
  'PersonalizationRoutes' => 'routes/personalization_routes.rb',
  'Home' => 'routes/home.rb',
  'RandomMeme' => 'routes/random_meme.rb',
  'Memes' => 'routes/memes.rb',
  'MemeStats' => 'routes/meme_stats.rb',
  'SearchRoutes' => 'routes/search_routes.rb',
  'TrendingRoutes' => 'routes/trending_routes.rb',
  'TrendingAPI' => 'routes/trending_api.rb',
  'ProfileRoutes' => 'routes/profile_routes.rb',
  'AdminRoutes' => 'routes/admin_routes.rb',
  'MetricsRoutes' => 'routes/metrics_routes.rb',
  'BehavioralTracking' => 'routes/behavioral_tracking.rb',
  'AlgorithmMetrics' => 'routes/algorithm_metrics.rb',
  'Seo' => 'routes/seo_routes.rb',
  'EnhancedRandom' => 'routes/enhanced_random.rb',
  'SessionMetrics' => 'routes/session_metrics.rb',
  'UtilityRoutes' => 'routes/utility_routes.rb',
  'Guides' => 'routes/guides.rb',
  'Blog' => 'routes/blog.rb',
  'LeaderboardRoutes' => 'routes/leaderboard_routes.rb',
  'UserApiRoutes' => 'routes/user_api_routes.rb',
  'SystemRoutes' => 'routes/system_routes.rb',
  'AdminInlineRoutes' => 'routes/admin_inline_routes.rb'
}

# Check which files are missing
missing_routes = []
route_files.each do |name, path|
  unless File.exist?(path)
    missing_routes << name
    puts "❌ Missing: #{name} (#{path})"
  else
    puts "✅ Exists: #{name}"
  end
end

if missing_routes.empty?
  puts "\n✅ All route files exist! No changes needed."
  exit 0
end

puts "\n📝 Commenting out #{missing_routes.length} missing route registrations in app.rb..."

# Read app.rb
app_rb = File.read('app.rb')

# Comment out each missing route
missing_routes.each do |route_name|
  # Match patterns like "register Routes::ABTesting" or "  register Routes::ABTesting"
  app_rb.gsub!(/^(\s*)(register Routes::#{route_name})/, '\1# \2 # ELON AUDIT: Route file not found')
end

# Write back
File.write('app.rb', app_rb)

puts "\n✅ Commented out #{missing_routes.length} missing routes:"
missing_routes.each { |r| puts "   - #{r}" }
puts "\n🚀 app.rb updated! Ready to deploy."
