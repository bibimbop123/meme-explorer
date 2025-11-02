source "https://rubygems.org"

ruby "3.2.1"

# Core web stack
gem "sinatra"
gem "sinatra-contrib" # includes sinatra/reloader
gem "puma"
gem "rackup"
gem "activesupport", "~> 7.1"


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

# Authentication
gem "oauth2", "~> 2.0"

# Scheduling
gem "whenever", require: false

# Optional (for Tier 2)
gem "sqlite3"
gem "sidekiq"
gem "thread"
gem "ostruct"

group :development do
  gem "rerun"
  gem "dotenv"
end
