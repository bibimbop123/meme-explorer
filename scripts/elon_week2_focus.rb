#!/usr/bin/env ruby
# frozen_string_literal: true

# ELON MUSK WEEK 2: FOCUS
# Remove features that don't serve the core mission

require 'fileutils'

class ElonWeek2Focus
  def initialize(dry_run: false)
    @dry_run = dry_run
    @deleted_count = 0
    @deleted_size = 0
  end

  def execute
    print_header
    
    # Step 1: Remove "guide" system (over-engineered content)
    remove_guides_system
    
    # Step 2: Remove metrics/analytics bloat
    remove_analytics_bloat
    
    # Step 3: Remove "premium" feature (not core)
    remove_premium_system
    
    # Step 4: Remove gamification remnants
    remove_gamification_remnants
    
    # Step 5: Remove redundant routes
    remove_redundant_routes
    
    # Step 6: Clean up dead workers
    remove_dead_workers
    
    print_summary
  end

  private

  def print_header
    puts "=" * 80
    puts "🎯 ELON MUSK WEEK 2: FOCUS 🎯"
    puts "=" * 80
    puts
    puts "Mode: #{@dry_run ? 'DRY RUN' : 'LIVE EXECUTION'}"
    puts
    puts "Mission: Browse funny memes from Reddit. That's it."
    puts "Removing: Everything that doesn't serve this mission."
    puts
  end

  def remove_guides_system
    puts "📋 STEP 1: Removing Guides System (Users don't read guides)"
    
    files = [
      'routes/guides.rb',
      'views/guides/guides_index.erb',
      'views/guides/getting_started.erb',
      'views/guides/personalization.erb',
      'views/guides/quality_system.erb',
      'views/guides/meme_formats.erb',
      'views/guides/faq.erb',
      'views/guides/discovery.erb'
    ]
    
    files.each { |f| delete_file(f) }
    
    # Remove guides directory if empty
    delete_directory('views/guides') if Dir.exist?('views/guides') && Dir.empty?('views/guides')
    puts
  end

  def remove_analytics_bloat
    puts "📋 STEP 2: Removing Analytics Bloat (You need usage, not 50 metrics)"
    
    files = [
      'routes/behavioral_tracking.rb',
      'routes/algorithm_metrics.rb',
      'routes/session_metrics.rb',
      'routes/metrics_routes.rb',
      'routes/meme_stats.rb',
      'views/metrics.erb',
      'views/admin/performance.erb',
      'views/admin/revenue.erb',
      'lib/services/analytics_service.rb',
      'lib/services/metrics_tracker_service.rb',
      'lib/services/performance_tracker.rb',
      'lib/services/revenue_tracker.rb',
      'lib/services/algorithm_config_service.rb',
      'lib/services/activity_tracker_service.rb',
      'lib/services/view_tracker_service.rb',
      'lib/services/session_tracker_service.rb',
      'public/js/activity-tracker.js',
      'public/js/ifunny-tracking.js',
      'public/js/content-feedback.js'
    ]
    
    files.each { |f| delete_file(f) }
    puts
  end

  def remove_premium_system
    puts "📋 STEP 3: Removing Premium System (Not profitable yet, premature)"
    
    files = [
      'lib/services/premium_service.rb',
      'views/premium.erb',
      'views/premium_success.erb',
      'db/migrations/add_premium_tier_2026.sql',
      'scripts/run_premium_migration.rb'
    ]
    
    files.each { |f| delete_file(f) }
    puts
  end

  def remove_gamification_remnants
    puts "📋 STEP 4: Removing Gamification Remnants"
    
    files = [
      'lib/services/surprise_rewards_service.rb',
      'lib/services/milestone_service.rb',
      'lib/services/leaderboard_service.rb',
      'lib/helpers/gamification_helpers.rb',
      'routes/reactions.rb',
      'scripts/recalculate_leaderboard.rb',
      'scripts/fix_gamification_tables.rb',
      'scripts/fix_leaderboard_sync.rb',
      'scripts/run_leaderboard_migration.rb',
      'scripts/migrate_leaderboard_data.rb',
      'scripts/calculate_leaderboard_scores.rb',
      'db/migrations/add_gamification_tables.sql',
      'db/migrations/postgres_add_gamification.sql',
      'db/migrations/enhance_leaderboard_system.sql',
      'db/migrations/add_ifunny_features.sql',
      'scripts/run_ifunny_migration.rb',
      'public/js/reactions-v2.js'
    ]
    
    files.each { |f| delete_file(f) }
    puts
  end

  def remove_redundant_routes
    puts "📋 STEP 5: Removing Redundant Routes"
    
    files = [
      'routes/enhanced_random.rb',
      'routes/trending_api.rb',
      'routes/web_vitals.rb',
      'routes/meme_stats.rb',
      'views/admin/ab_testing.erb',
      'views/admin/ab_testing_detail.erb'
    ]
    
    files.each { |f| delete_file(f) }
    puts
  end

  def remove_dead_workers
    puts "📋 STEP 6: Removing Dead/Overcomplicated Workers"
    
    files = [
      'app/workers/daily_digest_worker.rb',
      'app/workers/activity_aggregation_worker.rb',
      'app/workers/materialized_view_refresh_worker.rb',
      'app/workers/image_health_worker.rb',
      'app/workers/similar_meme_prefetch_worker.rb',
      'lib/services/image_health_service.rb',
      'lib/services/similar_meme_service.rb',
      'lib/services/seo_service.rb',
      'lib/helpers/seo_helpers.rb',
      'scripts/run_broken_images_migration.rb',
      'db/migrations/add_broken_images_table.sql'
    ]
    
    files.each { |f| delete_file(f) }
    puts
  end

  def delete_file(relative_path)
    full_path = File.join(Dir.pwd, relative_path)
    
    return unless File.exist?(full_path)
    
    size = File.size(full_path)
    size_kb = (size / 1024.0).round(1)
    
    if @dry_run
      puts "  [DRY RUN] Would delete: #{relative_path} (#{size_kb}KB)"
    else
      FileUtils.rm_f(full_path)
      @deleted_count += 1
      @deleted_size += size
      puts "  ✓ Deleted: #{relative_path} (#{size_kb}KB)"
    end
  end

  def delete_directory(relative_path)
    full_path = File.join(Dir.pwd, relative_path)
    
    return unless Dir.exist?(full_path)
    
    if @dry_run
      puts "  [DRY RUN] Would delete directory: #{relative_path}"
    else
      FileUtils.rm_rf(full_path)
      puts "  ✓ Deleted directory: #{relative_path}"
    end
  end

  def print_summary
    puts "=" * 80
    puts "📊 WEEK 2 FOCUS SUMMARY"
    puts "=" * 80
    puts
    
    if @dry_run
      puts "  This was a DRY RUN. No files were actually deleted."
      puts "  Run without --dry-run to execute."
    else
      size_mb = (@deleted_size / 1024.0 / 1024.0).round(1)
      puts "  📄 Files deleted:     #{@deleted_count}"
      puts "  💾 Space saved:       #{size_mb}MB"
    end
    
    puts
    puts "=" * 80
    puts
    puts "✅ WEEK 2 DAY 1 COMPLETE!" unless @dry_run
    puts
    puts "NEXT STEPS:"
    puts "1. Remove route registrations from app.rb"
    puts "2. Update README with clear one-sentence mission"
    puts "3. Test core flow: Browse → Like → Save"
    puts "4. Commit: 'Week 2: Focus - define clear mission, remove bloat'"
    puts
    puts "THE MISSION:"
    puts "  \"Browse the best memes from Reddit. Laugh. Share. That's it.\""
    puts
    puts "=" * 80
  end
end

# Parse arguments
dry_run = ARGV.include?('--dry-run')

unless dry_run
  puts
  puts "🔥 WARNING: This will delete files related to:"
  puts "  - Guides system"
  puts "  - Analytics/metrics bloat"
  puts "  - Premium features"
  puts "  - Gamification remnants"
  puts "  - Redundant routes & workers"
  puts
  print "Are you ready to focus? (yes/no): "
  
  response = $stdin.gets.chomp.downcase
  unless response == 'yes'
    puts "Aborting."
    exit 1
  end
  puts
end

ElonWeek2Focus.new(dry_run: dry_run).execute
