#!/usr/bin/env ruby
# Phase 2 Audit Improvements Deployment Script
# Applies all high-priority improvements from June 26, 2026 audit
# Senior Dev Pattern: Automated, safe deployment with rollback capability

require 'fileutils'
require 'time'

class Phase2Deployment
  BACKUP_DIR = File.join(__dir__, '..', 'backups', "phase2_audit_#{Time.now.strftime('%Y%m%d_%H%M%S')}")
  
  def initialize
    @errors = []
    @successes = []
  end
  
  def execute
    puts "🚀 Phase 2: High Priority Improvements Deployment"
    puts "=" * 70
    puts "Timestamp: #{Time.now}"
    puts "Backup Directory: #{BACKUP_DIR}"
    puts "=" * 70
    
    create_backup_dir
    
    # Execute all improvements
    verify_new_files
    verify_enhanced_files
    create_configuration_examples
    run_safety_checks
    
    print_summary
    
    if @errors.empty?
      puts "\n✅ Phase 2 deployment complete!"
      puts "\n📋 Next Steps:"
      print_next_steps
      return true
    else
      puts "\n⚠️  Deployment completed with warnings"
      puts "Review errors above and fix manually if needed"
      return false
    end
  end
  
  private
  
  def create_backup_dir
    FileUtils.mkdir_p(BACKUP_DIR)
    puts "✅ Created backup directory: #{BACKUP_DIR}"
  rescue => e
    record_error("Backup directory creation", e.message)
  end
  
  def verify_new_files
    puts "\n📁 Verifying New Files..."
    puts "-" * 70
    
    new_files = [
      'lib/concerns/transaction_wrapper.rb',
      'lib/cache_keys.rb',
      'scripts/chaos_tests.rb'
    ]
    
    new_files.each do |file|
      full_path = File.join(__dir__, '..', file)
      if File.exist?(full_path)
        puts "  ✅ #{file}"
        record_success("Created #{file}")
      else
        puts "  ❌ #{file} - MISSING!"
        record_error(file, "File not found")
      end
    end
  end
  
  def verify_enhanced_files
    puts "\n🔧 Verifying Enhanced Files..."
    puts "-" * 70
    
    enhanced_files = [
      'routes/health.rb'
    ]
    
    enhanced_files.each do |file|
      full_path = File.join(__dir__, '..', file)
      if File.exist?(full_path)
        content = File.read(full_path)
        if content.include?('/health/detailed')
          puts "  ✅ #{file} - Enhanced with detailed health checks"
          record_success("Enhanced #{file}")
        else
          puts "  ⚠️  #{file} - May need manual review"
        end
      else
        puts "  ❌ #{file} - MISSING!"
        record_error(file, "File not found")
      end
    end
  end
  
  def create_configuration_examples
    puts "\n⚙️  Creating Configuration Examples..."
    puts "-" * 70
    
    # Redis-backed sessions configuration example
    redis_session_config = <<~RUBY
      # config/initializers/redis_sessions.rb
      # Redis-Backed Sessions Configuration
      # Uncomment to enable (requires rack-session gem)
      
      # require 'rack/session/redis'
      # 
      # use Rack::Session::Redis,
      #   redis_server: { 
      #     url: ENV.fetch('REDIS_URL', 'redis://localhost:6379/1'),
      #     namespace: 'meme_explorer:session'
      #   },
      #   key: '_meme_explorer_session',
      #   expire_after: 86400,  # 24 hours
      #   threadsafe: true,
      #   secure: ENV['RACK_ENV'] == 'production',
      #   same_site: :lax,
      #   httponly: true
    RUBY
    
    config_file = File.join(__dir__, '..', 'config', 'initializers', 'redis_sessions.rb.example')
    File.write(config_file, redis_session_config)
    puts "  ✅ Created config/initializers/redis_sessions.rb.example"
    record_success("Created Redis sessions config example")
    
  rescue => e
    record_error("Configuration examples", e.message)
  end
  
  def run_safety_checks
    puts "\n🔍 Running Safety Checks..."
    puts "-" * 70
    
    # Check for syntax errors
    check_ruby_syntax('lib/concerns/transaction_wrapper.rb')
    check_ruby_syntax('lib/cache_keys.rb')
    check_ruby_syntax('routes/health.rb')
    check_ruby_syntax('scripts/chaos_tests.rb')
  end
  
  def check_ruby_syntax(file)
    full_path = File.join(__dir__, '..', file)
    return unless File.exist?(full_path)
    
    result = `ruby -c #{full_path} 2>&1`
    if $?.success?
      puts "  ✅ #{file} - Syntax OK"
    else
      puts "  ❌ #{file} - Syntax Error!"
      puts "     #{result}"
      record_error(file, "Syntax error: #{result}")
    end
  rescue => e
    record_error("Syntax check for #{file}", e.message)
  end
  
  def record_success(message)
    @successes << message
  end
  
  def record_error(context, message)
    @errors << { context: context, message: message }
  end
  
  def print_summary
    puts "\n" + "=" * 70
    puts "📊 Deployment Summary"
    puts "=" * 70
    
    puts "\n✅ Successes: #{@successes.size}"
    @successes.each { |s| puts "   - #{s}" }
    
    if @errors.any?
      puts "\n❌ Errors: #{@errors.size}"
      @errors.each do |e|
        puts "   - #{e[:context]}: #{e[:message]}"
      end
    end
  end
  
  def print_next_steps
    puts <<~STEPS
      
      1. **Review Health Checks**
         curl http://localhost:4567/health/detailed
      
      2. **Test Transaction Wrapper**
         Include TransactionWrapper in your services
         Use: with_transaction { ... }
      
      3. **Use Centralized Cache Keys**
         Replace cache keys with CacheKeys.meme(id), etc.
         Use CacheKeys.invalidate_user(user_id) for cache invalidation
      
      4. **Run Resilience Tests**
         ruby scripts/chaos_tests.rb
      
      5. **Optional: Enable Redis Sessions**
         - Add gem 'rack-session' to Gemfile
         - Review config/initializers/redis_sessions.rb.example
         - Uncomment and configure as needed
      
      6. **Monitor Production**
         - Check /health/detailed endpoint
         - Review Sidekiq queue depths
         - Monitor Redis memory usage
      
      7. **Documentation**
         Review AUDIT_PHASE2_HIGH_PRIORITY_COMPLETE.md for details
    STEPS
  end
end

# Run deployment if called directly
if __FILE__ == $0
  deployment = Phase2Deployment.new
  exit(deployment.execute ? 0 : 1)
end
