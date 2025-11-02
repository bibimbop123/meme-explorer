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

# Logging - use stdout for production (Render), file logging for development
if ENV['RACK_ENV'] == 'production' || ENV['RACK_ENV'] == 'staging'
  # Production/Staging: Log to stdout (Render expects this)
  # Don't specify stdout_redirect - Puma will use STDOUT by default
else
  # Development: Log to files
  require 'fileutils'
  FileUtils.mkdir_p('log') unless Dir.exist?('log')
  FileUtils.mkdir_p('tmp/pids') unless Dir.exist?('tmp/pids')
  stdout_redirect "log/puma.log", "log/puma-error.log", true
  pidfile "tmp/pids/puma.pid"
  state_path "tmp/pids/puma.state"
end

# On boot event - runs once per cluster
on_worker_boot do
  # Reconnect to database on worker boot
  if ENV['DATABASE_URL']
    require 'sequel'
    DB.disconnect
    Object.const_set(:DB, Sequel.connect(ENV['DATABASE_URL']))
  end
end
