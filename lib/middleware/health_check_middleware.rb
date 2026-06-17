# frozen_string_literal: true

# Health Check Middleware for Load Balancer
# Based on: REFACTORING_ROADMAP Phase 4, Task 6.4

class HealthCheckMiddleware
  HEALTH_PATH = '/health'
  READINESS_PATH = '/ready'

  def initialize(app)
    @app = app
  end

  def call(env)
    case env['PATH_INFO']
    when HEALTH_PATH
      health_check
    when READINESS_PATH
      readiness_check
    else
      @app.call(env)
    end
  end

  private

  # Liveness check - is the app running?
  def health_check
    [200, 
     { 'Content-Type' => 'application/json' }, 
     [{ 
       status: 'ok',
       service: 'meme-explorer',
       timestamp: Time.now.iso8601
     }.to_json]]
  rescue => e
    [500, 
     { 'Content-Type' => 'application/json' }, 
     [{ 
       status: 'error',
       error: e.message
     }.to_json]]
  end

  # Readiness check - is the app ready to serve traffic?
  def readiness_check
    checks = {
      database: check_database,
      redis: check_redis,
      disk_space: check_disk_space
    }

    all_healthy = checks.values.all? { |v| v[:status] == 'ok' }
    status_code = all_healthy ? 200 : 503

    [status_code,
     { 'Content-Type' => 'application/json' },
     [{
       status: all_healthy ? 'ready' : 'not_ready',
       checks: checks,
       timestamp: Time.now.iso8601
     }.to_json]]
  rescue => e
    [503,
     { 'Content-Type' => 'application/json' },
     [{
       status: 'error',
       error: e.message
     }.to_json]]
  end

  def check_database
    DB_POOL.with do |conn|
      conn.exec("SELECT 1")
    end
    { status: 'ok' }
  rescue => e
    { status: 'error', message: e.message }
  end

  def check_redis
    REDIS_POOL.with do |redis|
      redis.ping
    end
    { status: 'ok' }
  rescue => e
    { status: 'warning', message: e.message }
  end

  def check_disk_space
    stat = Sys::Filesystem.stat('/')
    percent_used = ((1 - (stat.blocks_available.to_f / stat.blocks.to_f)) * 100).round(2)
    
    if percent_used > 90
      { status: 'error', percent_used: percent_used }
    elsif percent_used > 80
      { status: 'warning', percent_used: percent_used }
    else
      { status: 'ok', percent_used: percent_used }
    end
  rescue => e
    { status: 'unknown', message: e.message }
  end
end
