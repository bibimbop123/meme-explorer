require_relative '../spec_helper'
require_relative '../../lib/services/feed_acknowledgement_service'
require_relative '../../lib/services/feed_reservation_service'
require 'timeout'

RSpec.describe MemeExplorer::FeedAcknowledgementService do
  let(:identity) { SecureRandom.hex(32) }
  let(:impression) { SecureRandom.hex(32) }
  let(:content) { '/coordinator.jpg' }
  let(:store) { MemeExplorer::FeedAcknowledgementStore }
  let(:issuing_user_id) { nil }
  let(:issued_reservation_token) { nil }
  let(:token) { store.issue(identity, content, impression_id: impression, title: 'Issued title', subreddit: 'issued', user_id: issuing_user_id, reservation_token: issued_reservation_token).fetch(:token) }
  let(:history) { "feed:acknowledged:v1:{#{Digest::SHA256.hexdigest(identity)}}:history" }

  def acknowledge(**options)
    described_class.acknowledge(identity, token, impression_id: impression, **options)
  end

  after do
    RedisService.with_redis do |r|
      r.del(history, *store.send(:keys, identity), store.send(:pending_key, identity), *MemeExplorer::FeedReservationService.send(:keys, identity))
    end
  end

  it 'records counters once and repairs history on duplicate DB acknowledgements' do
    user_id = create_test_user('ack-coordinator@example.com').to_i
    allow(self).to receive(:issuing_user_id).and_return(user_id)
    allow(store).to receive(:reconcile).and_return(status: :unavailable)
    expect(acknowledge(current_user_id: user_id)).to eq(status: :unavailable, stage: :history, recorded: true)
    expect(RedisService.with_redis { |r| r.zcard(history) }).to eq(0)
    timestamp = DB.get_first_value('SELECT EXTRACT(EPOCH FROM created_at) FROM meme_impressions WHERE id = ?', [impression]).to_f
    allow(store).to receive(:reconcile).and_call_original
    2.times { expect(acknowledge(current_user_id: user_id)).to eq(status: :acknowledged, recorded: false) }
    expect(RedisService.with_redis { |r| r.zscore(history, content) }).to eq(timestamp)
    expect(DB.get_first_value('SELECT views FROM meme_stats WHERE url = ?', [content]).to_i).to eq(1)
    expect(DB.get_first_value('SELECT SUM(shown_count) FROM user_meme_exposure').to_i).to eq(1)
    expect(DB.get_first_value("SELECT COUNT(*) FROM meme_activity_log WHERE activity_type = 'view'").to_i).to eq(1)
  end

  it 'restores lost history from a completed credential without renewing its deadline or counters' do
    user = create_test_user('ack-history-loss@example.com').to_i
    allow(self).to receive(:issuing_user_id).and_return(user)
    expect(acknowledge(current_user_id: user)).to eq(status: :acknowledged, recorded: true)
    expiry = store.send(:keys, identity).first
    digest = Digest::SHA256.hexdigest(token)
    deadline = RedisService.with_redis { |r| r.zscore(expiry, digest) }
    timestamp = DB.get_first_value('SELECT EXTRACT(EPOCH FROM created_at) FROM meme_impressions WHERE id = ?', [impression]).to_f
    RedisService.with_redis { |r| r.del(history) }
    expect(store.history(identity)).to eq(status: :available, entries: [])
    expect(acknowledge(current_user_id: user)).to eq(status: :acknowledged, recorded: false)
    expect(store.history(identity)).to eq(status: :available, entries: [{ content: content, acknowledged_at: timestamp }])
    RedisService.with_redis do |r|
      expect(r.zscore(expiry, digest)).to eq(deadline)
      expect(r.zcard(store.send(:pending_key, identity))).to eq(0)
    end
    expect(DB.get_first_value('SELECT views FROM meme_stats WHERE url = ?', [content]).to_i).to eq(1)
    expect(DB.get_first_value('SELECT SUM(shown_count) FROM user_meme_exposure').to_i).to eq(1)
    expect(DB.get_first_value("SELECT COUNT(*) FROM meme_activity_log WHERE activity_type = 'view'").to_i).to eq(1)
  end

  it 'cannot reconstruct history from the DB alone after the acknowledgement credential is lost' do
    expect(acknowledge).to eq(status: :acknowledged, recorded: true)
    RedisService.with_redis { |r| r.del(history, *store.send(:keys, identity)) }
    expect(acknowledge).to eq(status: :invalid)
    expect(store.history(identity)).to eq(status: :available, entries: [])
    expect(DB.get_first_value('SELECT views FROM meme_stats WHERE url = ?', [content]).to_i).to eq(1)
  end

  it 'rolls back DB insertion and counters on a database failure without touching history or lease' do
    lease = MemeExplorer::FeedReservationService.acquire(identity, content)
    allow(self).to receive(:issued_reservation_token).and_return(lease[:token])
    allow(DB).to receive(:execute).and_call_original
    allow(DB).to receive(:execute).with(a_string_including('INSERT INTO meme_activity_log'), anything).and_raise(StandardError)
    expect(acknowledge(reservation_token: lease[:token])).to eq(status: :unavailable, stage: :database)
    expect(DB.get_first_value('SELECT COUNT(*) FROM meme_impressions').to_i).to eq(0)
    expect(DB.get_first_value('SELECT COUNT(*) FROM meme_stats').to_i).to eq(0)
    expect(RedisService.with_redis { |r| r.zcard(history) }).to eq(0)
    expect(MemeExplorer::FeedReservationService.validate(identity, content, lease[:token])).to eq(status: :active)
  end

  it 'rejects unusable persisted timestamps without counters or history and repairs after correction' do
    [nil, 'infinity', '-infinity', '1970-01-01 00:00:00+00',
     '2100-01-01 00:00:00+00', '2000-01-01 00:00:00+00'].each do |timestamp|
      DB.execute('DELETE FROM meme_impressions')
      DB.execute('INSERT INTO meme_impressions (id, meme_url, session_key, created_at) VALUES (?, ?, ?, ?)',
        [impression, content, identity, timestamp])
      expect(acknowledge).to eq(status: :unavailable, stage: :database)
      expect(DB.get_first_value('SELECT COUNT(*) FROM meme_stats').to_i).to eq(0)
      expect(RedisService.with_redis { |r| r.zcard(history) }).to eq(0)
    end
    DB.execute('UPDATE meme_impressions SET created_at = CURRENT_TIMESTAMP WHERE id = ?', [impression])
    expect(acknowledge).to eq(status: :acknowledged, recorded: false)
    expect(RedisService.with_redis { |r| r.zcard(history) }).to eq(1)
  end

  it 'rejects a conflicting DB session or content binding without history repair' do
    ['other-session', identity].each do |session_id|
      DB.execute('DELETE FROM meme_impressions')
      DB.execute('INSERT INTO meme_impressions (id, meme_url, session_key) VALUES (?, ?, ?)',
        [impression, session_id == identity ? '/other.jpg' : content, session_id])
      expect(acknowledge).to eq(status: :invalid)
      expect(RedisService.with_redis { |r| r.zcard(history) }).to eq(0)
    end
  end

  it 'fails closed before DB recording when credentials are unavailable or malformed' do
    token
    allow(store).to receive(:lookup).and_return(status: :unavailable)
    expect(acknowledge).to eq(status: :unavailable)
    expect(described_class.acknowledge(identity, token, impression_id: nil)).to eq(status: :invalid)
    expect(DB.get_first_value('SELECT COUNT(*) FROM meme_impressions').to_i).to eq(0)
  end

  it 'acknowledges after lease expiry without releasing a successor lease' do
    leases = MemeExplorer::FeedReservationService
    old = leases.acquire(identity, content)
    allow(self).to receive(:issued_reservation_token).and_return(old[:token])
    leases.release(identity, content, old[:token])
    successor = leases.acquire(identity, content)
    expect(acknowledge(reservation_token: old[:token])).to eq(status: :acknowledged, recorded: true)
    expect(leases.validate(identity, content, successor[:token])).to eq(status: :active)
  end

  it 'survives a lost successful response without changing history or counters' do
    expect(acknowledge).to eq(status: :acknowledged, recorded: true)
    original = RedisService.with_redis { |r| r.zscore(history, content) }
    expect(acknowledge).to eq(status: :acknowledged, recorded: false)
    expect(RedisService.with_redis { |r| r.zscore(history, content) }).to eq(original)
    expect(DB.get_first_value('SELECT views FROM meme_stats WHERE url = ?', [content]).to_i).to eq(1)
  end

  it 'reports the committed DB result if the credential expires between stages' do
    allow(store).to receive(:reconcile).and_wrap_original do |original, *args, **kwargs|
      RedisService.with_redis do |r|
        r.zadd(store.send(:keys, identity).first, 0, Digest::SHA256.hexdigest(token))
      end
      original.call(*args, **kwargs)
    end
    expect(acknowledge).to eq(status: :invalid, stage: :history, recorded: true)
    expect(DB.get_first_value('SELECT COUNT(*) FROM meme_impressions').to_i).to eq(1)
    expect(RedisService.with_redis { |r| r.zcard(history) }).to eq(0)
  end

  it 'refuses to reconcile inside an uncommitted outer transaction' do
    DB.transaction do
      expect(acknowledge).to eq(status: :unavailable, stage: :database)
    end
    expect(DB.get_first_value('SELECT COUNT(*) FROM meme_impressions').to_i).to eq(0)
  end

  it 'uses issued metadata and does not attribute an old credential to a different user' do
    issuer = create_test_user('ack-issuer@example.com').to_i
    other = create_test_user('ack-other@example.com').to_i
    allow(self).to receive(:issuing_user_id).and_return(issuer)
    expect(acknowledge(current_user_id: other)).to eq(status: :acknowledged, recorded: true)
    row = DB.execute('SELECT title, subreddit FROM meme_stats WHERE url = ?', [content]).first
    expect(row).to include('title' => 'Issued title', 'subreddit' => 'issued')
    expect(DB.get_first_value('SELECT COUNT(*) FROM user_meme_exposure').to_i).to eq(0)
    expect(DB.get_first_value('SELECT user_id FROM meme_activity_log WHERE meme_url = ?', [content])).to be_nil
  end

  it 'does not retroactively attribute anonymous issuance after login' do
    user = create_test_user('ack-login@example.com').to_i
    expect(acknowledge(current_user_id: user)).to eq(status: :acknowledged, recorded: true)
    expect(DB.get_first_value('SELECT COUNT(*) FROM user_meme_exposure').to_i).to eq(0)
  end

  it 'rejects malformed recorded timestamp metadata before database writes' do
    credential = token
    metadata = store.send(:keys, identity).last
    digest = Digest::SHA256.hexdigest(credential)
    original = RedisService.with_redis { |r| JSON.parse(r.hget(metadata, digest)) }
    [nil, false, [], {}, 42, 'NaN', 'Infinity', '-1', '0', 'x' * 33].each do |timestamp|
      RedisService.with_redis do |r|
        r.hset(metadata, digest, JSON.generate(original.merge('acknowledged_at' => timestamp)))
      end
      expect(acknowledge).to eq(status: :unavailable)
      expect(DB.get_first_value('SELECT COUNT(*) FROM meme_impressions').to_i).to eq(0)
    end
    RedisService.with_redis { |r| r.hset(metadata, digest, JSON.generate(original)) }
    expect(acknowledge).to eq(status: :acknowledged, recorded: true)
    expect(acknowledge).to eq(status: :acknowledged, recorded: false)
  end

  it 'rejects substitution of a successor lease before database recording' do
    leases = MemeExplorer::FeedReservationService
    original = leases.acquire(identity, content)
    allow(self).to receive(:issued_reservation_token).and_return(original[:token])
    token
    leases.release(identity, content, original[:token])
    successor = leases.acquire(identity, content)
    expect(acknowledge(reservation_token: successor[:token])).to eq(status: :invalid)
    expect(DB.get_first_value('SELECT COUNT(*) FROM meme_impressions').to_i).to eq(0)
    expect(acknowledge).to eq(status: :acknowledged, recorded: true)
    expect(leases.validate(identity, content, successor[:token])).to eq(status: :active)
  end

  it 'releases its issuance-bound lease without trusting an ACK-supplied token' do
    leases = MemeExplorer::FeedReservationService
    lease = leases.acquire(identity, content)
    allow(self).to receive(:issued_reservation_token).and_return(lease[:token])
    expect(acknowledge).to eq(status: :acknowledged, recorded: true)
    expect(leases.validate(identity, content, lease[:token])).to eq(status: :invalid)
  end

  it 'records concurrent duplicate acknowledgements once on independent PostgreSQL connections' do
    user = create_test_user('ack-concurrent@example.com').to_i
    allow(self).to receive(:issuing_user_id).and_return(user)
    session_id, credential, id = identity, token, impression
    ready, start = Queue.new, Queue.new
    allow(DB).to receive(:execute).and_wrap_original do |original, sql, *args|
      if sql.start_with?('INSERT INTO meme_impressions')
        ready << DB.get_first_value('SELECT pg_backend_pid()')
        start.pop
      end
      original.call(sql, *args)
    end
    threads = 2.times.map do
      Thread.new do
        described_class.acknowledge(session_id, credential, impression_id: id, current_user_id: user)
      end
    end
    connections = Timeout.timeout(10) { 2.times.map { ready.pop } }
    expect(connections.uniq.size).to eq(2)
    2.times { start << true }
    results = threads.map(&:value)
    expect(results).to contain_exactly({ status: :acknowledged, recorded: true },
      { status: :acknowledged, recorded: false })
    expect(DB.get_first_value('SELECT COUNT(*) FROM meme_impressions').to_i).to eq(1)
    expect(DB.get_first_value('SELECT views FROM meme_stats WHERE url = ?', [content]).to_i).to eq(1)
    expect(DB.get_first_value('SELECT SUM(shown_count) FROM user_meme_exposure').to_i).to eq(1)
    expect(DB.get_first_value("SELECT COUNT(*) FROM meme_activity_log WHERE activity_type = 'view'").to_i).to eq(1)
    timestamp = DB.get_first_value('SELECT EXTRACT(EPOCH FROM created_at) FROM meme_impressions WHERE id = ?', [id]).to_f
    RedisService.with_redis do |r|
      expect(r.zscore(history, content)).to eq(timestamp)
      expect(r.zcard(store.send(:pending_key, session_id))).to eq(0)
    end
  ensure
    2.times { start << true } if start
    threads&.each(&:join)
  end
end