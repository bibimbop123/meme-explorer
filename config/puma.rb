# Puma configuration for multi-worker deployment
# Configure puma to start in cluster mode

# Binding
#
# NOTE (Aug 25, 2026): Never hardcode the port here. Render (and most PaaS
# providers) inject their own $PORT value per-instance and expect the app
# to bind to whatever they assign; a mismatched fixed port causes the
# platform to detect the discrepancy and force-restart the service to
# reconcile its network routing ("New primary port detected: XXXX.
# Restarting deploy..."), producing 502s for any request in flight during
# that restart. This currently only matters if something invokes Puma
# directly via this config file (the deployed startCommand instead runs
# `rackup config.ru -p $PORT`, which already binds correctly), but keep
# this dynamic so switching invocation methods doesn't reintroduce the bug.
bind "tcp://0.0.0.0:#{ENV.fetch('PORT', 3000)}"

# Disable cluster mode - use single process to consolidate in-memory cache
# Background thread loads 150+ API memes into shared MEME_CACHE
# All requests use same cache, no inter-process sync needed
workers Integer(ENV.fetch("WEB_CONCURRENCY", 0))

# Each worker has its own thread pool - increase for concurrent requests
threads_count = Integer(ENV.fetch("RAILS_MAX_THREADS", 32))
threads threads_count, threads_count

# Cluster mode settings
# Note: preload_app! and worker_shutdown_timeout only apply when WEB_CONCURRENCY > 0

# Timeouts
worker_shutdown_timeout 30

# Application environment
environment ENV.fetch("RACK_ENV", "development")

# Logging configuration
# Production/Staging: Use default Puma logging (stdout/stderr)
# Development: Log to files
if %w[production staging].include?(ENV['RACK_ENV'])
  # Cloud environments (Render, Heroku, etc.) expect STDOUT/STDERR
  # Don't configure stdout_redirect - let Puma use defaults
else
  # Local development: safe to use file logging
  require 'fileutils'
  FileUtils.mkdir_p('log') unless Dir.exist?('log')
  FileUtils.mkdir_p('tmp/pids') unless Dir.exist?('tmp/pids')
  
  stdout_redirect "log/puma.log", "log/puma-error.log", true
  pidfile "tmp/pids/puma.pid"
  state_path "tmp/pids/puma.state"
end

# On boot event - runs once per cluster (only in cluster mode: WEB_CONCURRENCY > 0)
if Integer(ENV.fetch("WEB_CONCURRENCY", 0)) > 0
  on_worker_boot do
    # Reconnect to database on worker boot
    if ENV['DATABASE_URL']
      require 'sequel'
      DB.disconnect
      Object.const_set(:DB, Sequel.connect(ENV['DATABASE_URL']))
    end
  end
end
