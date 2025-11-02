# Puma configuration for multi-worker deployment
# Configure puma to start in cluster mode

# Binding
bind "tcp://0.0.0.0:3000"

# Use cluster mode with multiple workers
workers Integer(ENV.fetch("WEB_CONCURRENCY", 3))

# Each worker has its own thread pool
threads_count = Integer(ENV.fetch("RAILS_MAX_THREADS", 5))
threads threads_count, threads_count

# Cluster mode settings
preload_app!

# Timeouts
worker_shutdown_timeout 30

# Application environment
environment ENV.fetch("RACK_ENV", "development")

# Logging
stdout_redirect "log/puma.log", "log/puma-error.log", true

# PID file for process management
pidfile "tmp/pids/puma.pid"

# State file
state_path "tmp/pids/puma.state"

# On boot event - runs once per cluster
on_worker_boot do
  # Reconnect to database on worker boot
  if ENV['DATABASE_URL']
    require 'sequel'
    DB.disconnect
    Object.const_set(:DB, Sequel.connect(ENV['DATABASE_URL']))
  end
end

# On fork event - runs each time a worker forks
on_fork do
  # Reconnect to Redis
  if defined?(Redis)
    Redis.new(url: ENV.fetch('REDIS_URL', 'redis://localhost:6379/0')).ping
  end
end
