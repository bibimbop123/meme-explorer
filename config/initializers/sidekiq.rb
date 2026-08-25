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
  config.redis = { 
    url: ENV['REDIS_URL'] || 'redis://localhost:6379/0'
    # NOTE (Aug 25, 2026): `namespace:` was removed here. Sidekiq 7+ dropped
    # support for redis-namespace entirely (see
    # https://github.com/sidekiq/sidekiq/blob/main/docs/7.0-Upgrade.md#redis-namespace),
    # and passing it raised an ArgumentError on every single Redis connection
    # attempt in production, breaking MemePoolManager's Redis reads on every
    # request and forcing a full ~30s Reddit re-bootstrap each time. Sidekiq's
    # own keys are already prefixed (queue:, cron_job:, etc.) so they don't
    # collide with the app's own cache keys without a namespace.
  }
  
  # Load schedule from config file if scheduler is available
  if $sidekiq_scheduler_available
    config.on(:startup) do
      schedule_file = File.expand_path('../../sidekiq.yml', __FILE__)
      if File.exist?(schedule_file)
        schedule_config = YAML.load_file(schedule_file, aliases: true)
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
  config.redis = { 
    url: ENV['REDIS_URL'] || 'redis://localhost:6379/0'
    # NOTE (Aug 25, 2026): see matching comment in configure_server above -
    # `namespace:` is no longer supported by Sidekiq 7+.
  }
end

puts "✅ Sidekiq configured (Redis: #{ENV['REDIS_URL'] || 'redis://localhost:6379/0'})"
