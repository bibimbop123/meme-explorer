require_relative '../spec_helper'
require_relative '../../scripts/check_pool_inventory'

RSpec.describe PoolInventoryDiagnostic do
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
end