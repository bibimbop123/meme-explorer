require_relative '../spec_helper'
require_relative '../../lib/services/meme_pool_manager'

RSpec.describe 'Pool batch diagnostics' do
  let(:old) { { 'url' => '/old.jpg' } }
  let(:fresh) { { 'url' => '/new.jpg' } }

  before do
    allow(MemePoolManager).to receive(:create_fetcher).and_return(double(rate_limited?: false))
    allow(MemePoolManager).to receive(:fetch_from_tier).and_return([old, fresh, fresh])
    allow(MemePoolManager).to receive(:quality_filter) { |items| items }
    allow(MemePoolManager).to receive(:get_current_pool).and_return([old])
    allow(RedisService).to receive(:delete)
  end

  it 'distinguishes overlapping responses, candidate additions and publication' do
    allow(MemePoolManager).to receive(:store_in_pool).and_return(2)
    allow(AppLogger).to receive(:info)
    result = MemePoolManager.send(:fetch_batch, size: 100)
    expect(result).to include(fetched: 15, fetched_unique: 2, validated_unique: 2,
      previous_unique: 1, candidate_new_unique: 1, planned_unique: 2,
      publication_succeeded: true, stored: 2, rate_limited: false)
    expect(AppLogger).to have_received(:info).with('[PoolManager] Inventory batch outcome', **result)
  end

  it 'does not report successful publication when candidates could not be stored' do
    allow(MemePoolManager).to receive(:store_in_pool).and_return(0)
    expect(MemePoolManager.send(:fetch_batch, size: 100)).to include(
      candidate_new_unique: 1, planned_unique: 2, stored: 0, publication_succeeded: false)
  end
end