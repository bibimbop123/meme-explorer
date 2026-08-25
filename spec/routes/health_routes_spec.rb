# frozen_string_literal: true

require_relative '../spec_helper'

# Regression tests for the production incident (Aug 25, 2026, round 7)
# where GET /health's Redis check unconditionally merged
# `status: 'healthy', connected: true` on top of whatever RedisService.stats
# returned - so even when Redis was genuinely unreachable
# (`stats` => `{ available: false, error: 'Redis not available' }`), the
# response claimed `status: 'healthy'`/`connected: true` anyway, producing a
# self-contradictory payload that masked the real Redis outage responsible
# for MemePoolManager's bootstrap lock never succeeding.
describe "GET /health (routes/health.rb)" do
  it "reports redis as healthy when RedisService.stats says it's available" do
    allow(RedisService).to receive(:refresh_availability!)
    allow(RedisService).to receive(:stats).and_return(
      available: true, connected: true, used_memory: '1M', pool_size: 10, pool_available: 9
    )

    get "/health"
    data = JSON.parse(last_response.body)

    expect(data["checks"]["redis"]["status"]).to eq("healthy")
    expect(data["checks"]["redis"]["available"]).to eq(true)
  end

  it "reports redis as unhealthy (not healthy) when RedisService.stats says it's unavailable" do
    allow(RedisService).to receive(:refresh_availability!)
    allow(RedisService).to receive(:stats).and_return(
      available: false, error: 'Redis not available'
    )

    get "/health"
    data = JSON.parse(last_response.body)

    expect(data["checks"]["redis"]["status"]).to eq("unhealthy")
    expect(data["checks"]["redis"]["available"]).to eq(false)
    expect(data["status"]).to eq("degraded")
  end

  it "never returns a self-contradictory payload (available: false alongside status: healthy)" do
    allow(RedisService).to receive(:refresh_availability!)
    allow(RedisService).to receive(:stats).and_return(
      available: false, error: 'Redis not available'
    )

    get "/health"
    data = JSON.parse(last_response.body)
    redis_check = data["checks"]["redis"]

    # This exact contradiction was the production bug: available: false but status: healthy.
    expect(redis_check["available"]).to eq(false)
    expect(redis_check["status"]).not_to eq("healthy")
  end
end
