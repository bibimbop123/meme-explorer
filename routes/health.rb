# Health Check Route
module MemeExplorer
  module Routes
    module Health
      def self.registered(app)
        app.get '/health' do
          begin
            MemeExplorer::Configuration.validate!
            cache_stats = MEME_CACHE.stats

            health_response = {
              status: 'healthy',
              timestamp: Time.now.iso8601,
              cache: {
                size_bytes: cache_stats[:size],
                max_size_bytes: cache_stats[:max_size],
                used_percent: cache_stats[:used_percent],
                entries: cache_stats[:entries],
                ttl_seconds: cache_stats[:ttl]
              },
              configuration: {
                tier_weights_valid: MemeExplorer::Configuration::TOTAL_TIER_WEIGHT == 100,
                session_configured: ENV['SESSION_SECRET'].present?,
                database_available: true,
                redis_available: false
              },
              version: '1.0.0'
            }

            content_type :json
            JSON.generate(health_response)
          rescue MemeExplorer::ConfigurationError => e
            status 503
            content_type :json
            MemeExplorer.logger.error("Health check failed: configuration error", { error: e.message })
            JSON.generate({
              status: 'unhealthy',
              error: 'configuration_error',
              message: e.message,
              timestamp: Time.now.iso8601
            })
          rescue => e
            status 503
            content_type :json
            MemeExplorer.logger.error("Health check failed", { error_class: e.class, error_message: e.message })
            JSON.generate({
              status: 'unhealthy',
              error: 'internal_error',
              message: e.message,
              timestamp: Time.now.iso8601
            })
          end
        end
      end
    end
  end
end
