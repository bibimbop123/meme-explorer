require_relative '../spec_helper'
require_relative '../../lib/services/meme_pool_manager'

RSpec.describe 'Non-destructive stale pool refresh' do
  let(:old) { { 'url' => '/old.jpg', 'fetched_at' => '2020-01-01T00:00:00Z' } }
  let(:recent) { { 'url' => '/recent.jpg', 'fetched_at' => '2026-01-01T00:00:00Z' } }
  let(:fresh) { { 'url' => '/fresh.jpg' } }

  before do
    allow(MemePoolManager).to receive(:get_current_pool).and_return([old, recent])
    allow(MemePoolManager).to receive(:create_fetcher).and_return(double(rate_limited?: false))
    allow(MemePoolManager).to receive(:fetch_from_tier).and_return([])
    allow(MemePoolManager).to receive(:quality_filter) { |items| items }
    allow(RedisService).to receive(:set)
    allow(RedisService).to receive(:delete)
    expect(MemePoolManager).not_to receive(:remove_from_pool)
  end

  it 'does not write or remove inventory when Reddit returns nothing' do
    expect(MemePoolManager).not_to receive(:store_in_pool)
    expect(MemePoolManager.send(:replace_stale, percentage: 0.5)).to eq(replaced: 0)
  end

  it 'leaves inventory untouched when every fetched item fails quality checks' do
    allow(MemePoolManager).to receive(:fetch_from_tier).and_return([fresh])
    allow(MemePoolManager).to receive(:quality_filter).and_return([])
    expect(MemePoolManager).not_to receive(:store_in_pool)
    expect(MemePoolManager.send(:replace_stale, percentage: 0.5)).to eq(replaced: 0)
  end

  it 'refreshes duplicate snapshots without retiring existing unique content' do
    snapshot = old.merge('title' => 'Updated')
    allow(MemePoolManager).to receive(:fetch_from_tier).and_return([snapshot])
    expect(MemePoolManager).to receive(:store_in_pool).with([snapshot, recent], expected_pool: anything).and_return(2)
    expect(MemePoolManager.send(:replace_stale, percentage: 0.5)).to eq(replaced: 0)
  end

  it 'retires only as many stale entries as there are new unique replacements' do
    allow(MemePoolManager).to receive(:fetch_from_tier).and_return([fresh])
    expect(MemePoolManager).to receive(:store_in_pool).with([fresh, recent], expected_pool: anything).and_return(2)
    expect(MemePoolManager.send(:replace_stale, percentage: 1.0)).to eq(replaced: 1)
  end

  it 'does not count refreshed stale snapshots as retired' do
    allow(MemePoolManager).to receive(:fetch_from_tier).and_return([fresh, old])
    expect(MemePoolManager).to receive(:store_in_pool).with([fresh, old], expected_pool: anything).and_return(2)
    expect(MemePoolManager.send(:replace_stale, percentage: 1.0)).to eq(replaced: 1)
  end

  it 'reports no replacement when publication fails' do
    allow(MemePoolManager).to receive(:fetch_from_tier).and_return([fresh])
    expect(MemePoolManager).to receive(:store_in_pool).with([fresh, recent], expected_pool: anything).and_return(0)
    expect(MemePoolManager.send(:replace_stale, percentage: 0.5)).to eq(replaced: 0)
  end

  it 'does not fetch when the rounded replacement budget is zero' do
    expect(MemePoolManager).not_to receive(:create_fetcher)
    expect(MemePoolManager.send(:replace_stale, percentage: 0.1)).to eq(replaced: 0)
  end

  it 'preserves inventory and reports unexpected fetch errors' do
    allow(MemePoolManager).to receive(:create_fetcher).and_raise('Fetch unavailable')
    expect(MemePoolManager).not_to receive(:store_in_pool)
    expect(MemePoolManager.send(:replace_stale, percentage: 0.5)).to eq(replaced: 0, error: 'Fetch unavailable')
  end

  it 'retires old source content before newer content even when fetched again recently' do
    refetched = old.merge('created_at' => '2019-01-01T00:00:00Z', 'fetched_at' => '2026-10-01T00:00:00Z')
    newer = recent.merge('created_at' => '2025-01-01T00:00:00Z')
    allow(MemePoolManager).to receive(:get_current_pool).and_return([newer, refetched])
    allow(MemePoolManager).to receive(:fetch_from_tier).and_return([fresh])
    expect(MemePoolManager).to receive(:store_in_pool).with([fresh, newer], expected_pool: anything).and_return(2)
    expect(MemePoolManager.send(:replace_stale, percentage: 0.5)).to eq(replaced: 1)
  end

  it 'falls back to fetch age for invalid source dates and leaves unknown age last' do
    invalid = old.merge('created_at' => 'not-a-time')
    future = recent.merge('created_at' => '2100-01-01T00:00:00Z')
    unknown = { 'url' => '/unknown.jpg', 'created_at' => [], 'fetched_at' => nil }
    expect(MemePoolManager.send(:find_stale_memes, [unknown, future, invalid], 3)).to eq([
      '/old.jpg', '/recent.jpg', '/unknown.jpg'
    ])
  end
end