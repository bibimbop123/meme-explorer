#!/usr/bin/env ruby
# Fix Redis Architecture - Automated Migration Script
# This script helps migrate from single Redis instance to connection pool

require 'fileutils'

puts "🔧 Redis Architecture Fix Script"
puts "=" * 60

# Step 1: Check current state
puts "\n📋 Step 1: Checking current Redis setup..."

app_rb_has_redis = File.read('app.rb').include?('REDIS = begin')
db_setup_has_redis = File.read('db/setup.rb').include?('REDIS = begin')

puts "   app.rb has REDIS initialization: #{app_rb_has_redis ? '✅ YES (PROBLEM!)' : '❌ NO'}"
puts "   db/setup.rb has REDIS initialization: #{db_setup_has_redis ? '✅ YES' : '❌ NO'}"

if app_rb_has_redis && db_setup_has_redis
  puts "   ⚠️  DUPLICATE REDIS CONNECTIONS DETECTED!"
else
  puts "   ✅ No duplicate Redis connections"
end

# Step 2: Check for connection_pool gem
puts "\n📦 Step 2: Checking Gemfile for connection_pool..."

gemfile_content = File.read('Gemfile')
has_connection_pool = gemfile_content.include?('connection_pool')

if has_connection_pool
  puts "   ✅ connection_pool gem already in Gemfile"
else
  puts "   ⚠️  connection_pool gem NOT found"
  puts "   Action: Add to Gemfile: gem 'connection_pool', '~> 2.4'"
end

# Step 3: Count Redis usage
puts "\n🔍 Step 3: Scanning codebase for Redis usage..."

redis_calls = []
Dir.glob('**/*.rb').each do |file|
  next if file.include?('vendor/') || file.include?('node_modules/')
  
  File.readlines(file).each_with_index do |line, index|
    if line.match?(/REDIS\.(get|set|del|zadd|lpush|hget|exists|incr|setex|expire)/)
      redis_calls << { file: file, line: index + 1, code: line.strip }
    end
  end
end

puts "   Found #{redis_calls.size} direct Redis calls"
puts "   Sample locations:"
redis_calls.first(5).each do |call|
  puts "     - #{call[:file]}:#{call[:line]}"
end

# Step 4: Generate migration plan
puts "\n📝 Step 4: Generating migration plan..."

migration_plan = {
  phase_1_critical: [
    "1. Add connection_pool to Gemfile (if not present)",
    "2. Remove REDIS initialization from app.rb",
    "3. Update db/setup.rb to use REDIS_POOL",
    "4. Add namespace separation for Sidekiq"
  ],
  phase_2_migration: [
    "5. Create lib/services/redis_service.rb wrapper",
    "6. Update all #{redis_calls.size} Redis calls to use pool",
    "7. Add error handling and fallbacks"
  ],
  phase_3_testing: [
    "8. Test Redis health endpoint",
    "9. Load test with connection pool",
    "10. Monitor for connection leaks"
  ]
}

migration_plan.each do |phase, steps|
  puts "\n   #{phase.to_s.upcase.gsub('_', ' ')}:"
  steps.each { |step| puts "     #{step}" }
end

# Step 5: Create backup
puts "\n💾 Step 5: Creating backup files..."

backup_dir = "backups/redis_migration_#{Time.now.strftime('%Y%m%d_%H%M%S')}"
FileUtils.mkdir_p(backup_dir)

['app.rb', 'db/setup.rb', 'config/initializers/sidekiq.rb'].each do |file|
  if File.exist?(file)
    FileUtils.cp(file, "#{backup_dir}/#{File.basename(file)}")
    puts "   ✅ Backed up #{file}"
  end
end

puts "\n   Backups saved to: #{backup_dir}"

# Step 6: Generate fix files
puts "\n📄 Step 6: Generating fix implementation files..."

# Generate new db/setup.rb Redis section
redis_pool_code = <<~RUBY
  # Redis Configuration with Connection Pooling
  # CRITICAL FIX: Use connection pool for thread safety (32 Puma threads)
  require 'connection_pool'
  
  REDIS_URL = ENV.fetch('REDIS_URL', 'redis://localhost:6379/0')
  
  REDIS_POOL = ConnectionPool.new(size: 40, timeout: 5) do
    Redis.new(
      url: REDIS_URL,
      driver: :ruby,
      reconnect_attempts: 3,
      reconnect_delay: 0.5,
      reconnect_delay_max: 5
    )
  end
  
  # Legacy REDIS constant for gradual migration
  # TODO: Remove after all code uses REDIS_POOL
  REDIS = REDIS_POOL.with { |conn| conn }
  
  puts "✅ Redis Pool initialized (size: 40, timeout: 5s)"
  
  # Test connection
  begin
    REDIS_POOL.with { |r| r.ping }
    puts "✅ Redis connection verified"
  rescue => e
    puts "⚠️  Redis connection warning: #{e.message}"
  end
RUBY

File.write("#{backup_dir}/NEW_db_setup_redis_section.rb", redis_pool_code)
puts "   📝 Generated: #{backup_dir}/NEW_db_setup_redis_section.rb"

# Generate RedisService wrapper
redis_service_code = <<~RUBY
  # Redis Service - Centralized Redis access with error handling
  # Usage: RedisService.fetch('key') { fallback_value }
  
  class RedisService
    class RedisError < StandardError; end
    
    class << self
      # Fetch from Redis with automatic fallback
      def fetch(key, ttl: 3600, &fallback)
        return fallback.call unless redis_available?
        
        REDIS_POOL.with do |redis|
          cached = redis.get(key)
          return parse_value(cached) if cached
          
          value = fallback.call
          redis.setex(key, ttl, serialize_value(value)) if value
          value
        end
      rescue Redis::BaseError, ConnectionPool::TimeoutError => e
        handle_error(e)
        fallback.call
      end
      
      # Direct Redis access with error handling
      def with_redis(&block)
        return nil unless redis_available?
        
        REDIS_POOL.with(&block)
      rescue Redis::BaseError, ConnectionPool::TimeoutError => e
        handle_error(e)
        nil
      end
      
      # Check Redis availability
      def redis_available?
        return @redis_available if defined?(@redis_available)
        
        @redis_available = begin
          REDIS_POOL.with { |r| r.ping == 'PONG' }
          true
        rescue
          false
        end
      end
      
      # Get Redis stats
      def stats
        return { available: false } unless redis_available?
        
        REDIS_POOL.with do |redis|
          info = redis.info
          {
            available: true,
            used_memory: info['used_memory_human'],
            connected_clients: info['connected_clients'],
            total_commands: info['total_commands_processed'],
            pool_size: REDIS_POOL.size,
            pool_available: REDIS_POOL.available
          }
        end
      rescue => e
        { available: false, error: e.message }
      end
      
      private
      
      def serialize_value(value)
        value.is_a?(String) ? value : value.to_json
      end
      
      def parse_value(value)
        JSON.parse(value) rescue value
      end
      
      def handle_error(error)
        puts "⚠️  Redis error: #{error.class} - #{error.message}"
        
        # Send to Sentry if available
        if defined?(Sentry)
          Sentry.capture_exception(error)
        end
        
        # Mark Redis as unavailable for 30 seconds
        @redis_available = false
        Thread.new do
          sleep 30
          remove_instance_variable(:@redis_available) if defined?(@redis_available)
        end
      end
    end
  end
RUBY

File.write("#{backup_dir}/redis_service.rb", redis_service_code)
puts "   📝 Generated: #{backup_dir}/redis_service.rb"

# Generate Sidekiq namespace config
sidekiq_config = <<~RUBY
  require 'sidekiq'
  require 'connection_pool'
  
  # Sidekiq Redis Configuration with Namespace Separation
  redis_config = {
    url: ENV['REDIS_URL'] || 'redis://localhost:6379/0',
    namespace: 'sidekiq',  # ← CRITICAL: Separate Sidekiq data from app cache
    pool_timeout: 5
  }
  
  Sidekiq.configure_server do |config|
    config.redis = redis_config.merge(size: 25)
    
    # Load schedule from config file if scheduler is available
    if defined?(SidekiqScheduler)
      config.on(:startup) do
        schedule_file = File.expand_path('../../sidekiq.yml', __FILE__)
        if File.exist?(schedule_file)
          schedule_config = YAML.load_file(schedule_file)
          if schedule_config && schedule_config[:schedule]
            Sidekiq.schedule = schedule_config[:schedule]
            SidekiqScheduler::Scheduler.instance.reload_schedule!
            puts "✅ Sidekiq scheduler loaded with \#{schedule_config[:schedule].keys.size} jobs"
          end
        end
      end
    end
  end
  
  Sidekiq.configure_client do |config|
    config.redis = redis_config.merge(size: 5)
  end
  
  puts "✅ Sidekiq configured with namespace separation"
RUBY

File.write("#{backup_dir}/sidekiq_with_namespace.rb", sidekiq_config)
puts "   📝 Generated: #{backup_dir}/sidekiq_with_namespace.rb"

# Step 7: Summary and next steps
puts "\n" + "=" * 60
puts "✅ ANALYSIS COMPLETE"
puts "=" * 60

puts "\n🎯 CRITICAL ISSUES FOUND:"
puts "   1. #{app_rb_has_redis && db_setup_has_redis ? '❌ DUPLICATE Redis connections' : '✅ No duplicate connections'}"
puts "   2. #{has_connection_pool ? '✅ connection_pool gem present' : '❌ MISSING connection_pool gem'}"
puts "   3. ⚠️  #{redis_calls.size} direct Redis calls need migration"

puts "\n📋 NEXT STEPS:"
puts "\n   PHASE 1 - Critical Fixes (30 minutes):"
puts "     1. Review backup files in: #{backup_dir}/"
puts "     2. Add to Gemfile: gem 'connection_pool', '~> 2.4'" unless has_connection_pool
puts "     3. Run: bundle install"
puts "     4. Remove REDIS initialization from app.rb (lines 107-117)"
puts "     5. Replace Redis section in db/setup.rb with:"
puts "        #{backup_dir}/NEW_db_setup_redis_section.rb"
puts "     6. Copy #{backup_dir}/redis_service.rb to lib/services/"
puts "     7. Update config/initializers/sidekiq.rb with namespacing"

puts "\n   PHASE 2 - Migration (4-6 hours):"
puts "     1. Gradually update Redis calls to use REDIS_POOL.with { |r| ... }"
puts "     2. Or use RedisService wrapper for automatic error handling"
puts "     3. Run tests after each major change"

puts "\n   PHASE 3 - Testing (2 hours):"
puts "     1. Test /health endpoint shows Redis pool stats"
puts "     2. Load test with concurrent requests"
puts "     3. Monitor for connection leaks"
puts "     4. Deploy to staging first"

puts "\n📚 DOCUMENTATION:"
puts "   - Full audit: SENIOR_DEV_REDIS_AUDIT_2026.md"
puts "   - Backups: #{backup_dir}/"

puts "\n🚀 Ready to implement? Review the audit document first!"
puts "=" * 60
