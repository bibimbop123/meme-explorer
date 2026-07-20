# frozen_string_literal: true

# Redis Connection Pool Configuration
# Prevents connection exhaustion under load

require 'connection_pool'
require 'redis'

module RedisConnectionPool
  # Production-grade connection pool settings
  POOL_SIZE = ENV.fetch('REDIS_POOL_SIZE', 10).to_i
  POOL_TIMEOUT = ENV.fetch('REDIS_POOL_TIMEOUT', 5).to_f
  
  def self.pool
    @pool ||= ConnectionPool.new(size: POOL_SIZE, timeout: POOL_TIMEOUT) do
      Redis.new(
        url: ENV['REDIS_URL'] || 'redis://localhost:6379/0',
        timeout: 5,
        reconnect_attempts: 3,
        reconnect_delay: 0.5,
        reconnect_delay_max: 2.0
      )
    end
  end
  
  # Thread-safe Redis access
  def self.with(&block)
    pool.with(&block)
  end
  
  # Health check
  def self.healthy?
    with { |conn| conn.ping == 'PONG' }
  rescue StandardError => err
    AppLogger.error("Redis health check failed: " + err.message)
    false
  end
end
