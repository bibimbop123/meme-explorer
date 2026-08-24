#!/usr/bin/env ruby
# scripts/fix_metrics_accuracy_august_24_2026.rb
# Fixes metrics page chart inflation and accuracy issues

require 'fileutils'

puts "🔧 Fixing Metrics Page Accuracy Issues..."
puts "=" * 60

# The fix: Update routes/metrics_routes.rb to disable inaccurate fallback behavior
metrics_routes_file = 'routes/metrics_routes.rb'

puts "\n📝 Reading #{metrics_routes_file}..."
metrics_content = File.read(metrics_routes_file)

# Create backup
backup_file = "#{metrics_routes_file}.backup_#{Time.now.strftime('%Y%m%d_%H%M%S')}"
File.write(backup_file, metrics_content)
puts "✅ Backup created: #{backup_file}"

# Fix 1: Disable charts when activity_log doesn't exist (lines 170-242)
# Fix 2: Disable time filters when activity_log doesn't exist
# Fix 3: Add warning message

updated_content = metrics_content.gsub(
  /            else\n              # Fallback to meme_stats approach \(less accurate but works without activity log\)\n              # ✅ POSTGRESQL FIX: Use PostgreSQL interval syntax\n              where_clause = case period\n                            when '24h' then "WHERE updated_at >= NOW\(\) - INTERVAL '1 day'"\n                            when '7d' then "WHERE updated_at >= NOW\(\) - INTERVAL '7 days'"\n                            when '30d' then "WHERE updated_at >= NOW\(\) - INTERVAL '30 days'"\n                            else ""\n                            end\n              case period\n              when '24h'\n                23\.downto\(0\) do \|hours_ago\|/m,
  '            else
              # ⚠️ ACCURACY FIX: Don\'t show charts without activity log to prevent 100x-1000x inflation
              # Fallback mode cannot accurately calculate time-based trends from cumulative counters
              @chart_dates = []
              @chart_views = []
              @chart_likes = []
              @chart_warning = "Charts require activity tracking. Enable meme_activity_log table for accurate historical data."
              
              # Original fallback code disabled to prevent misleading charts
              # The code was summing cumulative totals instead of counting events
              # This caused 100x-1000x inflation in chart data
              
              # Commenting out the fallback chart generation:
              =begin
              where_clause = case period
                            when \'24h\' then "WHERE updated_at >= NOW() - INTERVAL \'1 day\'"
                            when \'7d\' then "WHERE updated_at >= NOW() - INTERVAL \'7 days\'"
                            when \'30d\' then "WHERE updated_at >= NOW() - INTERVAL \'30 days\'"
                            else ""
                            end
              case period
              when \'24h\'
                23.downto(0) do |hours_ago|'
)

# Close the commented block and clean up the rest
updated_content = updated_content.gsub(
  /                end\n              end\n            end/m,
  '                end
              end
              =end
            end'
)

# Fix: Force period to 'all' when activity_log missing
updated_content = updated_content.gsub(
  /        begin\n          if defined\?\(MemeExplorer::App::DB\) && MemeExplorer::App::DB\n            # Get time period filter\n            period = params\[:period\] \|\| 'all'/m,
  "        begin
          if defined?(MemeExplorer::App::DB) && MemeExplorer::App::DB
            # Get time period filter
            period = params[:period] || 'all'
            
            # ⚠️ ACCURACY FIX: Check if activity_log exists first
            has_activity_log = MemeExplorer::App::DB.get_first_value(
              \"SELECT COUNT(*) FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'meme_activity_log'\"
            ).to_i > 0 rescue false
            
            # Force 'all' period if activity_log doesn't exist to avoid misleading time-filtered data
            if period != 'all' && !has_activity_log
              @time_filter_warning = \"⚠️ Time-based filtering requires activity tracking. Showing all-time data instead.\"
              period = 'all'
            end"
)

# Remove the duplicate has_activity_log check since we moved it earlier
updated_content = updated_content.gsub(
  /            # Check if activity log table exists for accurate time-based filtering\n            has_activity_log = MemeExplorer::App::DB\.get_first_value\(\n              "SELECT COUNT\(\*\) FROM information_schema\.tables WHERE table_schema = 'public' AND table_name = 'meme_activity_log'"\n            \)\.to_i > 0 rescue false\n            \n/,
  '            
'
)

# Write the fixed file
File.write(metrics_routes_file, updated_content)
puts "✅ Fixed #{metrics_routes_file}"

puts "\n" + "=" * 60
puts "✅ METRICS ACCURACY FIX COMPLETE!"
puts "=" * 60

puts "\n📋 Changes Made:"
puts "1. ✅ Disabled fallback chart generation (prevents 100x-1000x inflation)"
puts "2. ✅ Force 'all' period when activity_log missing (prevents time filter inaccuracy)"
puts "3. ✅ Added warning messages for users"

puts "\n🔍 Next Steps:"
puts "1. Restart your server: Ctrl+C then 'bundle exec rackup config.ru'"
puts "2. Visit /metrics to see the fix in action"
puts "3. If you have activity_log table, charts will work normally"
puts "4. If not, you'll see a warning instead of inflated charts"

puts "\n💡 To Enable Full Accuracy:"
puts "Run: ruby scripts/run_activity_log_migration.rb"
puts "This creates the meme_activity_log table for accurate metrics"

puts "\n✅ Done!"
