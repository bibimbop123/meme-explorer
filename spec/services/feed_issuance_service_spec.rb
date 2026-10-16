require_relative '../spec_helper'
require_relative '../../lib/services/feed_issuance_service'
require_relative '../../lib/services/feed_acknowledgement_service'

RSpec.describe MemeExplorer::FeedIssuanceService do
  let(:identity) { SecureRandom.hex(32) }
  let(:content) { '/issuance.jpg' }
  let(:store) { MemeExplorer::FeedAcknowledgementStore }
  let(:leases) { MemeExplorer::FeedReservationService }

  after do
    RedisService.with_redis do |r|
      r.del(*store.send(:keys, identity), store.send(:pending_key, identity),
        *leases.send(:keys, identity), "feed:acknowledged:v1:{#{Digest::SHA256.hexdigest(identity)}}:history")
    end
  end

  it 'issues a bound credential without marking history or counters until ACK' do
    result = described_class.issue(identity, content, title: 'Issued')
    expect(result[:status]).to eq(:issued)
    binding = store.lookup(identity, result[:token], impression_id: result[:impression_id])
    expect(binding[:context]['title']).to eq('Issued')
    expect(leases.validate(identity, content, binding[:reservation_token])).to eq(status: :active)
    expect(MemeExplorer::ViewingHistoryService.get_seen_memes(identity)).to eq([])
    expect(DB.get_first_value('SELECT COUNT(*) FROM meme_impressions').to_i).to eq(0)
    expect(MemeExplorer::FeedAcknowledgementService.acknowledge(identity, result[:token],
      impression_id: result[:impression_id])).to eq(status: :acknowledged, recorded: true)
    expect(leases.validate(identity, content, binding[:reservation_token])).to eq(status: :invalid)
  end

  it 'does not issue credentials or release an existing reservation on collision' do
    original = leases.acquire(identity, content)
    expect(store).not_to receive(:issue)
    expect(described_class.issue(identity, content)).to eq(status: :already_reserved, stage: :reservation)
    expect(leases.validate(identity, content, original[:token])).to eq(status: :active)
  end

  it 'rejects malformed attribution before acquiring or cleaning up any lease' do
    expect(leases).not_to receive(:acquire_unseen)
    expect(leases).not_to receive(:release)
    expect(store).not_to receive(:issue)
    [{ title: [] }, { title: ' ' }, { subreddit: 'x' * 4097 },
     { user_id: '1' }, { user_id: 0 }, { user_id: 2_147_483_648 }].each do |context|
      expect(described_class.issue(identity, content, **context)).to eq(status: :invalid, stage: :credential)
    end
    expect(store.history(identity)).to eq(status: :available, entries: [])
    expect(DB.get_first_value('SELECT COUNT(*) FROM meme_impressions').to_i).to eq(0)
  end

  it 'rejects a stale candidate acknowledged after candidate selection' do
    first = described_class.issue(identity, content)
    expect(MemeExplorer::FeedAcknowledgementService.acknowledge(identity, first[:token],
      impression_id: first[:impression_id])[:status]).to eq(:acknowledged)
    expect(store).not_to receive(:issue)
    expect(described_class.issue(identity, content)).to eq(status: :already_acknowledged, stage: :reservation)
    expect(RedisService.with_redis { |r| r.zcard(leases.send(:keys, identity).first) }).to eq(0)
  end

  it 'admits content after acknowledged history ages out, without resetting history' do
    history = "feed:acknowledged:v1:{#{Digest::SHA256.hexdigest(identity)}}:history"
    RedisService.with_redis do |r|
      r.zadd(history, Time.now.to_f - MemeExplorer::ViewingHistoryService::HISTORY_TTL - 1, content)
    end
    expect(described_class.issue(identity, content)[:status]).to eq(:issued)
    expect(RedisService.with_redis { |r| r.zcard(history) }).to eq(1)
  end

  it 'fails closed on corrupt acknowledged history without acquiring a lease' do
    history = "feed:acknowledged:v1:{#{Digest::SHA256.hexdigest(identity)}}:history"
    RedisService.with_redis { |r| r.set(history, 'wrong-type') }
    expect(described_class.issue(identity, content)).to eq(status: :unavailable, stage: :reservation)
    expect(RedisService.with_redis { |r| r.zcard(leases.send(:keys, identity).first) }).to eq(0)
  end

  it 'releases acquired leases for credential failures and both capacity outcomes' do
    [:invalid, :unavailable, :limit_reached, :receipt_limit_reached].each do |status|
      allow(store).to receive(:issue).and_return(status: status)
      expect(described_class.issue(identity, content)).to eq(status: status, stage: :credential)
      replacement = leases.acquire(identity, content)
      expect(replacement[:status]).to eq(:reserved)
      leases.release(identity, content, replacement[:token])
    end
  end

  it 'cleans up on unexpected issuance exceptions without leaking details' do
    allow(store).to receive(:issue).and_raise(StandardError, 'private details')
    expect(described_class.issue(identity, content)).to eq(status: :unavailable, stage: :credential)
    expect(leases.acquire(identity, content)[:status]).to eq(:reserved)
  end

  it 'does not release a successor when credential issuance fails after ownership changes' do
    successor = nil
    allow(store).to receive(:issue) do |session_id, url, **options|
      leases.release(session_id, url, options[:reservation_token])
      successor = leases.acquire(session_id, url)
      { status: :unavailable }
    end
    expect(described_class.issue(identity, content)).to eq(status: :unavailable, stage: :credential)
    expect(leases.validate(identity, content, successor[:token])).to eq(status: :active)
  end

  it 'bounds orphan credentials after a saved issuance response is lost' do
    allow(store).to receive(:issue).and_wrap_original do |original, *args, **options|
      expect(original.call(*args, **options)[:status]).to eq(:issued)
      { status: :unavailable } # Simulate a lost response after Redis saved metadata.
    end
    store::LIMIT.times do
      expect(described_class.issue(identity, content)).to eq(status: :unavailable, stage: :credential)
    end
    allow(store).to receive(:issue).and_call_original
    expect(described_class.issue(identity, content)).to eq(status: :limit_reached, stage: :credential)
    RedisService.with_redis do |r|
      expiry, metadata = store.send(:keys, identity)
      pending = store.send(:pending_key, identity)
      expect(r.hlen(metadata)).to eq(store::LIMIT)
      expect(r.zcard(pending)).to eq(store::LIMIT)
      [expiry, metadata, pending].each { |key| expect(r.ttl(key)).to be_between(1, store::TTL) }
      expect(r.zcard(leases.send(:keys, identity).first)).to eq(0)
      r.zrange(expiry, 0, -1).each { |member| r.zadd(expiry, 0, member) }
    end
    expect(store.history(identity)).to eq(status: :available, entries: [])
    expect(DB.get_first_value('SELECT COUNT(*) FROM meme_impressions').to_i).to eq(0)
    expect(described_class.issue(identity, content)[:status]).to eq(:issued)
    expect(RedisService.with_redis { |r| r.hlen(store.send(:keys, identity).last) }).to eq(1)
  end

  it 'recovers failed lease cleanup through original lease expiry' do
    allow(store).to receive(:issue).and_return(status: :unavailable)
    allow(leases).to receive(:release).and_return(false)
    expect(described_class.issue(identity, content)).to eq(status: :unavailable, stage: :credential)
    expect(described_class.issue(identity, content)).to eq(status: :already_reserved, stage: :reservation)
    RedisService.with_redis do |r|
      expiry, owners = leases.send(:keys, identity)
      [expiry, owners].each { |key| expect(r.ttl(key)).to be_between(1, leases::TTL) }
      r.zadd(expiry, 0, Digest::SHA256.hexdigest(content))
    end
    allow(store).to receive(:issue).and_call_original
    allow(leases).to receive(:release).and_call_original
    expect(described_class.issue(identity, content)[:status]).to eq(:issued)
  end
end