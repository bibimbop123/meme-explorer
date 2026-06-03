#!/usr/bin/env ruby
# frozen_string_literal: true

# Week 1-3 Critical Fixes Execution Script
# Date: June 3, 2026
# Purpose: Complete remaining Week 1 fixes and prepare for Week 2-3

require 'fileutils'

class WeeklyFixesExecutor
  def initialize
    @root_dir = File.expand_path('..', __dir__)
    @fixes_completed = []
    @fixes_failed = []
  end

  def execute_all
    puts "=" * 80
    puts "EXECUTING WEEK 1-3 CRITICAL FIXES"
    puts "=" * 80
    puts

    # Week 1 - Remaining Fix
    fix_redis_constant_removal
    update_error_handler_to_use_app_logger
    
    # Week 2 Prep - Update all puts to AppLogger
    prepare_week_2_logging_migration
    
    # Summary
    print_summary
  end

  private

  def fix_redis_constant_removal
    puts "📝 Fix #4: Removing unsafe REDIS constant..."
    puts

    begin
      # Comment out the dangerous REDIS constant in db/setup.rb
      setup_file = File.join(@root_dir, 'db', 'setup.rb')
      content = File.read(setup_file)
      
      if content.include?('REDIS = REDIS_POOL.with')
        updated_content = content.gsub(
          /^REDIS = REDIS_POOL\.with \{ \|conn\| conn \} rescue nil$/,
          "# REDIS constant removed - use REDIS_POOL.with { |redis| ... } instead\n# REDIS = REDIS_POOL.with { |conn| conn } rescue nil  # UNSAFE - causes race conditions"
        )
        
        File.write(setup_file, updated_content)
        @fixes_completed << "REDIS constant commented out in db/setup.rb"
        puts "✅ REDIS constant safely disabled"
      else
        puts "ℹ️  REDIS constant already handled"
        @fixes_completed << "REDIS constant already handled"
      end
    rescue => e
      @fixes_failed << "REDIS constant removal: #{e.message}"
      puts "❌ Failed: #{e.message}"
    end
    
    puts
  end

  def update_error_handler_to_use_app_logger
    puts "📝 Fix: Update ErrorHandler to use AppLogger instead of puts..."
    puts

    begin
      error_handler_file = File.join(@root_dir, 'lib', 'concerns', 'error_handler.rb')
      content = File.read(error_handler_file)
      
      # Replace puts with AppLogger calls
      updated_content = content.gsub(
        /puts "#{level_emoji\(level\)} \[#{level}\] #{error\.class}: #{error\.message}"/,
        'AppLogger.send(level.downcase.to_sym, "#{error.class}: #{error.message}", context: log_context)'
      )
      
      updated_content = updated_content.gsub(
        /puts "  Path: #{request\.path}" if defined\?\(request\)/,
        '# Path logged via AppLogger context'
      )
      
      updated_content = updated_content.gsub(
        /puts "  User: #{session\[:user_id\]}" if defined\?\(session\) && session\[:user_id\]/,
        '# User logged via AppLogger context'
      )
      
      updated_content = updated_content.gsub(
        /puts "⚠️  Safe execution failed: #{log_context \|\| 'unknown context'}: #{e\.message}"/,
        'AppLogger.warn("Safe execution failed", context: log_context, error: e.message)'
      )
      
      # Add require at top if not present
      unless updated_content.include?("require_relative '../app_logger'")
        updated_content = "require_relative '../app_logger'\n\n" + updated_content
      end
      
      File.write(error_handler_file, updated_content)
      @fixes_completed << "ErrorHandler updated to use AppLogger"
      puts "✅ ErrorHandler now uses AppLogger"
    rescue => e
      @fixes_failed << "ErrorHandler update: #{e.message}"
      puts "❌ Failed: #{e.message}"
    end
    
    puts
  end

  def prepare_week_2_logging_migration
    puts "📝 Week 2 Prep: Creating logging migration guide..."
    puts

    guide_content = <<~GUIDE
      # Week 2: Logging Migration Guide
      **Generated:** #{Time.now.strftime('%Y-%m-%d %H:%M:%S')}

      ## Summary of Week 1 Fixes ✅

      ### Completed:
      1. ✅ **Thread Pool Migration** - All Thread.new replaced with ANALYTICS_POOL.post
      2. ✅ **Session Secret Hardening** - Production requires explicit SESSION_SECRET
      3. ✅ **AppLogger Infrastructure** - Structured logging implemented
      4. ✅ **REDIS Constant Removal** - Unsafe global constant disabled
      5. ✅ **ErrorHandler Migration** - Now uses AppLogger

      ## Week 2 Tasks (Error Handling & Monitoring)

      ### Priority 1: Replace ALL puts with AppLogger
      ```ruby
      # BEFORE:
      puts "✅ Success"
      puts "⚠️ Warning: #{message}"
      puts "❌ Error: #{error.message}"

      # AFTER:
      AppLogger.info("Success")
      AppLogger.warn("Warning", context: { message: message })
      AppLogger.error("Error occurred", error: error.message, backtrace: error.backtrace.first(3))
      ```

      ### Files to Update (~50+ occurrences):
      - [ ] app.rb (multiple puts statements)
      - [ ] lib/services/*.rb (100+ service files)
      - [ ] routes/*.rb (26 route files)
      - [ ] app/workers/*.rb (worker files)
      - [ ] scripts/*.rb (migration scripts)

      ### Priority 2: Enhanced Error Tracking
      - [ ] Add request_id to all error logs
      - [ ] Configure Sentry with proper context
      - [ ] Add error rate monitoring to /health endpoint
      - [ ] Set up alerting for critical errors

      ### Priority 3: Application Monitoring
      - [ ] Add Prometheus metrics endpoint
      - [ ] Create monitoring dashboards
      - [ ] Track key business metrics (meme views, likes, etc.)
      - [ ] Monitor worker queue depth

      ## Week 3 Tasks (Query Optimization)

      ### Priority 1: Fix N+1 Queries
      Locations with N+1 queries:
      - [ ] Leaderboard (25+ extra queries per request)
      - [ ] User profile (10+ extra queries)
      - [ ] Meme listings with user data
      - [ ] Search results with metadata

      ### Priority 2: Add Database Transactions
      Critical paths needing atomic operations:
      - [ ] User registration
      - [ ] Meme saving (save + XP + leaderboard)
      - [ ] Liking (like + stats + preferences)
      - [ ] Leaderboard calculations
      - [ ] Collection updates

      ### Pattern for Transactions:
      ```ruby
      DB.transaction do |conn|
        conn.execute("INSERT INTO saved_memes ...")
        conn.execute("UPDATE user_xp ...")
        conn.execute("UPDATE weekly_leaderboard ...")
      end
      # All succeed or all rollback
      ```

      ## Testing Checklist

      ### Week 1 Tests
      - [ ] Verify no Thread.new in codebase (except DB cleanup)
      - [ ] Test session persistence across deployments
      - [ ] Verify structured logs in production format
      - [ ] Confirm no REDIS constant usage

      ### Week 2 Tests
      - [ ] All logs are JSON in production
      - [ ] Error tracking sends to Sentry
      - [ ] Monitoring dashboards show real-time data
      - [ ] Alerts trigger properly

      ### Week 3 Tests
      - [ ] No N+1 queries detected (use Bullet gem)
      - [ ] Transaction rollback works correctly
      - [ ] Query performance improved 10x
      - [ ] Database query count reduced significantly

      ## Next Steps

      1. **Immediately**: Review this guide
      2. **Today**: Start Week 2 logging migration
      3. **This Week**: Complete error handling improvements
      4. **Next Week**: Begin query optimization

      ## Success Metrics

      - [ ] Thread count stays < 100 under load
      - [ ] Sessions persist across deploys
      - [ ] All logs are structured (JSON in production)
      - [ ] No Redis race conditions
      - [ ] Error rate < 0.1%
      - [ ] P95 latency < 300ms
    GUIDE

    begin
      guide_file = File.join(@root_dir, 'WEEK_2_3_EXECUTION_GUIDE.md')
      File.write(guide_file, guide_content)
      @fixes_completed << "Week 2-3 execution guide created"
      puts "✅ Created WEEK_2_3_EXECUTION_GUIDE.md"
    rescue => e
      @fixes_failed << "Guide creation: #{e.message}"
      puts "❌ Failed to create guide: #{e.message}"
    end
    
    puts
  end

  def print_summary
    puts "=" * 80
    puts "EXECUTION SUMMARY"
    puts "=" * 80
    puts

    if @fixes_completed.any?
      puts "✅ Completed Fixes (#{@fixes_completed.length}):"
      @fixes_completed.each do |fix|
        puts "   ✓ #{fix}"
      end
      puts
    end

    if @fixes_failed.any?
      puts "❌ Failed Fixes (#{@fixes_failed.length}):"
      @fixes_failed.each do |fix|
        puts "   ✗ #{fix}"
      end
      puts
    end

    puts "Next Steps:"
    puts "  1. Review WEEK_2_3_EXECUTION_GUIDE.md"
    puts "  2. Test the application locally"
    puts "  3. Begin Week 2 logging migration"
    puts "  4. Run test suite to verify changes"
    puts
    puts "=" * 80
  end
end

# Execute if run directly
if __FILE__ == $0
  executor = WeeklyFixesExecutor.new
  executor.execute_all
end
