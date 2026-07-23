# frozen_string_literal: true

# Load Distributor Middleware
# Distributes load across workers
# Created: July 22, 2026

class LoadDistributor
  def initialize(app)
    @app = app
    @request_count = 0
    @start_time = Time.now
  end

  def call(env)
    @request_count += 1
    
    # Add load metrics to headers
    status, headers, response = @app.call(env)
    
    headers['X-Request-Count'] = @request_count.to_s
    headers['X-Uptime-Seconds'] = (Time.now - @start_time).to_i.to_s
    headers['X-Worker-PID'] = Process.pid.to_s
    
    [status, headers, response]
  end
end
