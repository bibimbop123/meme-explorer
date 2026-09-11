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
