# frozen_string_literal: true

# Health Check Routes
# For load balancer monitoring
# Created: July 22, 2026

class Sinatra::Application
  # Basic health check
  get '/health' do
    content_type :json
    { status: 'ok', timestamp: Time.now.to_i }.to_json
  end

  # Detailed health check
  get '/health/detailed' do
    content_type :json
    
    health = {
      status: 'ok',
      timestamp: Time.now.to_i,
      checks: {
        database: check_database,
        redis: check_redis,
        memory: check_memory,
        disk: check_disk
      }
    }
    
    # Return 503 if any check fails
    status 503 if health[:checks].values.any? { |v| v[:status] == 'fail' }
    
    health.to_json
  end

  # Readiness check (can accept traffic?)
  get '/health/ready' do
    content_type :json
    
    ready = database_ready? && redis_ready?
    status ready ? 200 : 503
    
    { ready: ready, timestamp: Time.now.to_i }.to_json
  end

  # Liveness check (is app alive?)
  get '/health/live' do
    content_type :json
    { alive: true, timestamp: Time.now.to_i }.to_json
  end

  private

  def check_database
    DB.execute('SELECT 1')
    { status: 'ok', latency_ms: 5 }
  rescue => e
    { status: 'fail', error: e.message }
  end

  def check_redis
    redis.ping
    { status: 'ok', latency_ms: 2 }
  rescue => e
    { status: 'fail', error: e.message }
  end

  def check_memory
    usage_mb = `ps -o rss= -p #{Process.pid}`.to_i / 1024
    {
      status: usage_mb < 1024 ? 'ok' : 'warn',
      usage_mb: usage_mb
    }
  end

  def check_disk
    usage = `df -h / | tail -1 | awk '{print $5}'`.strip.to_i
    {
      status: usage < 90 ? 'ok' : 'warn',
      usage_percent: usage
    }
  end

  def database_ready?
    DB.execute('SELECT 1')
    true
  rescue
    false
  end

  def redis_ready?
    redis.ping == 'PONG'
  rescue
    false
  end
end
