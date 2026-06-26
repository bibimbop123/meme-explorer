# frozen_string_literal: true

require 'prometheus/client'
require 'prometheus/client/formats/text'

# Prometheus Exporter Middleware
# Exposes metrics in Prometheus format
class PrometheusExporter
  def initialize(app)
    @app = app
    setup_metrics
  end

  def call(env)
    request = Rack::Request.new(env)
    
    # Expose metrics endpoint
    if request.path == '/metrics' && request.get?
      return metrics_response
    end
    
    # Instrument request
    start_time = Time.now
    status, headers, body = @app.call(env)
    duration = Time.now - start_time
    
    # Record metrics
    record_request_metrics(request, status, duration)
    
    [status, headers, body]
  end

  private

  def setup_metrics
    @registry = Prometheus::Client.registry
    
    # Request metrics
    @request_counter = @registry.counter(
      :http_requests_total,
      docstring: 'Total HTTP requests',
      labels: [:method, :path, :status]
    )
    
    @request_duration = @registry.histogram(
      :http_request_duration_seconds,
      docstring: 'HTTP request duration',
      labels: [:method, :path],
      buckets: [0.01, 0.05, 0.1, 0.25, 0.5, 1, 2.5, 5, 10]
    )
    
    # Business metrics
    @active_users = @registry.gauge(
      :active_users_current,
      docstring: 'Currently active users'
    )
    
    @cache_hit_rate = @registry.gauge(
      :cache_hit_rate_percent,
      docstring: 'Cache hit rate percentage'
    )
    
    @db_query_duration = @registry.histogram(
      :database_query_duration_seconds,
      docstring: 'Database query duration',
      labels: [:query_type],
      buckets: [0.001, 0.005, 0.01, 0.05, 0.1, 0.5, 1]
    )
  end

  def record_request_metrics(request, status, duration)
    labels = {
      method: request.request_method,
      path: normalize_path(request.path),
      status: status.to_s
    }
    
    @request_counter.increment(labels: labels)
    @request_duration.observe(duration, labels: labels.except(:status))
  end

  def normalize_path(path)
    # Normalize dynamic paths
    path.gsub(/\/\d+/, '/:id')
        .gsub(/\/[a-f0-9-]{36}/, '/:uuid')
  end

  def metrics_response
    [
      200,
      { 'Content-Type' => Prometheus::Client::Formats::Text::CONTENT_TYPE },
      [Prometheus::Client::Formats::Text.marshal(@registry)]
    ]
  end
end
