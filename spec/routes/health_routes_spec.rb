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
    # Overall status may be further overwritten by later checks (e.g. an
    # empty meme pool sets 'warning' after this), so just assert it's no
    # longer the healthy/default 'ok' value.
    expect(data["status"]).not_to eq("ok")
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

  # Regression test for the production incident (Aug 25, 2026, round 7)
  # where `MEME_CACHE` was referenced unqualified inside the
  # Routes::HealthRoutes module, raising
  # "uninitialized constant Routes::HealthRoutes::MEME_CACHE" - silently
  # caught and reported as `status: 'unhealthy'` for both the cache and
  # meme_pool checks, regardless of the actual cache state. This made
  # /health useless for diagnosing real cache/meme-pool problems.
  it "reports cache and meme_pool checks without raising a NameError for MEME_CACHE" do
    get "/health"
    data = JSON.parse(last_response.body)

    cache_error = data["checks"]["cache"]["error"]
    meme_pool_error = data["checks"]["meme_pool"]["error"]

    expect(cache_error.to_s).not_to match(/uninitialized constant/)
    expect(meme_pool_error.to_s).not_to match(/uninitialized constant/)
    expect(data["checks"]["cache"]).to have_key("status")
    expect(data["checks"]["meme_pool"]).to have_key("status")
  end

  # Regression test for the production incident (Aug 25, 2026, round 10)
  # where the meme_pool check only ever read
  # MemeExplorer::App::MEME_CACHE (the legacy in-process cache) - a
  # completely separate data source from MemePoolManager's Redis-backed
  # pool that actually serves production traffic. This made /health
  # report meme_count: 0 / status: warning even while MemePoolManager had
  # a full, healthy pool actively serving every request, making /health
  # useless for diagnosing real meme pool problems.
  describe "meme_pool check (round 10 regression)" do
    it "reports MemePoolManager's real pool size when it has memes" do
      allow(MemePoolManager).to receive(:get_pool_size).and_return(170)
      allow(RedisService).to receive(:get).with('meme_pool:last_refresh').and_return(Time.now.to_i.to_s)

      get "/health"
      data = JSON.parse(last_response.body)

      expect(data["checks"]["meme_pool"]["status"]).to eq("healthy")
      expect(data["checks"]["meme_pool"]["meme_count"]).to eq(170)
      expect(data["checks"]["meme_pool"]["source"]).to eq("MemePoolManager")
    end

    it "falls back to the legacy cache when MemePoolManager's pool is empty" do
      allow(MemePoolManager).to receive(:get_pool_size).and_return(0)

      get "/health"
      data = JSON.parse(last_response.body)

      expect(data["checks"]["meme_pool"]["source"]).to eq("legacy_cache")
    end
  end
end
