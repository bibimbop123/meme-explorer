require_relative "../../spec/spec_helper"

describe "Health Monitoring Routes" do
  describe "GET /health" do
    it "returns 200 OK" do
      get "/health"
      expect(last_response.status).to eq(200)
    end
    
    # BUG FIX: this asserted a response shape (`status: "ok"` unconditionally,
    # top-level `requests`/`avg_response_time_ms`/`error_rate_5m` keys)
    # that doesn't match the real, current /health route
    # (routes/health.rb) - the real response has `checks: {database:,
    # redis:, cache:, meme_pool:}`, no request-count tracking at all, and
    # an honestly-computed top-level `status` that's `"warning"` whenever
    # any sub-check (e.g. meme_pool being empty in a fresh test process)
    # is degraded - this is the same intentional, no-fake-numbers
    # philosophy already documented in README.md's Performance section.
    # Assert against the real response shape instead.
    it "returns JSON with health status" do
      get "/health"
      data = JSON.parse(last_response.body)
      expect(data).to have_key("status")
      expect(data).to have_key("timestamp")
      expect(data).to have_key("uptime_seconds")
      expect(data["checks"]).to include("database", "redis", "cache", "meme_pool")
      expect(data["checks"]["database"]["status"]).to eq("healthy")
    end
  end

  describe "GET /errors (admin only)" do
    it "returns 403 to non-admin users" do
      get "/errors"
      expect(last_response.status).to eq(403)
    end
  end
end
