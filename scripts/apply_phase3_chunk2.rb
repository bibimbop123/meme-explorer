#!/usr/bin/env ruby
# frozen_string_literal: true

# Phase 3 Chunk 2: Performance Monitoring Setup
# Configure Sentry performance tracking and Core Web Vitals monitoring

puts "🚀 Phase 3 Chunk 2: Performance Monitoring Setup"
puts "=" * 60

# Check if Sentry config exists
sentry_config = 'config/sentry.rb'
unless File.exist?(sentry_config)
  puts "❌ Sentry config not found at #{sentry_config}"
  exit 1
end

puts "\n✅ Step 1: Enhancing Sentry configuration for performance tracking..."

# Read current Sentry config
sentry_content = File.read(sentry_config)

# Add performance monitoring if not present
unless sentry_content.include?('traces_sample_rate')
  performance_config = <<~RUBY

  # Performance Monitoring
  config.traces_sample_rate = ENV['SENTRY_TRACES_SAMPLE_RATE']&.to_f || 0.1
  config.profiles_sample_rate = 1.0

  # Enable performance monitoring for key transactions
  config.before_send_transaction = lambda do |event, hint|
    # Add custom context
    event.contexts[:performance] = {
      environment: ENV['RACK_ENV'] || 'development',
      server: Socket.gethostname
    }
    event
  end
  RUBY
  
  # Insert before the final 'end'
  enhanced_content = sentry_content.sub(/end\s*$/, "#{performance_config}end")
  File.write(sentry_config, enhanced_content)
  puts "   ✓ Added performance monitoring to Sentry config"
else
  puts "   ℹ Performance monitoring already configured"
end

puts "\n✅ Step 2: Creating Core Web Vitals tracking module..."

web_vitals_js = 'public/js/web-vitals.js'
File.write(web_vitals_js, <<~JS)
/**
 * Core Web Vitals Tracking
 * Tracks LCP, FID, CLS and reports to analytics
 */

(function() {
  'use strict';

  // Track Core Web Vitals
  const webVitals = {
    lcp: null,
    fid: null,
    cls: null
  };

  // Track Largest Contentful Paint (LCP)
  function trackLCP() {
    const observer = new PerformanceObserver((list) => {
      const entries = list.getEntries();
      const lastEntry = entries[entries.length - 1];
      webVitals.lcp = Math.round(lastEntry.renderTime || lastEntry.loadTime);
      
      // Report if > 2.5s (needs improvement)
      if (webVitals.lcp > 2500) {
        console.warn(`⚠️ LCP: ${webVitals.lcp}ms (needs improvement)`);
      }
      
      sendToAnalytics('lcp', webVitals.lcp);
    });
    
    observer.observe({ type: 'largest-contentful-paint', buffered: true });
  }

  // Track First Input Delay (FID)
  function trackFID() {
    const observer = new PerformanceObserver((list) => {
      const entries = list.getEntries();
      entries.forEach((entry) => {
        webVitals.fid = Math.round(entry.processingStart - entry.startTime);
        
        // Report if > 100ms (needs improvement)
        if (webVitals.fid > 100) {
          console.warn(`⚠️ FID: ${webVitals.fid}ms (needs improvement)`);
        }
        
        sendToAnalytics('fid', webVitals.fid);
      });
    });
    
    observer.observe({ type: 'first-input', buffered: true });
  }

  // Track Cumulative Layout Shift (CLS)
  function trackCLS() {
    let clsValue = 0;
    const observer = new PerformanceObserver((list) => {
      list.getEntries().forEach((entry) => {
        if (!entry.hadRecentInput) {
          clsValue += entry.value;
        }
      });
      
      webVitals.cls = Math.round(clsValue * 1000) / 1000;
      
      // Report if > 0.1 (needs improvement)
      if (webVitals.cls > 0.1) {
        console.warn(`⚠️ CLS: ${webVitals.cls} (needs improvement)`);
      }
    });
    
    observer.observe({ type: 'layout-shift', buffered: true });
    
    // Send final CLS on page unload
    window.addEventListener('beforeunload', () => {
      sendToAnalytics('cls', webVitals.cls);
    });
  }

  // Send metrics to analytics endpoint
  function sendToAnalytics(metric, value) {
    if (!value) return;
    
    try {
      fetch('/api/vitals', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          metric: metric,
          value: value,
          url: window.location.pathname,
          timestamp: Date.now()
        }),
        keepalive: true
      }).catch(e => console.error('Analytics error:', e));
    } catch (e) {
      console.error('Failed to send vital:', e);
    }
  }

  // Initialize tracking
  if ('PerformanceObserver' in window) {
    trackLCP();
    trackFID();
    trackCLS();
    
    console.log('✅ Core Web Vitals tracking initialized');
  } else {
    console.warn('⚠️ PerformanceObserver not supported');
  }

  // Export for console access
  window.getWebVitals = () => webVitals;
})();
JS

puts "   ✓ Created #{web_vitals_js}"

puts "\n✅ Step 3: Creating Web Vitals API endpoint..."

vitals_route = 'routes/web_vitals.rb'
File.write(vitals_route, <<~RUBY)
# frozen_string_literal: true

# Web Vitals tracking endpoint
# Receives Core Web Vitals metrics from clients

app.post '/api/vitals' do
  content_type :json
  
  begin
    data = JSON.parse(request.body.read)
    
    metric = data['metric']
    value = data['value']
    url = data['url']
    
    # Log to application logger
    AppLogger.info("Web Vital - #{metric.upcase}: #{value}ms on #{url}")
    
    # Store in Redis for aggregation
    redis_key = "web_vitals:\#{Date.today}:\#{metric}"
    RedisService.rpush(redis_key, value.to_s)
    RedisService.expire(redis_key, 86400 * 7) # Keep for 7 days
    
    # Alert if critical thresholds exceeded
    if (metric == 'lcp' && value > 4000) ||
       (metric == 'fid' && value > 300) ||
       (metric == 'cls' && value > 0.25)
      AppLogger.warn("⚠️ Critical Web Vital: #{metric.upcase} = #{value}")
    end
    
    { success: true }.to_json
  rescue => e
    AppLogger.error("Web Vitals tracking error: \#{e.message}")
    status 500
    { error: 'Internal server error' }.to_json
  end
end

# Get Web Vitals dashboard data
app.get '/admin/web-vitals' do
  protected!
  
  @vitals_data = {}
  %w[lcp fid cls].each do |metric|
    redis_key = "web_vitals:\#{Date.today}:\#{metric}"
    values = RedisService.lrange(redis_key, 0, -1).map(&:to_f)
    
    next if values.empty?
    
    @vitals_data[metric] = {
      count: values.size,
      avg: (values.sum / values.size).round(2),
      p50: percentile(values, 50).round(2),
      p75: percentile(values, 75).round(2),
      p95: percentile(values, 95).round(2)
    }
  end
  
  erb :'admin/web_vitals'
end

def percentile(values, p)
  sorted = values.sort
  index = (p / 100.0 * sorted.length).ceil - 1
  sorted[[index, 0].max]
end
RUBY

puts "   ✓ Created #{vitals_route}"

puts "\n✅ Step 4: Creating Web Vitals dashboard view..."

dashboard_view = 'views/admin/web_vitals.erb'
FileUtils.mkdir_p(File.dirname(dashboard_view))
File.write(dashboard_view, <<~ERB)
<div class="web-vitals-dashboard">
  <h1>📊 Core Web Vitals Dashboard</h1>
  
  <% if @vitals_data.empty? %>
    <p>No vitals data collected yet. Visit pages to start collecting metrics.</p>
  <% else %>
    <div class="vitals-grid">
      <!-- LCP -->
      <% if @vitals_data['lcp'] %>
        <div class="vital-card lcp <%= vitals_status(@vitals_data['lcp'][:p75], 2500, 4000) %>">
          <h3>⚡ Largest Contentful Paint (LCP)</h3>
          <div class="metric-value"><%= @vitals_data['lcp'][:p75] %>ms</div>
          <div class="metric-label">P75</div>
          <div class="metrics-detail">
            <div>Count: <%= @vitals_data['lcp'][:count] %></div>
            <div>Avg: <%= @vitals_data['lcp'][:avg] %>ms</div>
            <div>P95: <%= @vitals_data['lcp'][:p95] %>ms</div>
          </div>
          <div class="threshold-guide">
            Good: &lt;2.5s | Needs Improvement: 2.5-4s | Poor: &gt;4s
          </div>
        </div>
      <% end %>
      
      <!-- FID -->
      <% if @vitals_data['fid'] %>
        <div class="vital-card fid <%= vitals_status(@vitals_data['fid'][:p75], 100, 300) %>">
          <h3>⏱️ First Input Delay (FID)</h3>
          <div class="metric-value"><%= @vitals_data['fid'][:p75] %>ms</div>
          <div class="metric-label">P75</div>
          <div class="metrics-detail">
            <div>Count: <%= @vitals_data['fid'][:count] %></div>
            <div>Avg: <%= @vitals_data['fid'][:avg] %>ms</div>
            <div>P95: <%= @vitals_data['fid'][:p95] %>ms</div>
          </div>
          <div class="threshold-guide">
            Good: &lt;100ms | Needs Improvement: 100-300ms | Poor: &gt;300ms
          </div>
        </div>
      <% end %>
      
      <!-- CLS -->
      <% if @vitals_data['cls'] %>
        <div class="vital-card cls <%= vitals_status(@vitals_data['cls'][:p75], 0.1, 0.25) %>">
          <h3>📏 Cumulative Layout Shift (CLS)</h3>
          <div class="metric-value"><%= @vitals_data['cls'][:p75] %></div>
          <div class="metric-label">P75</div>
          <div class="metrics-detail">
            <div>Count: <%= @vitals_data['cls'][:count] %></div>
            <div>Avg: <%= @vitals_data['cls'][:avg] %></div>
            <div>P95: <%= @vitals_data['cls'][:p95] %></div>
          </div>
          <div class="threshold-guide">
            Good: &lt;0.1 | Needs Improvement: 0.1-0.25 | Poor: &gt;0.25
          </div>
        </div>
      <% end %>
    </div>
  <% end %>
  
  <style>
    .vitals-grid {
      display: grid;
      grid-template-columns: repeat(auto-fit, minmax(300px, 1fr));
      gap: 20px;
      margin-top: 20px;
    }
    
    .vital-card {
      border: 2px solid #ddd;
      border-radius: 8px;
      padding: 20px;
      text-align: center;
    }
    
    .vital-card.good { border-color: #10b981; background: #ecfdf5; }
    .vital-card.needs-improvement { border-color: #f59e0b; background: #fffbeb; }
    .vital-card.poor { border-color: #ef4444; background: #fef2f2; }
    
    .metric-value {
      font-size: 48px;
      font-weight: bold;
      margin: 10px 0;
    }
    
    .metric-label {
      font-size: 14px;
      color: #666;
      text-transform: uppercase;
    }
    
    .metrics-detail {
      margin-top: 15px;
      padding-top: 15px;
      border-top: 1px solid #ddd;
      font-size: 14px;
    }
    
    .threshold-guide {
      margin-top: 10px;
      font-size: 12px;
      color: #666;
      font-style: italic;
    }
  </style>
</div>

<%
  # Helper to determine vital status
  def vitals_status(value, good_threshold, poor_threshold)
    return 'good' if value < good_threshold
    return 'poor' if value > poor_threshold
    'needs-improvement'
  end
%>
ERB

puts "   ✓ Created #{dashboard_view}"

puts "\n✅ Step 5: Updating layout.erb to include Web Vitals tracking..."

layout_file = 'views/layout.erb'
if File.exist?(layout_file)
  layout_content = File.read(layout_file)
  
  unless layout_content.include?('web-vitals.js')
    # Add before </body>
    updated_layout = layout_content.sub(
      '</body>',
      "  <script src=\"/js/web-vitals.js\" defer></script>\n  </body>"
    )
    File.write(layout_file, updated_layout)
    puts "   ✓ Added Web Vitals script to layout"
  else
    puts "   ℹ Web Vitals script already included"
  end
else
  puts "   ⚠️ Warning: layout.erb not found"
end

puts "\n" + "=" * 60
puts "✅ Phase 3 Chunk 2 Complete: Performance Monitoring Setup"
puts "=" * 60
puts "\n📊 What was added:"
puts "  1. Enhanced Sentry performance tracking"
puts "  2. Core Web Vitals tracking (LCP, FID, CLS)"
puts "  3. Web Vitals API endpoint (/api/vitals)"
puts "  4. Admin dashboard (/admin/web-vitals)"
puts "  5. Automatic threshold alerting"
puts "\n📈 Impact:"
puts "  - Real-time performance monitoring"
puts "  - Track actual user experience"
puts "  - Identify performance regressions"
puts "  - Data-driven optimization decisions"
puts "\n🧪 Testing:"
puts "  - Visit /admin/web-vitals after browsing site"
puts "  - Check browser console for Web Vitals"
puts "  - Monitor Sentry for performance transactions"
puts "\n✨ Status: READY FOR DEPLOYMENT"
