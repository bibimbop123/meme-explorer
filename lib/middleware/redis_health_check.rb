# frozen_string_literal: true

# Redis Health Check Middleware
# Based on: REFACTORING_ROADMAP Phase 4, Task 6.3
# Monitors Redis health and switches to memory cache if needed

class RedisHealthCheck
  CHECK_INTERVAL = 30 # seconds

  def initialize(app)
    @app = app
    @last_check = Time.now
    @redis_available = true
    start_background_checker
  end

  def call(env)
    # Add Redis health status to environment
    env['redis.available'] = @redis_available
    
    @app.call(env)
  end

  private

  def start_background_checker
    Thread.new do
      loop do
        sleep CHECK_INTERVAL
        check_redis_health
      end
    end
  end

  def check_redis_health
    begin
      REDIS_POOL.with do |redis|
        redis.ping
      end

      unless @redis_available
        AppLogger.info("Redis connection restored")
        @redis_available = true
      end
    rescue => e
      if @redis_available
        AppLogger.error("Redis health check failed", 
          error: e.class.name,
          message: e.message
        )
        @redis_available = false
      end
    end

    @last_check = Time.now
  end
end
