# Health Check Endpoint
# Comprehensive health monitoring for production

module MemeExplorer
  class App < Sinatra::Base
    
    # Comprehensive health check endpoint
    get '/health' do
      content_type :json
      
      health_status = {
        status: 'ok',
        timestamp: Time.now.iso8601,
        uptime_seconds: (Time.now - $start_time).to_i,
        checks: {}
      }
      
      # Database health
      begin
        DB.execute("SELECT 1")
        health_status[:checks][:database] = {
          status: 'healthy',
          type: 'sqlite3'
        }
      rescue => e
        health_status[:checks][:database] = {
          status: 'unhealthy',
          error: e.message
        }
        health_status[:status] = 'degraded'
      end
      
      # Redis health
      begin
        if REDIS
          REDIS.ping
          health_status[:checks][:redis] = {
            status: 'healthy',
            connected: true
          }
        else
          health_status[:checks][:redis] = {
            status: 'disabled',
            connected: false
          }
        end
      rescue => e
        health_status[:checks][:redis] = {
          status: 'unhealthy',
          error: e.message
        }
        health_status[:status] = 'degraded'
      end
      
      # Cache health
      begin
        cache_stats = MEME_CACHE.stats
        health_status[:checks][:cache] = {
          status: 'healthy',
          size: cache_stats[:size],
          memory_usage_mb: (cache_stats[:estimated_memory] / 1024.0 / 1024.0).round(2)
        }
      rescue => e
        health_status[:checks][:cache] = {
          status: 'unhealthy',
          error: e.message
        }
      end
      
      # Meme pool health
      begin
        meme_count = MEME_CACHE.get(:memes)&.size || 0
        last_refresh = MEME_CACHE.get(:last_refresh)
        
        health_status[:checks][:meme_pool] = {
          status: meme_count > 0 ? 'healthy' : 'warning',
          meme_count: meme_count,
          last_refresh: last_refresh&.iso8601,
          age_minutes: last_refresh ? ((Time.now - last_refresh) / 60).round(1) : nil
        }
        
        health_status[:status] = 'warning' if meme_count == 0
      rescue => e
        health_status[:checks][:meme_pool] = {
          status: 'unhealthy',
          error: e.message
        }
      end
      
      # Set HTTP status based on health
      status_code = case health_status[:status]
                    when 'ok' then 200
                    when 'warning' then 200  # Still operational
                    when 'degraded' then 503
                    else 503
                    end
      
      status status_code
      health_status.to_json
    end
    
    # Readiness check - for load balancers
    get '/health/ready' do
      content_type :json
      
      ready = true
      checks = []
      
      # Must have database
      begin
        DB.execute("SELECT 1")
        checks << { name: 'database', ready: true }
      rescue
        ready = false
        checks << { name: 'database', ready: false }
      end
      
      # Must have memes
      meme_count = MEME_CACHE.get(:memes)&.size || 0
      if meme_count > 0
        checks << { name: 'meme_pool', ready: true }
      else
        ready = false
        checks << { name: 'meme_pool', ready: false }
      end
      
      status ready ? 200 : 503
      { ready: ready, checks: checks }.to_json
    end
    
    # Liveness check - for container orchestration
    get '/health/live' do
      content_type :json
      status 200
      { alive: true, timestamp: Time.now.iso8601 }.to_json
    end
    
  end
end
