source "https://rubygems.org"

ruby "3.2.1"

# Core web stack
gem "sinatra", "~> 4.0"
gem "sinatra-contrib", "~> 4.0" # includes sinatra/reloader
gem "puma", "~> 6.0"
gem "rackup", "~> 2.1"
gem "activesupport", "~> 7.1"

# Security
gem "rack-protection", "~> 4.0"
gem "rack-csrf", "~> 0.1.0"

# Data and HTTP
# Note: yaml, json, net-http are built into Ruby stdlib - removed from dependencies
gem "httparty", "~> 0.21"
gem "net-http-persistent", "~> 4.0"  # HTTP connection pooling for performance
gem "concurrent-ruby", "~> 1.2"      # Thread pools and concurrent operations
gem "colorize", "~> 1.1"
gem "dotenv", "~> 2.8"

# Caching and persistence
gem "redis"
gem "rack-attack"
gem "redis-rack", "~> 3.0"  # Redis-based session storage
gem "pg", "~> 1.5"  # PostgreSQL adapter
gem "connection_pool", "~> 2.4"  # Connection pooling for PostgreSQL

# Authentication
gem "oauth2", "~> 2.0"
gem "bcrypt", "~> 3.1" # Password hashing

# Error tracking and monitoring
gem "sentry-ruby", "~> 5.0"

# Push Notifications
gem "web-push"

# Payments
gem "stripe", "~> 10.0"

# Background jobs & scheduling
# NOTE: sidekiq-scheduler manages cron via Redis (see config/sidekiq.yml)
# whenever (cron-based) was removed — sidekiq-scheduler is the single scheduler
gem "sidekiq"
gem "sidekiq-scheduler"  # Cron-like scheduling for Sidekiq

group :development, :test do
  gem "rspec", "~> 3.12"
  gem "rack-test", "~> 2.1"
  gem "database_cleaner-sequel", "~> 1.8"
  gem "webmock", "~> 3.19"  # Mock HTTP requests in tests
  gem "simplecov", "~> 0.22", require: false  # Code coverage
end

group :development do
  gem "rerun"
  # sqlite3 kept in development only for local migration tooling
  gem "sqlite3"
end

# REMOVED from production:
# - gem "whenever"    -> replaced by sidekiq-scheduler (single scheduling mechanism)
# - gem "thread"      -> Thread/Mutex/Queue are Ruby core, not a gem
# - gem "ostruct"     -> stdlib, no explicit gem needed in Ruby 3.2+
