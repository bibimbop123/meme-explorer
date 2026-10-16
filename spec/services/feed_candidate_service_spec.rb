require_relative '../spec_helper'
require_relative '../../lib/services/feed_candidate_service'
require_relative '../../lib/services/feed_acknowledgement_service'
require 'timeout'

RSpec.describe MemeExplorer::FeedCandidateService do
  let(:identity) { SecureRandom.hex(32) }
  let(:issuer) { MemeExplorer::FeedIssuanceService }
  let(:store) { MemeExplorer::FeedAcknowledgementStore }
  let(:leases) { MemeExplorer::FeedReservationService }

  after do
    RedisService.with_redis do |r|
      r.del(*store.send(:keys, identity), store.send(:pending_key, identity),
        *leases.send(:keys, identity), "feed:acknowledged:v1:{#{Digest::SHA256.hexdigest(identity)}}:history")
    end
  end

  it 'keeps abandoned supply unseen and reports exhaustion only after real acknowledgements' do
    pool = [{ url: '/first.jpg' }, { url: '/second.jpg' }]
    first = described_class.select(pool, identity)
    second = described_class.select(pool, identity)
    expect([first[:status], second[:status]]).to eq([:issued, :issued])
    expect(first[:meme]).not_to eq(second[:meme])
    expect(described_class.select(pool, identity)).to eq(status: :temporarily_reserved)
    expect(store.history(identity)).to eq(status: :available, entries: [])
    expect(DB.get_first_value('SELECT COUNT(*) FROM meme_impressions').to_i).to eq(0)
    expiry = leases.send(:keys, identity).first
    RedisService.with_redis { |r| r.zadd(expiry, 0, Digest::SHA256.hexdigest('/first.jpg')) }
    recovered = described_class.select(pool, identity)
    expect(recovered[:status]).to eq(:issued)
    expect(recovered[:meme]).to eq(pool.first)
    [recovered, second].each do |result|
      expect(MemeExplorer::FeedAcknowledgementService.acknowledge(identity, result[:token],
        impression_id: result[:impression_id])[:status]).to eq(:acknowledged)
    end
    expect(described_class.select(pool, identity)).to eq(status: :exhausted)
    expect(store.history(identity)[:entries].size).to eq(2)
    expect(DB.get_first_value('SELECT SUM(views) FROM meme_stats').to_i).to eq(2)
  end

  it 'issues distinct candidates to simultaneous traversals of the same ordered pool' do
    pool = [{ url: '/concurrent-one.jpg' }, { url: '/concurrent-two.jpg' }]
    session_id = identity
    ready, start = Queue.new, Queue.new
    threads = 2.times.map do
      Thread.new do
        ready << true
        start.pop
        described_class.select(pool, session_id)
      end
    end
    Timeout.timeout(10) { 2.times { ready.pop } }
    2.times { start << true }
    results = threads.map(&:value)
    expect(results.map { |result| result[:status] }).to eq([:issued, :issued])
    expect(results.map { |result| result[:meme][:url] }.uniq.size).to eq(2)
    expect(results.map { |result| result[:impression_id] }.uniq.size).to eq(2)
    expect(store.history(identity)).to eq(status: :available, entries: [])
    expect(described_class.select(pool, identity)).to eq(status: :temporarily_reserved)
  ensure
    2.times { start << true } if start
    threads&.each(&:join)
  end

  it 'retains traversal contention after DB rollback and recovers with the same credential' do
    pool = [{ url: '/db-retry.jpg' }]
    selected = described_class.select(pool, identity)
    allow(DB).to receive(:execute).and_call_original
    allow(DB).to receive(:execute).with(a_string_including('INSERT INTO meme_activity_log'), anything).and_raise(StandardError)
    ack = MemeExplorer::FeedAcknowledgementService
    expect(ack.acknowledge(identity, selected[:token], impression_id: selected[:impression_id])).to eq(status: :unavailable, stage: :database)
    expect(DB.get_first_value('SELECT COUNT(*) FROM meme_impressions').to_i).to eq(0)
    expect(store.history(identity)).to eq(status: :available, entries: [])
    expect(described_class.select(pool, identity)).to eq(status: :temporarily_reserved)
    allow(DB).to receive(:execute).and_call_original
    expect(ack.acknowledge(identity, selected[:token], impression_id: selected[:impression_id])).to eq(status: :acknowledged, recorded: true)
    expect(described_class.select(pool, identity)).to eq(status: :exhausted)
    expect(DB.get_first_value('SELECT SUM(views) FROM meme_stats').to_i).to eq(1)
  end

  it 'repairs a real Redis schema failure after DB commit without releasing a successor' do
    pool = [{ url: '/history-retry.jpg' }]
    selected = described_class.select(pool, identity)
    history = "feed:acknowledged:v1:{#{Digest::SHA256.hexdigest(identity)}}:history"
    RedisService.with_redis { |r| r.set(history, 'wrong-type') }
    ack = MemeExplorer::FeedAcknowledgementService
    expect(ack.acknowledge(identity, selected[:token], impression_id: selected[:impression_id])).to eq(status: :unavailable, stage: :history, recorded: true)
    expect(described_class.select(pool, identity)).to eq(status: :unavailable, stage: :reservation)
    timestamp = DB.get_first_value('SELECT EXTRACT(EPOCH FROM created_at) FROM meme_impressions WHERE id = ?', [selected[:impression_id]]).to_f
    RedisService.with_redis do |r|
      r.del(history)
      r.zadd(leases.send(:keys, identity).first, 0, Digest::SHA256.hexdigest('/history-retry.jpg'))
    end
    successor = described_class.select(pool, identity)
    expect(successor[:status]).to eq(:issued)
    binding = store.lookup(identity, successor[:token])
    expect(ack.acknowledge(identity, selected[:token], impression_id: selected[:impression_id])).to eq(status: :acknowledged, recorded: false)
    expect(leases.validate(identity, '/history-retry.jpg', binding[:reservation_token])).to eq(status: :active)
    expect(store.history(identity)).to eq(status: :available, entries: [{ content: '/history-retry.jpg', acknowledged_at: timestamp }])
    expect(described_class.select(pool, identity)).to eq(status: :exhausted)
    expect(DB.get_first_value('SELECT SUM(views) FROM meme_stats').to_i).to eq(1)
    expect(DB.get_first_value("SELECT COUNT(*) FROM meme_activity_log WHERE activity_type = 'view'").to_i).to eq(1)
  end

  it 'tries each identity once in supplied order and returns the issued candidate' do
    seen = { 'url' => '/seen.jpg' }
    busy = { file: '/busy.jpg' }
    fresh = { 'url' => '/fresh.jpg', 'title' => 'Fresh' }
    expect(issuer).to receive(:issue).with(identity, '/seen.jpg', title: nil, subreddit: nil, user_id: nil).once.ordered.and_return(status: :already_acknowledged)
    expect(issuer).to receive(:issue).with(identity, '/busy.jpg', title: nil, subreddit: nil, user_id: nil).once.ordered.and_return(status: :already_reserved)
    expect(issuer).to receive(:issue).with(identity, '/fresh.jpg', title: 'Fresh', subreddit: nil, user_id: nil).once.ordered.and_return(status: :issued, token: 'credential')
    expect(described_class.select([seen, seen.dup, busy, fresh], identity)).to eq(status: :issued, token: 'credential', meme: fresh)
  end

  it 'cleans up speculative leases at real pending capacity and preserves pending credentials' do
    credentials = store::LIMIT.times.map do |i|
      store.issue(identity, "/pending-cap-#{i}.jpg", impression_id: SecureRandom.hex(32)).fetch(:token)
    end
    pool = [{ url: '/capacity-first.jpg' }, { url: '/capacity-second.jpg' }]
    expect(described_class.select(pool, identity)).to eq(status: :limit_reached, stage: :credential)
    RedisService.with_redis do |r|
      expiry, owners = leases.send(:keys, identity)
      expect(r.zcard(expiry)).to eq(0)
      expect(r.hlen(owners)).to eq(0)
      expect(r.zcard(store.send(:pending_key, identity))).to eq(store::LIMIT)
    end
    expect(store.lookup(identity, credentials.first)[:status]).to eq(:valid)
    expect(store.history(identity)).to eq(status: :available, entries: [])
    expect(DB.get_first_value('SELECT COUNT(*) FROM meme_impressions').to_i).to eq(0)
  end

  it 'retains completed retry receipts at real total capacity and cleans up the attempted lease' do
    retained = nil
    store::TOTAL_LIMIT.times do |i|
      impression = SecureRandom.hex(32)
      issued = store.issue(identity, "/receipt-cap-#{i}.jpg", impression_id: impression)
      retained ||= issued[:token]
      expect(store.reconcile(identity, issued[:token], impression_id: impression,
        acknowledged_at: Time.now.to_f - 1)[:status]).to eq(:reconciled)
    end
    expect(described_class.select([{ url: '/total-overflow.jpg' }], identity)).to eq(status: :receipt_limit_reached, stage: :credential)
    expect(store.lookup(identity, retained)[:status]).to eq(:valid)
    RedisService.with_redis do |r|
      expect(r.zcard(leases.send(:keys, identity).first)).to eq(0)
      expect(r.hlen(store.send(:keys, identity).last)).to eq(store::TOTAL_LIMIT)
      expect(r.zcard(store.send(:pending_key, identity))).to eq(0)
    end
  end

  it 'distinguishes acknowledged exhaustion from temporary reservation contention' do
    pool = [{ 'url' => '/one.jpg' }, { 'url' => '/two.jpg' }]
    allow(issuer).to receive(:issue).and_return(status: :already_acknowledged)
    expect(described_class.select(pool, identity)).to eq(status: :exhausted)
    allow(issuer).to receive(:issue).with(identity, '/two.jpg', anything).and_return(status: :already_reserved)
    expect(described_class.select(pool, identity)).to eq(status: :temporarily_reserved)
  end

  it 'stops at capacity or infrastructure failure without trying another candidate' do
    [:limit_reached, :receipt_limit_reached, :unavailable].each do |status|
      allow(issuer).to receive(:issue).with(identity, '/first.jpg', anything).and_return(status: status, stage: :credential)
      expect(issuer).not_to receive(:issue).with(identity, '/second.jpg', anything)
      expect(described_class.select([{ url: '/first.jpg' }, { url: '/second.jpg' }], identity)).to eq(status: status, stage: :credential)
    end
  end

  it 'rejects malformed candidates and distinguishes empty supply' do
    expect(issuer).not_to receive(:issue)
    expect(described_class.select([], identity)).to eq(status: :empty)
    [nil, [nil], [{}], [{ url: ' ' }]].each do |pool|
      expect(described_class.select(pool, identity)).to eq(status: :invalid)
    end
    expect(described_class.select([], 'invalid')).to eq(status: :invalid)
  end

  it 'rejects invalid user identity independently of inventory or continuation position' do
    expect(issuer).not_to receive(:issue)
    ['1', 0, -1, 1.5, false, 2_147_483_648].each do |user_id|
      expect(described_class.select([], identity, user_id: user_id)).to eq(status: :invalid)
      expect(described_class.select([{ url: '/identity.jpg' }], identity, user_id: user_id)).to eq(status: :invalid)
      expect(described_class.select([{ url: '/identity.jpg' }], identity, user_id: user_id, offset: 1)).to eq(status: :invalid)
    end
    expect(described_class.select([], identity, user_id: 1)).to eq(status: :empty)
  end

  it 'bounds issuance attempts without claiming an unvisited candidate is exhausted' do
    pool = (described_class::MAX_ATTEMPTS + 1).times.map { |i| { url: "/budget-#{i}.jpg" } }
    expect(issuer).to receive(:issue).exactly(described_class::MAX_ATTEMPTS).times.and_return(status: :already_acknowledged)
    expect(described_class.select(pool, identity)).to eq(status: :traversal_incomplete, next_offset: described_class::MAX_ATTEMPTS, reserved: false)
  end

  it 'can report exhaustion when the complete pool exactly fits the attempt budget' do
    pool = described_class::MAX_ATTEMPTS.times.map { |i| { url: "/exact-#{i}.jpg" } }
    expect(issuer).to receive(:issue).exactly(described_class::MAX_ATTEMPTS).times.and_return(status: :already_acknowledged)
    expect(described_class.select(pool, identity)).to eq(status: :exhausted)
  end

  it 'bounds duplicate inspection separately from issuance attempts' do
    pool = Array.new(described_class::MAX_INSPECTED) { { url: '/duplicate-budget.jpg' } }
    pool << { url: '/unvisited.jpg' }
    expect(issuer).to receive(:issue).once.and_return(status: :already_reserved)
    expect(described_class.select(pool, identity)).to eq(status: :traversal_incomplete, next_offset: described_class::MAX_INSPECTED, reserved: true)
  end

  it 'continues to a later candidate without rescanning an acknowledged prefix' do
    pool = (described_class::MAX_ATTEMPTS + 1).times.map { |i| { url: "/continue-#{i}.jpg" } }
    allow(issuer).to receive(:issue).and_return(status: :already_acknowledged)
    first = described_class.select(pool, identity)
    expect(first[:status]).to eq(:traversal_incomplete)
    expect(issuer).to receive(:issue).with(identity, pool.last[:url], anything).once.and_return(status: :issued, token: 'later')
    expect(described_class.select(pool, identity, offset: first[:next_offset])).to eq(status: :issued, token: 'later', meme: pool.last)
  end

  it 'never claims whole-pool exhaustion from a resumed suffix' do
    allow(issuer).to receive(:issue).and_return(status: :already_acknowledged)
    pool = [{ url: '/prefix.jpg' }, { url: '/suffix.jpg' }]
    expect(described_class.select(pool, identity, offset: 1)).to eq(status: :suffix_complete, reserved: false)
    allow(issuer).to receive(:issue).and_return(status: :already_reserved)
    expect(described_class.select(pool, identity, offset: 1)).to eq(status: :suffix_complete, reserved: true)
    expect(described_class.select(pool, identity, offset: 2)).to eq(status: :suffix_complete, reserved: false)
  end

  it 'rejects malformed and out-of-range continuation offsets before issuance' do
    expect(issuer).not_to receive(:issue)
    [nil, '0', -1, 1.5, 2].each do |offset|
      expect(described_class.select([{ url: '/one.jpg' }], identity, offset: offset)).to eq(status: :invalid)
    end
  end

  it 'exposes a prefix reservation conflict even when the remaining suffix is acknowledged' do
    pool = (described_class::MAX_ATTEMPTS + 1).times.map { |i| { url: "/conflict-#{i}.jpg" } }
    allow(issuer).to receive(:issue).and_return(status: :already_acknowledged)
    allow(issuer).to receive(:issue).with(identity, pool.first[:url], anything).and_return(status: :already_reserved)
    prefix = described_class.select(pool, identity)
    expect(prefix).to eq(status: :traversal_incomplete, next_offset: described_class::MAX_ATTEMPTS, reserved: true)
    suffix = described_class.select(pool, identity, offset: prefix[:next_offset])
    expect(suffix).to eq(status: :suffix_complete, reserved: false)
    expect(prefix[:reserved] || suffix[:reserved]).to eq(true)
  end

  it 'continues beyond a real acknowledged prefix and commits only the newly acknowledged item' do
    pool = (described_class::MAX_ATTEMPTS + 1).times.map { |i| { url: "/real-continuation-#{i}.jpg" } }
    ack = MemeExplorer::FeedAcknowledgementService
    pool.first(described_class::MAX_ATTEMPTS).each do |meme|
      issued = issuer.issue(identity, meme[:url])
      expect(ack.acknowledge(identity, issued[:token], impression_id: issued[:impression_id])[:status]).to eq(:acknowledged)
    end
    original_history = store.history(identity)[:entries]
    prefix = described_class.select(pool, identity)
    expect(prefix).to eq(status: :traversal_incomplete, next_offset: described_class::MAX_ATTEMPTS, reserved: false)
    selected = described_class.select(pool, identity, offset: prefix[:next_offset])
    expect(selected[:status]).to eq(:issued)
    expect(selected[:meme]).to eq(pool.last)
    expect(store.history(identity)[:entries]).to eq(original_history)
    expect(DB.get_first_value('SELECT SUM(views) FROM meme_stats').to_i).to eq(described_class::MAX_ATTEMPTS)
    expect(ack.acknowledge(identity, selected[:token], impression_id: selected[:impression_id])).to eq(status: :acknowledged, recorded: true)
    expect(store.history(identity)[:entries].first(original_history.size)).to eq(original_history)
    expect(DB.get_first_value('SELECT SUM(views) FROM meme_stats').to_i).to eq(pool.size)
    expect(described_class.select(pool, identity, offset: prefix[:next_offset])).to eq(status: :suffix_complete, reserved: false)
  end
end