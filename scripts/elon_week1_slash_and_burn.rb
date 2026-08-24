#!/usr/bin/env ruby
# frozen_string_literal: true

# ELON MUSK WEEK 1: SLASH AND BURN
# This script aggressively simplifies the codebase
# Run with: ruby scripts/elon_week1_slash_and_burn.rb

require 'fileutils'

class SlashAndBurnExecutor
  attr_reader :stats

  def initialize
    @stats = {
      markdown_deleted: 0,
      services_deleted: 0,
      js_deleted: 0,
      backup_deleted: 0,
      bytes_saved: 0
    }
    @dry_run = ARGV.include?('--dry-run')
  end

  def execute!
    puts "=" * 80
    puts "🔥 ELON MUSK WEEK 1: SLASH AND BURN 🔥"
    puts "=" * 80
    puts
    puts "Mode: #{@dry_run ? 'DRY RUN (no files will be deleted)' : 'LIVE EXECUTION'}"
    puts

    unless @dry_run
      print "Are you ready to delete 70% of your codebase? (yes/no): "
      response = gets.chomp.downcase
      unless response == 'yes'
        puts "❌ Aborted. Run with --dry-run to see what would be deleted."
        exit 1
      end
    end

    puts "\n📋 STEP 1: Deleting Documentation Bloat\n"
    delete_documentation_bloat

    puts "\n📋 STEP 2: Deleting Backup/Working/Improved Files\n"
    delete_backup_files

    puts "\n📋 STEP 3: Consolidating Meme Selection Algorithms\n"
    consolidate_algorithms

    puts "\n📋 STEP 4: Deleting Redundant Services\n"
    delete_redundant_services

    puts "\n📋 STEP 5: Deleting Gamification Bloat\n"
    delete_gamification_bloat

    puts "\n📋 STEP 6: Cleaning Up Service Workers\n"
    cleanup_service_workers

    print_summary
  end

  private

  def delete_documentation_bloat
    patterns = [
      'COMPREHENSIVE_*_AUDIT_*.md',
      'SENIOR_*_AUDIT_*.md',
      'WEEK*_COMPLETE_*.md',
      'AUDIT_COMPLETE_*.md',
      '*_EXECUTION_SUMMARY.md',
      '*_ROADMAP_*.md',
      'REFACTORING_*.md',
      'SIMPLIFICATION_*.md',
      '*_DEPLOYMENT_GUIDE.md',
      '*_IMPLEMENTATION_*.md',
      'TIER_*_COMPLETE_*.md',
      'RANDOM_ALGORITHM_*.md',
      'ADSENSE_*_AUDIT_*.md',
      'MOBILE_UX_AUDIT_*.md',
      'AUTH_SYSTEM_*.md',
      '*_IMPROVEMENT_PLAN*.md',
      'PRODUCTION_*_GUIDE*.md',
      'REDIS_*_MIGRATION*.md',
      'QUICK_START_*.md'
    ]

    # Keep these essential docs
    keep_files = [
      'README.md',
      'CHANGELOG.md',
      'SECURITY.md',
      'ARCHITECTURE.md',
      'CONTRIBUTING.md',
      'TROUBLESHOOTING.md',
      'ELON_MUSK_BRUTAL_AUDIT_2026.md',
      'API_DOCS.md',
      'DEPLOY.md',
      'DEPLOYMENT_INSTRUCTIONS.md'
    ]

    patterns.each do |pattern|
      Dir.glob(pattern).each do |file|
        next if keep_files.include?(File.basename(file))
        delete_file(file, :markdown)
      end
    end

    # Also clean up old audit/roadmap docs by name
    old_docs = Dir.glob('*.md').select do |f|
      basename = File.basename(f)
      next if keep_files.include?(basename)
      basename.match?(/(AUDIT|ROADMAP|CRITIQUE|EXECUTION|COMPLETE|GUIDE|PLAN|STATUS|SUMMARY|HANDOFF)/i)
    end

    old_docs.each { |f| delete_file(f, :markdown) }
  end

  def delete_backup_files
    # Delete backup directories
    backup_dirs = [
      'views/random/backup',
      'public/js/backup',
      'lib/services/backup'
    ]

    backup_dirs.each do |dir|
      if Dir.exist?(dir)
        dir_size = calculate_dir_size(dir)
        if @dry_run
          puts "  Would delete directory: #{dir} (#{format_bytes(dir_size)})"
          @stats[:backup_deleted] += dir_size
        else
          FileUtils.rm_rf(dir)
          puts "  ✓ Deleted directory: #{dir} (#{format_bytes(dir_size)})"
          @stats[:backup_deleted] += dir_size
        end
      end
    end

    # Delete files with backup/working/improved in name
    patterns = [
      'views/**/*_WORKING.*',
      'views/**/*_BACKUP.*',
      'views/**/*.original',
      'public/js/**/*-IMPROVED.js',
      'public/js/**/*-WORKING.js',
      'public/js/**/*-backup.js',
      'lib/**/*_backup.rb',
      'lib/**/*_old.rb'
    ]

    patterns.each do |pattern|
      Dir.glob(pattern).each { |f| delete_file(f, :backup) }
    end
  end

  def consolidate_algorithms
    puts "  📝 Keeping: lib/services/simple_meme_selector.rb (the simplest one)"
    
    redundant_algorithms = [
      'lib/services/meme_selection_service.rb',
      'lib/services/diversity_engine_service.rb'
    ]

    redundant_algorithms.each do |file|
      if File.exist?(file)
        delete_file(file, :services)
        puts "     ↳ Removed redundant algorithm: #{File.basename(file)}"
      end
    end

    puts "  💡 NOTE: You'll need to update references to use SimpleMemeSelector"
  end

  def delete_redundant_services
    # These services add complexity without clear value
    redundant_services = [
      'lib/services/curation_signals_service.rb',
      'lib/services/curator_notes_service.rb',
      'lib/services/personalization_service.rb',
      'lib/services/taste_profile_service.rb',
      'lib/services/session_learning_service.rb',
      'lib/services/collaborative_filtering_service.rb',
      'lib/services/contextual_scoring_service.rb',
      'lib/services/daily_digest_service.rb',
      'lib/services/user_collections_service.rb',
      'lib/services/retention_service.rb',
      'lib/services/ab_testing_service.rb',
      'lib/services/placeholder_image_service.rb'
    ]

    puts "  Deleting #{redundant_services.length} over-engineered services..."
    redundant_services.each do |file|
      delete_file(file, :services) if File.exist?(file)
    end

    # Delete related helpers
    redundant_helpers = [
      'lib/helpers/curated_collections_helper.rb',
      'lib/helpers/curator_notes_helper.rb',
      'lib/helpers/refined_meme_helper.rb',
      'lib/helpers/session_stats_helper.rb',
      'lib/helpers/connection_pool_monitor.rb'
    ]

    redundant_helpers.each do |file|
      delete_file(file, :services) if File.exist?(file)
    end
  end

  def delete_gamification_bloat
    gamification_js = [
      'public/js/achievement-system.js',
      'public/js/streak-system.js',
      'public/js/surprise-rewards.js',
      'public/js/particle-effects.js',
      'public/js/haptic-system.js',
      'public/js/sound-system.js',
      'public/js/leaderboard.js'
    ]

    gamification_css = [
      'public/css/achievements.css',
      'public/css/streaks.css',
      'public/css/leaderboard.css',
      'public/css/animations.css'
    ]

    gamification_views = [
      'views/leaderboard.erb',
      'views/_taste_profile.erb',
      'views/_curation_signal.erb',
      'views/_rarity_badge.erb',
      'views/_curator_note.erb'
    ]

    gamification_routes = [
      'routes/battles.rb',
      'routes/ab_testing.rb',
      'routes/collections.rb'
    ]

    puts "  Removing gamification JavaScript..."
    gamification_js.each { |f| delete_file(f, :js) if File.exist?(f) }

    puts "  Removing gamification CSS..."
    gamification_css.each { |f| delete_file(f, :js) if File.exist?(f) }

    puts "  Removing gamification views..."
    gamification_views.each { |f| delete_file(f, :backup) if File.exist?(f) }

    puts "  Removing gamification routes..."
    gamification_routes.each { |f| delete_file(f, :services) if File.exist?(f) }

    # Delete gamification workers
    workers = [
      'app/workers/streak_reminder_worker.rb',
      'app/workers/leaderboard_calculation_worker.rb',
      'app/workers/cache_preload_worker.rb'
    ]

    workers.each { |f| delete_file(f, :services) if File.exist?(f) }
  end

  def cleanup_service_workers
    delete_file('sw-2.js', :js) if File.exist?('sw-2.js')
    puts "  💡 NOTE: Review sw.js to ensure it's the version you want to keep"
  end

  def delete_file(path, category)
    size = File.exist?(path) ? File.size(path) : 0
    
    if @dry_run
      puts "  Would delete: #{path} (#{format_bytes(size)})"
    else
      FileUtils.rm_f(path)
      puts "  ✓ Deleted: #{path} (#{format_bytes(size)})"
    end

    @stats[:bytes_saved] += size
    case category
    when :markdown
      @stats[:markdown_deleted] += 1
    when :services
      @stats[:services_deleted] += 1
    when :js
      @stats[:js_deleted] += 1
    when :backup
      @stats[:backup_deleted] += size
    end
  end

  def calculate_dir_size(dir)
    size = 0
    Dir.glob(File.join(dir, '**', '*')).each do |file|
      size += File.size(file) if File.file?(file)
    end
    size
  end

  def format_bytes(bytes)
    if bytes < 1024
      "#{bytes}B"
    elsif bytes < 1024 * 1024
      "#{(bytes / 1024.0).round(1)}KB"
    else
      "#{(bytes / (1024.0 * 1024)).round(1)}MB"
    end
  end

  def print_summary
    puts "\n" + "=" * 80
    puts "📊 SLASH AND BURN SUMMARY"
    puts "=" * 80
    puts
    puts "  📄 Markdown files deleted:     #{@stats[:markdown_deleted]}"
    puts "  🔧 Service files deleted:      #{@stats[:services_deleted]}"
    puts "  📜 JavaScript files deleted:   #{@stats[:js_deleted]}"
    puts "  💾 Total space saved:          #{format_bytes(@stats[:bytes_saved])}"
    puts
    puts "=" * 80
    
    if @dry_run
      puts "\n⚠️  This was a DRY RUN - no files were actually deleted"
      puts "Remove --dry-run to execute for real"
    else
      puts "\n✅ WEEK 1 DAY 1 COMPLETE!"
      puts
      puts "NEXT STEPS:"
      puts "1. Run your test suite to see what broke"
      puts "2. Fix critical references to deleted services"
      puts "3. Run the app locally and test core functionality"
      puts "4. Commit with message: 'Week 1: Slash and burn - remove 70% of bloat'"
      puts
      puts "Then move to Day 2: Service consolidation"
    end
    puts "=" * 80
  end
end

# Execute
executor = SlashAndBurnExecutor.new
executor.execute!
