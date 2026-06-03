require 'sidekiq'

# Only load scheduler if available
begin
  require 'sidekiq-scheduler'
  $sidekiq_scheduler_available = true
rescue LoadError
  puts "⚠️  sidekiq-scheduler not available - scheduled jobs disabled"
  $sidekiq_scheduler_available = false
end

Sidekiq.configure_server do |config|
  config.redis = { url: ENV['REDIS_URL'] || 'redis://localhost:6379/0' }
  
  # Load schedule from config file if scheduler is available
  if $sidekiq_scheduler_available
    config.on(:startup) do
      schedule_file = File.expand_path('../../sidekiq.yml', __FILE__)
      if File.exist?(schedule_file)
        schedule_config = YAML.load_file(schedule_file)
        if schedule_config && schedule_config[:schedule]
          Sidekiq.schedule = schedule_config[:schedule]
          SidekiqScheduler::Scheduler.instance.reload_schedule!
          puts "✅ Sidekiq scheduler loaded with #{schedule_config[:schedule].keys.size} jobs"
        end
      end
    end
  end
end

Sidekiq.configure_client do |config|
  config.redis = { url: ENV['REDIS_URL'] || 'redis://localhost:6379/0' }
end

puts "✅ Sidekiq configured (Redis: #{ENV['REDIS_URL'] || 'redis://localhost:6379/0'})"
