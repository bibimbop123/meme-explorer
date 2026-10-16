require_relative '../spec_helper'
require_relative '../../lib/services/feed_acknowledgement_store'
require_relative '../../lib/services/feed_reservation_service'

RSpec.describe MemeExplorer::FeedAcknowledgementStore do
  let(:identity) { SecureRandom.hex(32) }
  let(:impression) { SecureRandom.hex(32) }
  let(:history_key) { "feed:acknowledged:v1:{#{Digest::SHA256.hexdigest(identity)}}:history" }

  def race_redis(script, keys:, arguments:)
    connections = 2.times.map { Redis.new(url: ENV.fetch('REDIS_URL')) }
    ready, start = Queue.new, Queue.new
    threads = connections.each_with_index.map do |redis, index|
      Thread.new do
        ready << true
        start.pop
        redis.eval(script, keys: keys, argv: arguments[index])
      end
    end
    2.times { ready.pop }
    2.times { start << true }
    threads.map(&:value)
  ensure
    threads&.each(&:join)
    connections&.each(&:close)
  end
  after do
    RedisService.with_redis do |r|
      r.del(*described_class.send(:keys, identity), described_class.send(:pending_key, identity), history_key,
        *MemeExplorer::FeedReservationService.send(:keys, identity))
    end
  end

  it 'reconciles idempotently without refreshing the original history timestamp' do
    token = described_class.issue(identity, '/fixture.jpg', impression_id: impression)[:token]
    timestamp = Time.now.to_f - 10
    expect(described_class.reconcile(identity, token, impression_id: impression, acknowledged_at: timestamp)).to eq(status: :reconciled)
    expect(described_class.reconcile(identity, token, impression_id: impression, acknowledged_at: Time.now.to_f - 1)).to eq(status: :reconciled)
    RedisService.with_redis do |r|
      expect(r.zscore(history_key, '/fixture.jpg')).to eq(timestamp)
      expect(r.zcard(history_key)).to eq(1)
    end
    expect(MemeExplorer::ViewingHistoryService.get_seen_memes(identity)).to eq([])
  end

  it 'reads oldest-first acknowledged history, pruning age without renewing expiry' do
    now = Time.now.to_f
    RedisService.with_redis do |r|
      r.zadd(history_key, now - 2, '/older.jpg')
      r.zadd(history_key, now - 1, '/newer.jpg')
      r.zadd(history_key, now - MemeExplorer::ViewingHistoryService::HISTORY_TTL - 1, '/expired.jpg')
      r.expire(history_key, 60)
    end
    expect(described_class.history(identity)).to eq(status: :available, entries: [
      { content: '/older.jpg', acknowledged_at: now - 2 },
      { content: '/newer.jpg', acknowledged_at: now - 1 }
    ])
    expect(RedisService.with_redis { |r| r.ttl(history_key) }).to be_between(58, 60)
  end

  it 'bounds history snapshots to the newest retained entries' do
    now = Time.now.to_f
    maximum = MemeExplorer::ViewingHistoryService::MAX_HISTORY_SIZE
    RedisService.with_redis do |r|
      r.pipelined do |pipe|
        (maximum + 2).times { |i| pipe.zadd(history_key, now - maximum - 2 + i, "/history-#{i}.jpg") }
      end
    end
    result = described_class.history(identity)
    expect(result[:status]).to eq(:available)
    expect(result[:entries].size).to eq(maximum)
    expect(result[:entries].first[:content]).to eq('/history-2.jpg')
    expect(RedisService.with_redis { |r| r.zcard(history_key) }).to eq(maximum)
  end

  it 'distinguishes empty history from invalid identity and infrastructure or malformed data' do
    expect(described_class.history(identity)).to eq(status: :available, entries: [])
    expect(described_class.history('invalid')).to eq(status: :invalid)
    RedisService.with_redis { |r| r.set(history_key, 'wrong-type') }
    expect(described_class.history(identity)).to eq(status: :unavailable)
    [nil, ['odd'], ['/fixture.jpg', 'Infinity'], ['', '1']].each do |reply|
      allow(RedisService).to receive(:with_redis).and_return(reply)
      expect(described_class.history(identity)).to eq(status: :unavailable)
    end
    allow(RedisService).to receive(:with_redis).and_call_original
  end

  it 'rejects wrong-type reservation keys before history writes and repairs after recovery' do
    owner = SecureRandom.hex(32)
    token = described_class.issue(identity, '/fixture.jpg', impression_id: impression, reservation_token: owner).fetch(:token)
    lease_keys = MemeExplorer::FeedReservationService.send(:keys, identity)
    RedisService.with_redis { |r| r.set(lease_keys.last, 'wrong-type') }
    timestamp = Time.now.to_f - 1
    args = { impression_id: impression, acknowledged_at: timestamp, reservation_token: owner }
    expect(described_class.reconcile(identity, token, **args)).to eq(status: :unavailable)
    RedisService.with_redis do |r|
      expect(r.exists?(history_key)).to eq(false)
      expect(r.zcard(described_class.send(:pending_key, identity))).to eq(1)
      raw = r.hget(described_class.send(:keys, identity).last, Digest::SHA256.hexdigest(token))
      expect(JSON.parse(raw)).not_to have_key('acknowledged_at')
      r.del(lease_keys.last)
    end
    expect(described_class.reconcile(identity, token, **args)).to eq(status: :reconciled)
    expect(RedisService.with_redis { |r| r.zscore(history_key, '/fixture.jpg') }).to eq(timestamp)
  end

  it 'does not partially prune expired credentials when issuance keys have wrong types' do
    token = described_class.issue(identity, '/fixture.jpg', impression_id: impression).fetch(:token)
    expiry, metadata = described_class.send(:keys, identity)
    pending = described_class.send(:pending_key, identity)
    digest = Digest::SHA256.hexdigest(token)
    RedisService.with_redis do |r|
      r.zadd(expiry, 0, digest)
      r.del(pending)
      r.set(pending, 'wrong-type')
    end
    expect(described_class.issue(identity, '/next.jpg', impression_id: impression)).to eq(status: :unavailable)
    RedisService.with_redis do |r|
      expect(r.hexists(metadata, digest)).to eq(true)
      expect(r.zscore(expiry, digest)).to eq(0)
      r.del(pending)
    end
    expect(described_class.issue(identity, '/next.jpg', impression_id: impression)[:status]).to eq(:issued)
    expect(RedisService.with_redis { |r| r.hexists(metadata, digest) }).to eq(false)
  end

  it 'binds validated issuance context and rejects malformed stored context' do
    token = described_class.issue(identity, '/fixture.jpg', impression_id: impression,
      title: 'Fixture', subreddit: 'test', user_id: 12).fetch(:token)
    expect(described_class.lookup(identity, token)[:context]).to eq('title' => 'Fixture', 'subreddit' => 'test', 'user_id' => 12)
    [nil, {}, { 'title' => nil, 'subreddit' => nil, 'user_id' => '12' }].each do |context|
      payload = JSON.generate('content' => '/fixture.jpg', 'impression_id' => impression, 'context' => context)
      RedisService.with_redis { |r| r.hset(described_class.send(:keys, identity).last, Digest::SHA256.hexdigest(token), payload) }
      expect(described_class.lookup(identity, token)).to eq(status: :unavailable)
    end
  end

  it 'rejects invalid attribution at issuance' do
    [{ user_id: 0 }, { user_id: '1' }, { user_id: 2_147_483_648 }, { title: [] }, { subreddit: 'x' * 4097 }].each do |context|
      expect(described_class.issue(identity, '/fixture.jpg', impression_id: impression, **context)).to eq(status: :invalid)
    end
  end

  it 'admits sequential browsing beyond pending capacity while preserving retry credentials' do
    first = nil
    (described_class::LIMIT + 5).times do |i|
      issued = described_class.issue(identity, "/sequential-#{i}.jpg", impression_id: impression)
      expect(issued[:status]).to eq(:issued)
      first ||= issued[:token]
      expect(described_class.reconcile(identity, issued[:token], impression_id: impression,
        acknowledged_at: Time.now.to_f - 1)).to eq(status: :reconciled)
    end
    expect(described_class.lookup(identity, first)[:status]).to eq(:valid)
    expect(described_class.reconcile(identity, first, impression_id: impression,
      acknowledged_at: Time.now.to_f - 1)).to eq(status: :reconciled)
    expect(RedisService.with_redis { |r| r.zcard(described_class.send(:pending_key, identity)) }).to eq(0)
  end

  it 'bounds retained receipts without evicting unexpired retry credentials' do
    first = nil
    described_class::TOTAL_LIMIT.times do |i|
      issued = described_class.issue(identity, "/receipt-#{i}.jpg", impression_id: impression)
      expect(issued[:status]).to eq(:issued)
      first ||= issued[:token]
      expect(described_class.reconcile(identity, issued[:token], impression_id: impression,
        acknowledged_at: Time.now.to_f - 1)).to eq(status: :reconciled)
    end
    expect(described_class.issue(identity, '/overflow.jpg', impression_id: impression)).to eq(status: :receipt_limit_reached)
    expect(described_class.lookup(identity, first)[:status]).to eq(:valid)
    RedisService.with_redis do |r|
      expiry, metadata = described_class.send(:keys, identity)
      expect(r.hlen(metadata)).to eq(described_class::TOTAL_LIMIT)
      r.zadd(expiry, 0, Digest::SHA256.hexdigest(first))
    end
    expect(described_class.issue(identity, '/replacement.jpg', impression_id: impression)[:status]).to eq(:issued)
    expect(described_class.lookup(identity, first)).to eq(status: :invalid)
  end

  it 'keeps pending capacity occupied when reconciliation fails' do
    tokens = described_class::LIMIT.times.map do |i|
      described_class.issue(identity, "/pending-#{i}.jpg", impression_id: impression).fetch(:token)
    end
    expect(described_class.reconcile(identity, tokens.first, impression_id: SecureRandom.hex(32),
      acknowledged_at: Time.now.to_f - 1)).to eq(status: :invalid)
    expect(described_class.issue(identity, '/blocked.jpg', impression_id: impression)).to eq(status: :limit_reached)
    expect(described_class.reconcile(identity, tokens.first, impression_id: impression,
      acknowledged_at: Time.now.to_f - 1)).to eq(status: :reconciled)
    expect(described_class.issue(identity, '/admitted.jpg', impression_id: impression)[:status]).to eq(:issued)
    expect(described_class.lookup(identity, tokens.first)[:status]).to eq(:valid)
  end

  it 'admits only one credential at the last total-cap slot across independent connections' do
    retained = nil
    (described_class::TOTAL_LIMIT - 1).times do |i|
      token = described_class.issue(identity, "/race-receipt-#{i}.jpg", impression_id: impression).fetch(:token)
      retained ||= token
      expect(described_class.reconcile(identity, token, impression_id: impression,
        acknowledged_at: Time.now.to_f - 1)).to eq(status: :reconciled)
    end
    keys = [*described_class.send(:keys, identity), described_class.send(:pending_key, identity)]
    arguments = 2.times.map do |i|
      [Digest::SHA256.hexdigest(SecureRandom.hex(32)),
       JSON.generate('content' => "/racing-#{i}.jpg", 'impression_id' => impression,
         'context' => { 'title' => nil, 'subreddit' => nil, 'user_id' => nil }),
       described_class::TTL, described_class::LIMIT, described_class::TOTAL_LIMIT]
    end
    expect(race_redis(described_class::ISSUE, keys: keys, arguments: arguments).sort).to eq([1, 4])
    RedisService.with_redis do |r|
      expect(r.zcard(keys[0])).to eq(described_class::TOTAL_LIMIT)
      expect(r.hlen(keys[1])).to eq(described_class::TOTAL_LIMIT)
      expect(r.zcard(keys[2])).to eq(1)
    end
    expect(described_class.lookup(identity, retained)[:status]).to eq(:valid)
  end

  it 'frees exactly one pending slot when duplicate reconciliations race' do
    tokens = described_class::LIMIT.times.map do |i|
      described_class.issue(identity, "/duplicate-#{i}.jpg", impression_id: impression).fetch(:token)
    end
    digest = Digest::SHA256.hexdigest(identity)
    prefix = "feed:reservations:v1:{#{digest}}"
    keys = [*described_class.send(:keys, identity), history_key,
      "#{prefix}:expiry", "#{prefix}:owners", described_class.send(:pending_key, identity)]
    timestamp = Time.now.to_f - 1
    args = [Digest::SHA256.hexdigest(tokens.first), impression, '/duplicate-0.jpg', timestamp, '',
      MemeExplorer::ViewingHistoryService::HISTORY_TTL, MemeExplorer::ViewingHistoryService::MAX_HISTORY_SIZE,
      Digest::SHA256.hexdigest('/duplicate-0.jpg')]
    deadline = RedisService.with_redis { |r| r.zscore(keys.first, args.first) }
    expect(race_redis(described_class::RECONCILE, keys: keys, arguments: [args, args])).to eq([1, 1])
    RedisService.with_redis do |r|
      expect(r.zcard(keys.last)).to eq(described_class::LIMIT - 1)
      expect(r.zscore(keys.first, args.first)).to eq(deadline)
      expect(r.zscore(history_key, '/duplicate-0.jpg')).to eq(timestamp)
    end
    expect(described_class.issue(identity, '/one-slot.jpg', impression_id: impression)[:status]).to eq(:issued)
    expect(described_class.issue(identity, '/no-second-slot.jpg', impression_id: impression)).to eq(status: :limit_reached)
  end

  it 'releases only the owned active lease and preserves a successor lease' do
    lease = MemeExplorer::FeedReservationService.acquire(identity, '/fixture.jpg')
    token = described_class.issue(identity, '/fixture.jpg', impression_id: impression, reservation_token: lease[:token])[:token]
    args = { impression_id: impression, acknowledged_at: Time.now.to_f - 1, reservation_token: lease[:token] }
    expect(described_class.reconcile(identity, token, **args)).to eq(status: :reconciled)
    successor = MemeExplorer::FeedReservationService.acquire(identity, '/fixture.jpg')
    expect(described_class.reconcile(identity, token, **args)).to eq(status: :reconciled)
    expect(MemeExplorer::FeedReservationService.validate(identity, '/fixture.jpg', successor[:token])).to eq(status: :active)
  end

  it 'does not overwrite newer history with a late older acknowledgement' do
    RedisService.with_redis { |r| r.zadd(history_key, Time.now.to_f, '/fixture.jpg') }
    token = described_class.issue(identity, '/fixture.jpg', impression_id: impression)[:token]
    score = RedisService.with_redis { |r| r.zscore(history_key, '/fixture.jpg') }
    expect(described_class.reconcile(identity, token, impression_id: impression, acknowledged_at: score - 10)).to eq(status: :reconciled)
    expect(RedisService.with_redis { |r| r.zscore(history_key, '/fixture.jpg') }).to eq(score)
  end

  it 'rejects invalid or future reconciliation timestamps and mismatched impressions' do
    token = described_class.issue(identity, '/fixture.jpg', impression_id: impression)[:token]
    [nil, Float::INFINITY, Time.now.to_f + 1000, 1].each do |timestamp|
      expect(described_class.reconcile(identity, token, impression_id: impression, acknowledged_at: timestamp)).to eq(status: :invalid)
    end
    expect(described_class.reconcile(identity, token, impression_id: SecureRandom.hex(32), acknowledged_at: Time.now.to_f - 1)).to eq(status: :invalid)
    expect(RedisService.with_redis { |r| r.zcard(history_key) }).to eq(0)
  end

  it 'repairs history after Redis failure using the same original acknowledgement time' do
    token = described_class.issue(identity, '/fixture.jpg', impression_id: impression)[:token]
    timestamp = Time.now.to_f - 1
    allow(RedisService).to receive(:with_redis).and_return(nil)
    expect(described_class.reconcile(identity, token, impression_id: impression, acknowledged_at: timestamp)).to eq(status: :unavailable)
    allow(RedisService).to receive(:with_redis).and_call_original
    expect(described_class.reconcile(identity, token, impression_id: impression, acknowledged_at: timestamp)).to eq(status: :reconciled)
  end

  it 'preserves the credential deadline and bounds history expiry to recorded time' do
    token = described_class.issue(identity, '/fixture.jpg', impression_id: impression)[:token]
    expiry = described_class.send(:keys, identity).first
    digest = Digest::SHA256.hexdigest(token)
    deadline = RedisService.with_redis { |r| r.zscore(expiry, digest) }
    timestamp = Time.now.to_f - 300
    expect(described_class.reconcile(identity, token, impression_id: impression, acknowledged_at: timestamp)).to eq(status: :reconciled)
    RedisService.with_redis do |r|
      expect(r.zscore(expiry, digest)).to eq(deadline)
      remaining = MemeExplorer::ViewingHistoryService::HISTORY_TTL - 300
      expect(r.ttl(history_key)).to be_between(remaining - 2, remaining + 1)
    end
  end

  it 'cannot write history using an expired acknowledgement credential' do
    token = described_class.issue(identity, '/fixture.jpg', impression_id: impression)[:token]
    RedisService.with_redis do |r|
      r.zadd(described_class.send(:keys, identity).first, 0, Digest::SHA256.hexdigest(token))
    end
    expect(described_class.reconcile(identity, token, impression_id: impression, acknowledged_at: Time.now.to_f - 1)).to eq(status: :invalid)
    expect(RedisService.with_redis { |r| r.exists?(history_key) }).to eq(false)
  end

  it 'binds metadata to session and token without renewing expiry on lookup' do
    token = described_class.issue(identity, '/fixture.jpg', impression_id: impression)[:token]
    keys = described_class.send(:keys, identity)
    before = RedisService.with_redis { |r| r.zscore(keys.first, Digest::SHA256.hexdigest(token)) }
    expect(described_class.lookup(identity, token)).to include(status: :valid, content: '/fixture.jpg', impression_id: impression)
    expect(described_class.lookup(SecureRandom.hex(32), token)).to eq(status: :invalid)
    expect(described_class.lookup(identity, SecureRandom.hex(32))).to eq(status: :invalid)
    expect(RedisService.with_redis { |r| r.zscore(keys.first, Digest::SHA256.hexdigest(token)) }).to eq(before)
  end

  it 'bounds issuance, prunes expired metadata and rejects expired credentials' do
    tokens = described_class::LIMIT.times.map { |i| described_class.issue(identity, "/#{i}.jpg", impression_id: impression)[:token] }
    expect(described_class.issue(identity, '/extra.jpg', impression_id: impression)).to eq(status: :limit_reached)
    expiry, metadata = described_class.send(:keys, identity)
    RedisService.with_redis { |r| r.zadd(expiry, 0, Digest::SHA256.hexdigest(tokens.first)) }
    expect(described_class.lookup(identity, tokens.first)).to eq(status: :invalid)
    expect(described_class.issue(identity, '/replacement.jpg', impression_id: impression)[:status]).to eq(:issued)
    RedisService.with_redis do |r|
      expect(r.hlen(metadata)).to eq(described_class::LIMIT)
      [expiry, metadata].each { |key| expect(r.ttl(key)).to be_between(1, described_class::TTL) }
    end
  end

  it 'rejects malformed input and distinguishes infrastructure failure' do
    expect(described_class.issue('bad', '/a', impression_id: impression)).to eq(status: :invalid)
    expect(described_class.issue(identity, 'x' * 4097, impression_id: impression)).to eq(status: :invalid)
    expect(described_class.lookup(identity, 'bad')).to eq(status: :invalid)
    allow(RedisService).to receive(:with_redis).and_return(nil)
    expect(described_class.issue(identity, '/a', impression_id: impression)).to eq(status: :unavailable)
    expect(described_class.lookup(identity, SecureRandom.hex(32))).to eq(status: :unavailable)
  end

  it 'keeps issued credentials separate from viewed history and active leases' do
    token = described_class.issue(identity, '/fixture.jpg', impression_id: impression)[:token]
    expect(described_class.lookup(identity, token)[:status]).to eq(:valid)
    expect(MemeExplorer::ViewingHistoryService.get_seen_memes(identity)).to eq([])
  end

  it 'requires a valid impression binding and rejects a mismatched expected impression' do
    expect(described_class.issue(identity, '/fixture.jpg', impression_id: 'invalid')).to eq(status: :invalid)
    token = described_class.issue(identity, '/fixture.jpg', impression_id: impression)[:token]
    expect(described_class.lookup(identity, token, impression_id: impression)).to include(status: :valid, impression_id: impression)
    expect(described_class.lookup(identity, token, impression_id: SecureRandom.hex(32))).to eq(status: :invalid)
    expect(described_class.lookup(identity, token, impression_id: 'invalid')).to eq(status: :invalid)
  end

  it 'does not trust stored metadata without a valid server-issued impression identifier' do
    token = described_class.issue(identity, '/fixture.jpg', impression_id: impression)[:token]
    metadata = described_class.send(:keys, identity).last
    [nil, 'invalid', 42].each do |invalid|
      payload = JSON.generate('content' => '/fixture.jpg', 'impression_id' => invalid)
      RedisService.with_redis { |r| r.hset(metadata, Digest::SHA256.hexdigest(token), payload) }
      expect(described_class.lookup(identity, token)).to eq(status: :unavailable)
    end
  end

  it 'rejects corrupt or oversized stored metadata without returning content' do
    token = described_class.issue(identity, '/fixture.jpg', impression_id: impression)[:token]
    metadata = described_class.send(:keys, identity).last
    ['{broken', '[]', '{"content":42}', '{"content":" "}', JSON.generate('content' => 'x' * 4097), 'x' * 32_769].each do |payload|
      RedisService.with_redis { |r| r.hset(metadata, Digest::SHA256.hexdigest(token), payload) }
      expect(described_class.lookup(identity, token)).to eq(status: :unavailable)
    end
  end

  it 'enforces the last capacity slot across independent concurrent connections' do
    (described_class::LIMIT - 1).times { |i| described_class.issue(identity, "/#{i}.jpg", impression_id: impression) }
    connections = 2.times.map { Redis.new(url: ENV.fetch('REDIS_URL')) }
    ready = Queue.new
    start = Queue.new
    threads = connections.map do |redis|
      Thread.new do
        ready << true
        start.pop
        redis.eval(described_class::ISSUE, keys: [*described_class.send(:keys, identity), described_class.send(:pending_key, identity)],
          argv: [Digest::SHA256.hexdigest(SecureRandom.hex(32)), JSON.generate('content' => '/concurrent.jpg', 'impression_id' => impression), described_class::TTL, described_class::LIMIT, described_class::TOTAL_LIMIT])
      end
    end
    2.times { ready.pop }
    2.times { start << true }
    expect(threads.map(&:value).sort).to eq([1, 2])
    RedisService.with_redis do |r|
      expiry, metadata = described_class.send(:keys, identity)
      expect(r.zcard(expiry)).to eq(described_class::LIMIT)
      expect(r.hlen(metadata)).to eq(described_class::LIMIT)
    end
  ensure
    connections&.each(&:close)
  end
end