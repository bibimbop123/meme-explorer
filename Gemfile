source "https://rubygems.org"

ruby "3.2.1"

# Core web stack
gem "sinatra"
gem "sinatra-contrib" # includes sinatra/reloader
gem "puma"
gem "rackup"
gem "activesupport", "~> 8.1"


# Data and HTTP
gem "yaml"
gem "json"
gem "net-http"
gem "httparty"
gem "colorize"  # 👈 for readable logs
gem "dotenv"

# Caching and persistence
gem "redis"
gem "rack-attack"
gem "pg", "~> 1.5"  # PostgreSQL adapter

# Authentication
gem "oauth2", "~> 2.0"
gem "bcrypt", "~> 3.1" # Password hashing

# Error tracking and monitoring
gem "sentry-ruby", "~> 5.0"

# Scheduling
gem "whenever", require: false

# Optional (for Tier 2)
gem "sqlite3"
gem "sidekiq"
gem "thread"
gem "ostruct"

group :development, :test do
  gem "rspec", "~> 3.12"
  gem "rack-test", "~> 2.1"
  gem "database_cleaner-sequel", "~> 1.8"
end

group :development do
  gem "rerun"
end

gem "rack-csrf", "~> 0.1.0"
