# spec/routes/metrics_routes_spec.rb
#
# Covers the /metrics dashboard, with particular attention to the
# Selection Latency Breakdown section added this session (see
# lib/services/selection_benchmark.rb) - this is the first spec that
# actually renders views/metrics.erb with real @selection_breakdown data,
# rather than just syntax-checking the ERB in isolation.
require_relative "../../spec/spec_helper"

describe "Metrics Routes" do
  describe "GET /metrics (without authentication)" do
    it "redirects to login" do
      get "/metrics"
      expect(last_response.status).to eq(302)
      expect(last_response.location).to include("/login")
    end
  end

  describe "GET /metrics.json (without authentication)" do
    it "returns 401 JSON" do
      header "Accept", "application/json"
      get "/metrics.json"
      expect(last_response.status).to eq(401)
    end
  end

  describe "GET /metrics (with authentication)" do
    before(:each) do
      hashed = BCrypt::Password.create("testpass123")
      DB.execute(
        "INSERT INTO users (email, password_hash) VALUES (?, ?)",
        ["metrics_test_user@example.com", hashed]
      )
      @user_id = DB.last_insert_row_id
    end

    def authenticated_get(path)
      env "rack.session", { user_id: @user_id }
      get path
    end

    it 'renders measurement limitations and distinguishes unavailable return data' do
      session[:user_id] = @user_id
      allow(RetentionService).to receive(:daily_return_rate).and_return(days: [], available: false, overall_return_rate_pct: nil)
      get '/metrics'
      expect(last_response.status).to eq(200)
      expect(last_response.body).to include('Measurement unavailable', 'not new-user cohort retention',
        'single-event days excluded and idle gaps included')
      expect(last_response.body).not_to include('D1 Return Rate')
      allow(RetentionService).to receive(:daily_return_rate).and_return(days: [], available: true, overall_return_rate_pct: nil)
      get '/metrics'
      expect(last_response.body).to include('No eligible recorded activity')
      expect(last_response.body).not_to include('Measurement unavailable')
    end

    %w[all 30d 7d 24h].each do |period|
      it "uses the same report for HTML, JSON and CSV for #{period}" do
        session[:user_id] = @user_id
        DB.execute("INSERT INTO meme_stats (url, title, subreddit, likes, views) VALUES (?, ?, ?, 80, 800)",
          ['/metrics-fixture.jpeg', '<script>private</script>', 'fixture'])
        %w[view like].each do |event|
          DB.execute('INSERT INTO meme_activity_log (meme_url, activity_type) VALUES (?, ?)', ['/metrics-fixture.jpeg', event])
        end
        get "/metrics.json?period=#{period}"
        expect(last_response.status).to eq(200)
        data = JSON.parse(last_response.body)
        expect(data['total_views']).to eq(period == 'all' ? 800 : 1)
        expect(data['total_likes']).to eq(period == 'all' ? 80 : 1)
        get "/metrics/export?period=#{period}"
        expect(last_response.status).to eq(200)
        require 'csv'
        csv = CSV.parse(last_response.body).select { |row| row.size == 2 }.to_h
        expect(csv['total_views'].to_i).to eq(data['total_views'])
        get "/metrics?period=#{period}"
        expect(last_response.status).to eq(200)
        expect(last_response.body).to include('UTC', '&lt;script&gt;private&lt;/script&gt;')
        expect(last_response.body).not_to include('<script>private</script>')
        expect(last_response.body).to include('View exact chart data', 'metrics-chart-status', 'Like actions')
        table = last_response.body.split('<details class="table-container" id="metrics-chart-data">').last.split('</details>').first
        values = table.scan(/<td>(\d+)<\/td>/).flatten.map(&:to_i)
        expect(values.each_slice(2).sum { |views, _| views }).to eq(data['chart_views'].sum)
        expect(values.each_slice(2).sum { |_, likes| likes }).to eq(data['chart_likes'].sum)
        expect(last_response.body).to include("class=\"active\">#{ { 'all' => 'All Time', '30d' => 'Last 30 Days', '7d' => 'Last 7 Days', '24h' => 'Last 24 Hours' }.fetch(period)}")
      end
    end

    it 'rejects invalid periods on every report endpoint' do
      session[:user_id] = @user_id
      %w[/metrics /metrics.json /metrics/export].each do |path|
        get path, period: 'bogus'
        expect(last_response.status).to eq(400)
      end
    end

    it 'keeps current global snapshots visible when a selected window has no activity' do
      session[:user_id] = @user_id
      get '/metrics?period=24h'
      expect(last_response.status).to eq(200)
      expect(last_response.body).to include('No data yet for this period',
        'Registered accounts — all time', 'Currently saved entries — all time', 'metricsChart')
    end

    it 'returns unavailable instead of presenting database failure as zero activity' do
      session[:user_id] = @user_id
      allow(MetricsReport).to receive(:build).and_raise(PG::Error)
      get '/metrics?period=7d'
      expect(last_response.status).to eq(503)
      expect(last_response.body).to include('no totals inferred')
    end

    it "renders successfully with no selection latency data yet" do
      RedisService.with_redis do |redis|
        redis.del(
          "#{SelectionBenchmark::REDIS_KEY_PREFIX}:total",
          "#{SelectionBenchmark::REDIS_KEY_PREFIX}:pool_lookup",
          "#{SelectionBenchmark::REDIS_KEY_PREFIX}:pool_manager_lookup",
          "#{SelectionBenchmark::REDIS_KEY_PREFIX}:reddit_fetch",
          "#{SelectionBenchmark::REDIS_KEY_PREFIX}:selection"
        )
      end

      authenticated_get "/metrics"

      expect(last_response.status).to eq(200)
      expect(last_response.body).to include("Selection Latency")
      expect(last_response.body).to include("No data yet")
    end

    it "renders the selection latency breakdown when real data exists" do
      SelectionBenchmark.record(5.5, stage: :total)
      SelectionBenchmark.record(2.1, stage: :pool_lookup)
      SelectionBenchmark.record(0.8, stage: :pool_manager_lookup)
      SelectionBenchmark.record(3.0, stage: :selection)

      authenticated_get "/metrics"

      expect(last_response.status).to eq(200)
      expect(last_response.body).to include("5.5ms")
      expect(last_response.body).to include("MemePoolManager (Redis)")
      expect(last_response.body).to include("Selection Algorithm")
    end

    it "returns the selection_latency breakdown in the JSON API" do
      SelectionBenchmark.record(10.0, stage: :total)

      env "rack.session", { user_id: @user_id }
      header "Accept", "application/json"
      get "/metrics.json"

      expect(last_response.status).to eq(200)
      data = JSON.parse(last_response.body)
      expect(data).to have_key("selection_latency")
      expect(data["selection_latency"]).to have_key("total")
      expect(data["selection_latency"]["total"]["count"]).to be >= 1
    end
  end
end
