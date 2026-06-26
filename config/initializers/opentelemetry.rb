# frozen_string_literal: true

require 'opentelemetry/sdk'
require 'opentelemetry/exporter/otlp'
require 'opentelemetry/instrumentation/all'

# OpenTelemetry Configuration
# Distributed tracing and metrics collection

OpenTelemetry::SDK.configure do |c|
  c.service_name = 'meme-explorer'
  c.service_version = '1.0.0'
  
  # Configure exporters
  if ENV['OTLP_ENDPOINT']
    c.add_span_processor(
      OpenTelemetry::SDK::Trace::Export::BatchSpanProcessor.new(
        OpenTelemetry::Exporter::OTLP::Exporter.new(
          endpoint: ENV['OTLP_ENDPOINT'],
          headers: { 'Authorization' => "Bearer #{ENV['OTLP_TOKEN']}" }
        )
      )
    )
  end
  
  # Auto-instrumentation
  c.use_all({
    'OpenTelemetry::Instrumentation::Sinatra' => { enabled: true },
    'OpenTelemetry::Instrumentation::Redis' => { enabled: true },
    'OpenTelemetry::Instrumentation::Net::HTTP' => { enabled: true }
  })
  
  # Resource attributes
  c.resource = OpenTelemetry::SDK::Resources::Resource.create({
    'service.name' => 'meme-explorer',
    'service.version' => '1.0.0',
    'deployment.environment' => ENV['RACK_ENV'] || 'development',
    'service.instance.id' => ENV['HOSTNAME'] || 'localhost'
  })
end

# Custom span creation helper
module OpenTelemetryHelper
  def with_span(name, attributes: {})
    tracer = OpenTelemetry.tracer_provider.tracer('meme-explorer')
    tracer.in_span(name, attributes: attributes) do |span|
      yield span
    end
  rescue => e
    span&.record_exception(e)
    span&.status = OpenTelemetry::Trace::Status.error(e.message)
    raise
  end
end
