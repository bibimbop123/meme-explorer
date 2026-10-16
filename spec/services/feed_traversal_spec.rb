require_relative '../spec_helper'
require_relative '../../lib/services/feed_traversal'

RSpec.describe MemeExplorer::FeedTraversal do
  let(:identity) { SecureRandom.hex(32) }
  let(:issuer) { MemeExplorer::FeedIssuanceService }

  it 'binds copied metadata and deduplicates identities across chunk boundaries' do
    pool = 101.times.map { |i| { url: "/snapshot-#{i}.jpg", title: 'Original' } }
    pool << pool.first.dup
    traversal = described_class.new(pool, identity)
    pool.last[:url].replace('/mutated.jpg')
    pool.last[:title].replace('Mutated')
    pool.clear
    expect(issuer).to receive(:issue).with(identity, a_string_matching(%r{\A/snapshot-\d+\.jpg\z}),
      title: 'Original', subreddit: nil, user_id: nil).exactly(101).times.and_return(status: :already_acknowledged)
    expect(traversal.advance).to eq(status: :traversal_incomplete, reserved: false)
    expect(traversal.advance).to eq(status: :snapshot_complete, reserved: false, empty: false)
    expect(traversal.advance).to eq(status: :closed)
  end

  it 'aggregates prefix contention without treating snapshot completion as global exhaustion' do
    pool = 101.times.map { |i| { url: "/conflict-snapshot-#{i}.jpg" } }
    allow(issuer).to receive(:issue).and_return(status: :already_acknowledged)
    allow(issuer).to receive(:issue).with(identity, pool.first[:url], anything).and_return(status: :already_reserved)
    traversal = described_class.new(pool, identity)
    expect(traversal.advance).to eq(status: :traversal_incomplete, reserved: true)
    expect(traversal.advance).to eq(status: :snapshot_complete, reserved: true, empty: false)
  end

  it 'validates the entire bounded snapshot before any issuance' do
    expect(issuer).not_to receive(:issue)
    [nil, Array.new(described_class::MAX_CANDIDATES + 1), [{ url: '/valid.jpg' }, {}],
     [{ url: '/bad-context.jpg', title: [] }]].each do |pool|
      expect(described_class.new(pool, identity).advance).to eq(status: :invalid)
    end
    expect(described_class.new([], identity).advance).to eq(status: :snapshot_complete, reserved: false, empty: true)
  end

  it 'closes after issuance or failure instead of silently retrying the same snapshot' do
    [:issued, :unavailable, :receipt_limit_reached].each do |status|
      allow(issuer).to receive(:issue).and_return(status: status)
      traversal = described_class.new([{ url: '/terminal.jpg' }], identity)
      expect(traversal.advance[:status]).to eq(status)
      expect(traversal.advance).to eq(status: :closed)
    end
  end
end