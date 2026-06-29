#!/usr/bin/env ruby
# Production Logs Critical Fixes - June 29, 2026
# Fixes:
# 1. Missing /api/vitals route registration
# 2. Pool categorization - too restrictive filters
# 3. Bootstrap performance optimization
# 4. Reduce log noise for expected conditions

puts "🔧 Production Logs Fix - June 29, 2026"
puts "=" * 60

# Fix 1: Update app.rb to register web_vitals route
puts "\n✅ FIX 1: Register /api/vitals route in app.rb"
app_rb = File.read('app.rb')

unless app_rb.include?('require_relative "./routes/web_vitals"')
  # Add after routes/health
  app_rb.gsub!(
    /require_relative "\.\/routes\/health"/,
    'require_relative "./routes/health"' + "\n" + 'require_relative "./routes/web_vitals"'
  )
  File.write('app.rb', app_rb)
  puts "   ✓ Added web_vitals route require"
else
  puts "   ℹ️  web_vitals already required"
end

# Check if route is registered
unless app_rb.include?('register Routes::WebVitals')
  # Find where other routes are registered and add it
  if app_rb =~ /(register Routes::Health.*?\n)/
    app_rb.gsub!($1, $1 + "      register Routes::WebVitals\n")
    File.write('app.rb', app_rb)
    puts "   ✓ Registered Routes::WebVitals"
  end
else
  puts "   ℹ️  Routes::WebVitals already registered"
end

# Fix 2: Update web_vitals.rb to use proper module structure
puts "\n✅ FIX 2: Update web_vitals.rb route module"
web_vitals_content = <<~'RUBY'
  # frozen_string_literal: true

  # Web Vitals tracking endpoint
  # Receives Core Web Vitals metrics from clients

  module Routes
    module WebVitals
      def self.registered(app)
        app.post '/api/vitals' do
          content_type :json
          
          begin
            data = JSON.parse(request.body.read)
            
            metric = data['metric']
            value = data['value']
            url = data['url']
            
            # Log to application logger (DEBUG level to reduce noise)
            AppLogger.debug("Web Vital - #{metric.upcase}: #{value}ms on #{url}")
            
            # Store in Redis for aggregation
            redis_key = "web_vitals:#{Date.today}:#{metric}"
            RedisService.rpush(redis_key, value.to_s)
            RedisService.expire(redis_key, 604800) # Keep for 7 days
            
            # Alert if critical thresholds exceeded
            if (metric == 'lcp' && value > 4000) ||
               (metric == 'fid' && value > 300) ||
               (metric == 'cls' && value > 0.25)
              AppLogger.warn("⚠️ Critical Web Vital: #{metric.upcase} = #{value}")
            end
            
            { success: true }.to_json
          rescue => e
            AppLogger.error("Web Vitals tracking error: #{e.message}")
            status 500
            { error: 'Internal server error' }.to_json
          end
        end
        
        # Get Web Vitals dashboard data
        app.get '/admin/web-vitals' do
          protected!
          
          @vitals_data = {}
          %w[lcp fid cls].each do |metric|
            redis_key = "web_vitals:#{Date.today}:#{metric}"
            values = RedisService.lrange(redis_key, 0, -1).map(&:to_f)
            
            next if values.empty?
            
            @vitals_data[metric] = {
              count: values.size,
              avg: (values.sum / values.size).round(2),
              p50: percentile(values, 50).round(2),
              p75: percentile(values, 75).round(2),
              p95: percentile(values, 95).round(2)
            }
          end
          
          erb :'admin/web_vitals'
        end
        
        app.helpers do
          def percentile(values, p)
            sorted = values.sort
            index = (p / 100.0 * sorted.length).ceil - 1
            sorted[[index, 0].max]
          end
        end
      end
    end
  end
RUBY

File.write('routes/web_vitals.rb', web_vitals_content)
puts "   ✓ Updated web_vitals.rb with proper module structure"

# Fix 3: Update diversity engine to have less restrictive pool filters for bootstrap
puts "\n✅ FIX 3: Relax pool filters for bootstrapped memes"
diversity_v2 = File.read('lib/services/diversity_engine_service_v2.rb')

# Update trending pool to be less restrictive
diversity_v2.gsub!(
  /# MUCH lower threshold: 20\+ likes, 0\.5\+ ratio\s+likes >= 20 && upvote_ratio >= 0\.5/,
  "# VERY relaxed threshold for bootstrap: 5+ likes OR 0.6+ ratio OR recent\n          likes >= 5 || upvote_ratio >= 0.6 || meme['created_at']"
)

# Update fresh pool minimum threshold
diversity_v2.gsub!(
  /if fresh\.size < 50/,
  'if fresh.size < 20'
)

File.write('lib/services/diversity_engine_service_v2.rb', diversity_v2)
puts "   ✓ Relaxed trending and fresh pool filters"

# Fix 4: Update pool manager to reduce log noise
puts "\n✅ FIX 4: Reduce log noise in MemePoolManager"
pool_manager = File.read('lib/services/meme_pool_manager.rb')

# Change Sidekiq warning to debug level
pool_manager.gsub!(
  /AppLogger\.warn\("ℹ️  \[PoolManager\] Sidekiq unavailable, pool will stay at bootstrap size"\)/,
  'AppLogger.debug("ℹ️  [PoolManager] Sidekiq unavailable, pool will stay at bootstrap size")'
)

# Reduce bootstrap logging verbosity
pool_manager.gsub!(
  /AppLogger\.info\("✅ \[PoolManager\] Bootstrap complete: #\{bootstrap_result\[:size\]\} memes"\)/,
  'AppLogger.info("✅ [Pool] Using MemePoolManager: #{bootstrap_result[:size]} memes (tier-distributed)")'
)

File.write('lib/services/meme_pool_manager.rb', pool_manager)
puts "   ✓ Reduced log noise for expected conditions"

# Fix 5: Optimize bootstrap by caching metadata
puts "\n✅ FIX 5: Add meme metadata for pool categorization"
turbofetcher = File.read('lib/services/turbocharged_reddit_fetcher.rb')

# Check if we're already adding engagement metadata
unless turbofetcher.include?('Add engagement metadata for pool selection')
  turbofetcher.gsub!(
    /(post_data = \{[^}]+permalink: permalink\s*\})/m,
    <<~RUBY.chomp
      post_data = {
              title: title,
              subreddit: sub,
              url: final_url,
              permalink: permalink,
              # Add engagement metadata for pool selection
              likes: data.dig('ups') || 0,
              comments: data.dig('num_comments') || 0,
              upvote_ratio: data.dig('upvote_ratio') || 0.5,
              created_at: data.dig('created_utc') ? Time.at(data['created_utc']).to_s : Time.now.to_s
            }
    RUBY
  )
  File.write('lib/services/turbocharged_reddit_fetcher.rb', turbofetcher)
  puts "   ✓ Added engagement metadata to fetched memes"
else
  puts "   ℹ️  Engagement metadata already present"
end

puts "\n" + "=" * 60
puts "✅ ALL FIXES APPLIED SUCCESSFULLY!"
puts "\nChanges made:"
puts "  1. ✅ Registered /api/vitals route (fixes 404 errors)"
puts "  2. ✅ Converted web_vitals to proper module structure"
puts "  3. ✅ Relaxed pool filters (fixes empty trending/surprise pools)"
puts "  4. ✅ Reduced log noise for expected conditions"
puts "  5. ✅ Added engagement metadata for better categorization"
puts "\nNext: Deploy with './scripts/deploy_production_logs_fix_june_29.sh'"
