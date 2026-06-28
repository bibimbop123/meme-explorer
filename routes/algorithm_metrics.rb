# Algorithm Metrics Routes - Phase 1 Observability
# Provides real-time dashboard for algorithm performance monitoring

module Routes
  module AlgorithmMetrics
    def self.registered(app)
      # Algorithm performance metrics dashboard
      app.get "/api/algorithm/metrics" do
        content_type :json
        halt 403, { error: "Forbidden" }.to_json unless is_admin?
        
        begin
          # Get last 1000 selections from Redis
          selections = if defined?(REDIS) && REDIS
            REDIS.lrange('algorithm:selections', 0, 999).map { |s| JSON.parse(s) rescue nil }.compact
          else
            []
          end
          
          if selections.empty?
            return {
              total_selections: 0,
              avg_duration_ms: 0,
              personalization_rate: 0,
              avg_pool_size: 0,
              redis_available: false,
              message: "No data available - Redis may be down or no selections yet"
            }.to_json
          end
          
          # Calculate aggregated metrics
          total = selections.size
          avg_duration = selections.map { |s| s['duration_ms'] }.compact.sum / total.to_f
          personalization_rate = selections.count { |s| s['personalization_applied'] } / total.to_f
          avg_pool = selections.map { |s| s['pool_size'] }.compact.sum / total.to_f
          avg_filtered = selections.map { |s| s['filtered_size'] }.compact.sum / total.to_f
          
          # Performance breakdown by hour
          last_hour = selections.select { |s| s['timestamp'] && s['timestamp'] > (Time.now.to_i - 3600) }
          last_hour_avg = last_hour.any? ? last_hour.map { |s| s['duration_ms'] }.compact.sum / last_hour.size.to_f : 0
          
          {
            total_selections: total,
            avg_duration_ms: avg_duration.round(2),
            personalization_rate: (personalization_rate * 100).round(1),
            avg_pool_size: avg_pool.round(0),
            avg_filtered_size: avg_filtered.round(0),
            redis_available: true,
            algorithm_version: selections.first['algorithm_version'] || 'v2_personalized',
            
            # Performance metrics
            performance: {
              last_hour_avg_ms: last_hour_avg.round(2),
              last_hour_count: last_hour.size,
              p50_duration_ms: calculate_percentile(selections.map { |s| s['duration_ms'] }.compact, 50),
              p95_duration_ms: calculate_percentile(selections.map { |s| s['duration_ms'] }.compact, 95),
              p99_duration_ms: calculate_percentile(selections.map { |s| s['duration_ms'] }.compact, 99)
            },
            
            # Health indicators
            health: {
              status: avg_duration < 50 ? 'healthy' : (avg_duration < 100 ? 'warning' : 'critical'),
              personalization_working: personalization_rate > 0.3,
              selection_rate_per_hour: last_hour.size
            },
            
            # Recent selections sample
            recent_selections: selections.first(10).map { |s|
              {
                timestamp: Time.at(s['timestamp']).strftime('%H:%M:%S'),
                meme_id: s['meme_id']&.to_s&.slice(0, 50),
                duration_ms: s['duration_ms'],
                personalized: s['personalization_applied'],
                pool_size: s['pool_size']
              }
            }
          }.to_json
        rescue => e
          AppLogger.error("❌ Algorithm metrics error: #{e.message}")
          {
            error: e.message,
            backtrace: e.backtrace.first(3)
          }.to_json
        end
      end
      
      # Clear metrics (admin only, for testing)
      app.delete "/api/algorithm/metrics" do
        content_type :json
        halt 403, { error: "Forbidden" }.to_json unless is_admin?
        
        if defined?(REDIS) && REDIS
          REDIS.del('algorithm:selections')
          { success: true, message: "Metrics cleared" }.to_json
        else
          { success: false, error: "Redis not available" }.to_json
        end
      end
      
      private
      
      # Calculate percentile from array of numbers
      def self.calculate_percentile(array, percentile)
        return 0 if array.empty?
        sorted = array.sort
        index = (percentile / 100.0 * sorted.length).ceil - 1
        sorted[[index, 0].max].round(2)
      end
    end
  end
end
