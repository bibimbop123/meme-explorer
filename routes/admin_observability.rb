# frozen_string_literal: true

# Admin routes for observability dashboards

# Performance Dashboard
get '/admin/performance' do
    requires_admin!
    
    @page_title = 'Performance Dashboard'
    @since_hours = (params[:hours] || 1).to_i
    @since_time = Time.now - (@since_hours * 3600)
    
    @slow_operations = PerformanceTracker.slow_operations(
      since: @since_time,
      limit: 50
    )
    
    @operation_stats = PerformanceTracker.operation_stats(
      since: @since_time
    )
    
    erb :'admin/performance'
  end
  
  # Revenue Dashboard
  get '/admin/revenue' do
    requires_admin!
    
    @page_title = 'Revenue Dashboard'
    @today_stats = RevenueTracker.daily_stats
    @mrr = RevenueTracker.monthly_recurring_revenue
    @weekly_trend = RevenueTracker.weekly_trend
    @ad_stats = RevenueTracker.ad_frequency_stats
    
    erb :'admin/revenue'
  end
  
  # Health Check Dashboard
  get '/admin/health' do
    requires_admin!
    
    @page_title = 'System Health'
    @alerts = AlertService.check_health
    @recent_errors = DB.table_exists?(:error_metrics) ? 
      DB[:error_metrics]
        .where('created_at > ?', Time.now - 3600)
        .order(Sequel.desc(:created_at))
        .limit(50)
        .all : []
    
    erb :'admin/health'
  end
  
  # API endpoint for metrics (for external monitoring)
  get '/api/metrics' do
    requires_admin!
    
    content_type :json
    
    {
      timestamp: Time.now.iso8601,
      performance: {
        slow_operations_count: PerformanceTracker.slow_operations.count,
        average_response_time: PerformanceTracker.average_duration('request')
      },
      revenue: {
        mrr: RevenueTracker.monthly_recurring_revenue,
        today: RevenueTracker.daily_stats
      },
      health: {
        alerts: AlertService.check_health.count,
        status: AlertService.check_health.empty? ? 'healthy' : 'degraded'
      }
    }.to_json
  end
