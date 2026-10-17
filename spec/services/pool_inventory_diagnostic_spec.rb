require_relative '../spec_helper'
require_relative '../../scripts/check_pool_inventory'
require 'open3'
require 'rbconfig'

RSpec.describe PoolInventoryDiagnostic do
  it 'fails without configuration using only a generic diagnostic' do
    stdout, stderr, status = Open3.capture3({ 'REDIS_URL' => nil }, RbConfig.ruby,
      File.expand_path('../../scripts/check_pool_inventory.rb', __dir__))
    expect(status.exitstatus).to eq(1)
    expect(stdout).to eq('')
    expect(stderr).to eq("Inventory diagnostic failed. Check REDIS_URL, Redis access and pool key types; connection details omitted.\n")
  end

  it 'does not expose credentials or connection details for invalid configuration' do
    stdout, stderr, status = Open3.capture3(
      { 'REDIS_URL' => 'invalid-scheme://diagnostic-user:synthetic-sensitive-value@invalid.example:1234/0' },
      RbConfig.ruby, File.expand_path('../../scripts/check_pool_inventory.rb', __dir__))
    expect(status.exitstatus).to eq(1)
    expect(stdout).to eq('')
    expect(stderr).to include('connection details omitted')
    expect(stderr).not_to include('diagnostic-user', 'synthetic-sensitive-value', 'invalid.example', 'invalid-scheme', 'backtrace')
  end

  it 'reads only fixed metadata keys without retrieving payloads or lock owners' do
    redis = double
    expect(redis).to receive(:get).with('meme_pool:count').and_return('167')
    expect(redis).to receive(:get).with('meme_pool:last_refresh').and_return('1000')
    allow(redis).to receive(:ttl).and_return(300)
    allow(redis).to receive(:llen).and_return(167)
    report = described_class.report(redis, now: 1060)
    expect(report).to include(metadata_count: 167, seconds_since_refresh: 60, cooldown_ttl: 300)
    expect(report[:pools]['random']).to include(list_count: 167, list_ttl: 300)
    expect(report.to_json).not_to include('redis://', 'Bearer')
  end

  it 'reports missing or malformed metadata without inventing zero inventory' do
    redis = double
    allow(redis).to receive(:get).with('meme_pool:count').and_return('invalid')
    allow(redis).to receive(:get).with('meme_pool:last_refresh').and_return(nil)
    allow(redis).to receive(:ttl).and_return(-2)
    allow(redis).to receive(:llen).and_return(0)
    expect(described_class.report(redis)).to include(metadata_count: nil, seconds_since_refresh: nil, legacy_pool_ttl: -2)
  end

  it 'summarizes unique source ages without exporting content or treating unknown as fresh' do
    now = Time.utc(2026, 10, 16).to_i
    rows = [
      { 'url' => '/private-one', 'created_at' => Time.at(now - 60).utc.iso8601, 'title' => 'private-title' },
      { 'url' => '/private-one' },
      { 'url' => '/private-two', 'created_at' => Time.at(now - 172800).utc.iso8601 },
      { 'url' => '/private-three', 'created_at' => Time.at(now - 700000).utc.iso8601 },
      { 'url' => '/private-four', 'created_at' => 'invalid' },
      { 'url' => '/private-five', 'created_at' => Time.at(now + 60).utc.iso8601 }, nil
    ]
    redis = double
    expect(redis).to receive(:getrange).with('meme_pool', 0, described_class::MAX_PAYLOAD_BYTES).and_return(rows.to_json)
    report = described_class.content_summary(redis, now: now)
    expect(report).to include(status: 'available', payload_bytes: rows.to_json.bytesize, records: 7, unique_urls: 5, duplicate_urls: 1,
      invalid_records: 1, source_age_under_day: 1, source_age_one_to_seven_days: 1,
      source_age_over_seven_days: 1, source_age_unknown: 2)
    expect(report.to_json).not_to include('/private', 'private-title')
  end

  it 'rejects absent, malformed and oversized summaries without unbounded payload reads' do
    redis = double
    ['', '{', '{}', Array.new(described_class::MAX_RECORDS + 1).to_json].each do |raw|
      allow(redis).to receive(:getrange).and_return(raw)
      expect(described_class.content_summary(redis)[:status]).not_to eq('available')
    end
    allow(redis).to receive(:getrange).and_return('x' * (described_class::MAX_PAYLOAD_BYTES + 1))
    expect(described_class.content_summary(redis)).to eq(status: 'oversized')
  end

  it 'keeps missing source dates unknown immediately after a fresh record' do
    now = Time.utc(2026, 10, 16).to_i
    redis = double
    rows = [{ 'url' => '/fresh', 'created_at' => Time.at(now - 60).utc.iso8601 },
            { 'url' => '/unknown' }, { 'url' => '/future', 'created_at' => Time.at(now + 60).utc.iso8601 }, nil]
    allow(redis).to receive(:getrange).and_return(rows.to_json)
    expect(described_class.content_summary(redis, now: now)).to include(
      source_age_under_day: 1, source_age_unknown: 2, invalid_records: 1,
      unique_urls: 3, duplicate_urls: 0)
  end

  it 'reports byte size rather than character count without another Redis read' do
    raw = [{ 'url' => '/example', 'title' => '笑' }].to_json
    redis = double
    expect(redis).to receive(:getrange).with('meme_pool', 0, described_class::MAX_PAYLOAD_BYTES).once.and_return(raw)
    report = described_class.content_summary(redis)
    expect(report[:payload_bytes]).to eq(raw.bytesize)
    expect(report[:payload_bytes]).to be > raw.length
    expect(report.to_json).not_to include('/example', '笑')
  end
end