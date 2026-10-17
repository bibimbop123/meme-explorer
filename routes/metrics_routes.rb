require_relative '../lib/services/metrics_report'
# routes/metrics_routes.rb
module Routes
  module MetricsRoutes

    def self.registered(app)
      app.get '/api/admin/legacy-impression-metrics' do
        content_type :json
        headers 'Cache-Control' => 'no-store'
        require_admin!
        snapshot = LegacyImpressionMetrics.snapshot
        status 503 unless snapshot[:available]
        snapshot.merge(scope: 'handler outcomes only; telemetry writes may be lost during Redis outages').to_json
      end

      app.helpers do
        def metrics_report
          period = params.fetch('period', 'all')
          halt 400, 'Invalid metrics period' unless MetricsReport::PERIODS.key?(period)
          MetricsReport.build(period: period)
        rescue StandardError => e
          AppLogger.error('Metrics report unavailable', error: e.class.name)
          halt 503, 'Metrics temporarily unavailable; no totals inferred.'
        end
      end

      app.get '/metrics.json' do
        require_auth!
        content_type :json
        headers 'Cache-Control' => 'no-store'
        metrics_report.merge(selection_latency: SelectionBenchmark.stage_breakdown,
          retention: RetentionService.daily_return_rate,
          avg_session_length_minutes: RetentionService.avg_session_length_minutes).to_json
      end

      app.get '/metrics' do
        require_auth!
        headers 'Cache-Control' => 'no-store'
        report = metrics_report
        report.each { |key, value| instance_variable_set("@#{key}", value) }
        @chart_period = report[:period]
        @selection_latency = SelectionBenchmark.stats
        @selection_breakdown = SelectionBenchmark.stage_breakdown
        @retention = RetentionService.daily_return_rate
        @avg_session_length_minutes = RetentionService.avg_session_length_minutes
        erb :metrics, layout: false
      end

      app.get '/metrics/export' do
        require_auth!
        require 'csv'
        report = metrics_report
        headers 'Cache-Control' => 'no-store'
        attachment "meme_metrics_#{report[:period]}_#{Time.now.utc.strftime('%Y%m%d')}.csv"
        content_type 'text/csv'
        CSV.generate do |csv|
          csv << ['Meme Explorer Metrics Report']
          csv << ['Period', report[:period]]
          csv << ['Source', report[:source]]
          csv << ['Window start UTC', report[:window_start]]
          csv << ['Generated UTC', report[:generated_at]]
          csv << ['Metric', 'Value']
          %i[total_memes total_likes total_views avg_likes avg_views engagement_rate].each do |key|
            csv << [key, report[key]]
          end
        end
      end

      # User notifications API
      #
      # BUG FIX: called `get_user_saved_memes_count(user_id)`, a method
      # that doesn't exist anywhere in the codebase (grep confirms zero
      # `def get_user_saved_memes_count`) - every single request to this
      # endpoint raised NoMethodError/500 instead of ever returning real
      # data. This was also duplicated verbatim in routes/system_routes.rb
      # with the identical bug, but registration order (this file is
      # `register`ed first in app.rb) meant only this copy was ever
      # actually reachable; removed the dead duplicate there. The real,
      # working method for this is `UserService.get_saved_memes_count`.
      app.get "/api/notifications" do
        require_auth!
        user_id = current_user_id
        
        # Get user notifications (saved count changes, likes, etc.)
        content_type :json
        {
          user_id: user_id,
          saved_count: UserService.get_saved_memes_count(user_id),
          timestamp: Time.now.iso8601,
          message: "Your profile is up to date"
        }.to_json
      end
    end
  end
end
