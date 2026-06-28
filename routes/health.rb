# Health Check Endpoint
# Comprehensive health monitoring for production

module Routes
  module HealthRoutes
    def self.registered(app)
    
    # Comprehensive health check endpoint
    app.get '/health' do
      content_type :json
      
      health_status = {
        status: 'ok',
        timestamp: Time.now.iso8601,
        uptime_seconds: (Time.now - MemeExplorer::START_TIME).to_i,
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
        if defined?(RedisService)
          redis_stats = RedisService.stats
          health_status[:checks][:redis] = redis_stats.merge(
            status: 'healthy',
            connected: true
          )
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
    app.get '/health/ready' do
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
    app.get '/health/live' do
      content_type :json
      status 200
      { alive: true, timestamp: Time.now.iso8601 }.to_json
    end
    
    # Detailed health check - for monitoring systems
    app.get '/health/detailed' do
      content_type :json
      
      health_data = {
        status: 'healthy',
        timestamp: Time.now.iso8601,
        uptime_seconds: (Time.now - MemeExplorer::START_TIME).to_i,
        checks: {},
        metrics: {},
        resources: {}
      }
      
      # Database health with connection pool info
      begin
        DB.execute("SELECT 1")
        pool_info = if defined?(DB_POOL)
          {
            size: DB_POOL.size,
            available: DB_POOL.available
          }
        else
          { info: 'Connection pool not configured' }
        end
        
        health_data[:checks][:database] = {
          status: 'healthy',
          response_time_ms: Routes::HealthRoutes.measure_query_time,
          pool: pool_info
        }
      rescue => e
        health_data[:checks][:database] = {
          status: 'unhealthy',
          error: e.message
        }
        health_data[:status] = 'degraded'
      end
      
      # Redis health with memory usage
      begin
        if defined?(RedisService)
          redis_info = RedisService.client.with { |conn| conn.info }
          used_memory_mb = (redis_info['used_memory'].to_i / 1024.0 / 1024.0).round(2)
          max_memory_mb = (redis_info['maxmemory'].to_i / 1024.0 / 1024.0).round(2)
          
          health_data[:checks][:redis] = {
            status: 'healthy',
            used_memory_mb: used_memory_mb,
            max_memory_mb: max_memory_mb,
            memory_usage_percent: max_memory_mb > 0 ? ((used_memory_mb / max_memory_mb) * 100).round(1) : 0,
            connected_clients: redis_info['connected_clients'].to_i,
            uptime_days: (redis_info['uptime_in_seconds'].to_i / 86400.0).round(1)
          }
        end
      rescue => e
        health_data[:checks][:redis] = {
          status: 'unhealthy',
          error: e.message
        }
        health_data[:status] = 'degraded'
      end
      
      # Sidekiq health (if available)
      begin
        if defined?(Sidekiq)
          stats = Sidekiq::Stats.new
          queue_stats = Sidekiq::Queue.all.map { |q| { name: q.name, size: q.size } }
          
          health_data[:checks][:sidekiq] = {
            status: 'healthy',
            processed: stats.processed,
            failed: stats.failed,
            retry_size: stats.retry_size,
            dead_size: stats.dead_size,
            queues: queue_stats,
            workers_size: stats.workers_size
          }
          
          # Warn if queues backing up
          if queue_stats.any? { |q| q[:size] > 1000 }
            health_data[:checks][:sidekiq][:status] = 'warning'
            health_data[:checks][:sidekiq][:message] = 'Queue backlog detected'
          end
        end
      rescue => e
        health_data[:checks][:sidekiq] = {
          status: 'unavailable',
          error: e.message
        }
      end
      
      # Thread pool utilization
      begin
        thread_count = Thread.list.size
        health_data[:resources][:threads] = {
          count: thread_count,
          status: thread_count < 100 ? 'healthy' : 'warning'
        }
      rescue => e
        health_data[:resources][:threads] = {
          status: 'error',
          error: e.message
        }
      end
      
      # Memory usage
      begin
        if RUBY_PLATFORM =~ /linux/
          memory_kb = `ps -o rss= -p #{Process.pid}`.to_i
          memory_mb = (memory_kb / 1024.0).round(2)
        else
          # macOS/BSD
          memory_bytes = `ps -o rss= -p #{Process.pid}`.to_i * 1024
          memory_mb = (memory_bytes / 1024.0 / 1024.0).round(2)
        end
        
        health_data[:resources][:memory] = {
          used_mb: memory_mb,
          status: memory_mb < 1000 ? 'healthy' : 'warning'
        }
      rescue => e
        health_data[:resources][:memory] = {
          status: 'unavailable',
          error: e.message
        }
      end
      
      # Business metrics
      begin
        health_data[:metrics][:meme_pool_size] = MEME_CACHE.get(:memes)&.size || 0
        health_data[:metrics][:cache_size] = MEME_CACHE.stats[:size]
        health_data[:metrics][:last_cache_refresh] = MEME_CACHE.get(:last_refresh)&.iso8601
      rescue => e
        health_data[:metrics][:error] = e.message
      end
      
      # Set overall status
      if health_data[:checks].values.any? { |check| check[:status] == 'unhealthy' }
        health_data[:status] = 'degraded'
        status 503
      elsif health_data[:checks].values.any? { |check| check[:status] == 'warning' }
        health_data[:status] = 'warning'
        status 200
      else
        health_data[:status] = 'healthy'
        status 200
      end
      
      health_data.to_json
    end
    
    # Internal helper — not a route
    def self.measure_query_time
      start_time = Time.now
      DB.execute("SELECT 1")
      ((Time.now - start_time) * 1000).round(2)
    rescue
      nil
    end
    
    end
  end
end
