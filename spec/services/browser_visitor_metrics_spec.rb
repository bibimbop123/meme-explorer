require_relative '../spec_helper'

RSpec.describe BrowserVisitorMetrics do
  before do
    DB_POOL.with { |connection| connection.exec(File.read(File.expand_path('../../db/migrations/add_browser_visitors.sql', __dir__))) }
    DB_POOL.with { |connection| connection.exec(File.read(File.expand_path('../../db/migrations/add_browser_visitor_revocation.sql', __dir__))) }
    DB.execute('DELETE FROM browser_visitors')
    DB.execute('DELETE FROM browser_visitor_collection')
    allow(ENV).to receive(:[]).and_call_original
    allow(ENV).to receive(:[]).with('ENABLE_VISITOR_METRICS').and_return('true')
  end

  it 'deduplicates browser observations and reports rolling windows with partial coverage' do
    now = Time.utc(2026, 10, 21, 12)
    described_class.record('a' * 64, now: now - 20 * 86_400)
    described_class.record('a' * 64, now: now)
    described_class.record('b' * 64, now: now - 2 * 86_400)
    described_class.record('c' * 64, now: now - 10 * 86_400)
    described_class.record('d' * 64, now: now + 3600)
    snapshot = described_class.snapshot(now: now)
    expect(snapshot).to include(available: true, counts: { '24h' => 1, '7d' => 2, '30d' => 3 }, partial_windows: ['30d'])
    expect(DB.get_first_value('SELECT COUNT(*) FROM browser_visitors').to_i).to eq(4)
    expect(DB.get_first_value('SELECT visitor_key FROM browser_visitors LIMIT 1')).not_to eq('a' * 64)
  end

  it 'does not invent zero counts on query failure and rejects malformed identities' do
    expect { described_class.record('bad') }.to raise_error(ArgumentError)
    allow(DB).to receive(:execute).and_raise(PG::Error)
    expect(described_class.snapshot).to eq(available: false, status: 'unavailable')
  end

  it 'discloses visitor cookie, hashed key, withdrawal suppression and privacy signals on the privacy page' do
    get '/privacy'
    expect(last_response.status).to eq(200)
    expect(last_response.body).to include('Optional first-party visitor measurement', 'meme_visitor',
      'SHA-256', 'Global Privacy Control', 'suppression marker')
  end

  it 'includes exact window edges and excludes just-older, future and revoked observations' do
    now = Time.utc(2026, 10, 21, 12)
    ages = [2_592_001, 2_592_000, 604_801, 604_800, 86_401, 86_400, 0, -1]
    ages.each_with_index do |age, index|
      described_class.record(format('%064x', index + 1), now: now - age)
    end
    revoked = 'f' * 64
    described_class.record(revoked, now: now)
    described_class.withdraw(revoked, now: now)
    result = described_class.snapshot(now: now)
    expect(result[:counts]).to eq('24h' => 2, '7d' => 4, '30d' => 6)
    expect(result[:partial_windows]).to eq([])
    expect(result[:generated_at]).to eq(now.iso8601)
  end

  it 'calculates all windows and collection coverage in one database statement' do
    now = Time.utc(2026, 10, 21, 12)
    expect(DB).to receive(:execute).once.and_call_original
    expect(described_class.snapshot(now: now)).to include(available: true,
      counts: { '24h' => 0, '7d' => 0, '30d' => 0 }, partial_windows: %w[24h 7d 30d])
  end

  it 'requires explicit consent and respects privacy signals before setting a cookie' do
    expect(described_class).not_to receive(:record)
    post '/api/visitor-observation', consent: 'rejected'
    expect(last_response.status).to eq(400)
    header 'Sec-GPC', '1'
    post '/api/visitor-observation', consent: 'accepted'
    expect(last_response.status).to eq(204)
    expect(last_response.headers['set-cookie'].to_s).not_to include('meme_visitor=')
  end

  it 'keeps a browser identity across repeated observations without account linkage' do
    2.times do
      post '/api/visitor-observation', consent: 'accepted'
      expect(last_response.status).to eq(204)
    end
    expect(DB.get_first_value('SELECT COUNT(*) FROM browser_visitors').to_i).to eq(1)
    expect(last_response.headers['set-cookie'].to_s).to include('meme_visitor=')
  end

  it 'removes only the withdrawing browser from counts and supports repeated withdrawal' do
    described_class.record('f' * 64)
    post '/api/visitor-observation', consent: 'accepted'
    expect(DB.get_first_value('SELECT COUNT(*) FROM browser_visitors').to_i).to eq(2)
    2.times do
      post '/api/visitor-withdrawal'
      expect(last_response.status).to eq(204)
    end
    expect(DB.get_first_value('SELECT COUNT(*) FROM browser_visitors WHERE revoked_at IS NULL').to_i).to eq(1)
  end

  it 'rejects late observations for a withdrawn identity without extending suppression' do
    identity = 'e' * 64
    now = Time.utc(2026, 10, 21, 12)
    expect(described_class.record(identity, now: now)).to be true
    described_class.withdraw(identity, now: now + 1)
    expect(described_class.record(identity, now: now + 2)).to be false
    described_class.withdraw(identity, now: now + 3)
    row = DB.execute('SELECT * FROM browser_visitors WHERE visitor_key = ?', [Digest::SHA256.hexdigest(identity)]).first
    expect(row['last_seen_at']).to be_nil
    expect(Time.parse(row['revoked_at'])).to eq(now + 1)
    expect(described_class.snapshot(now: now + 4)[:counts].values).to eq([0, 0, 0])
  end

  it 'permits withdrawal when collection is disabled' do
    post '/api/visitor-observation', consent: 'accepted'
    expect(last_response.status).to eq(204)
    allow(ENV).to receive(:[]).with('ENABLE_VISITOR_METRICS').and_return('false')
    post '/api/visitor-withdrawal'
    expect(last_response.status).to eq(204)
    expect(DB.get_first_value('SELECT COUNT(*) FROM browser_visitors WHERE revoked_at IS NULL').to_i).to eq(0)
  end

  it 'retains revocation when established-identity observations race withdrawal' do
    identity = '8' * 64
    described_class.record(identity)
    ready = Queue.new
    release = Queue.new
    threads = 6.times.map do |index|
      Thread.new do
        ready << true
        release.pop
        index == 3 ? described_class.withdraw(identity) : described_class.record(identity)
      end
    end
    6.times { ready.pop }
    6.times { release << true }
    threads.each(&:value)
    row = DB.execute('SELECT last_seen_at, revoked_at FROM browser_visitors WHERE visitor_key = ?',
      [Digest::SHA256.hexdigest(identity)]).first
    expect(row['last_seen_at']).to be_nil
    expect(row['revoked_at']).not_to be_nil
    expect(described_class.record(identity)).to be false
    expect(described_class.snapshot[:counts].values).to eq([0, 0, 0])
  ensure
    threads&.each { |thread| thread.join(5) }
  end

  it 'rejects an old cookie after withdrawal without refreshing it or counting it again' do
    identity = '9' * 64
    rack_mock_session.cookie_jar['meme_visitor'] = identity
    post '/api/visitor-observation', consent: 'accepted'
    expect(last_response.status).to eq(204)
    post '/api/visitor-withdrawal'
    expect(last_response.status).to eq(204)
    # Model a request carrying the cookie captured before withdrawal completed.
    rack_mock_session.cookie_jar['meme_visitor'] = identity
    post '/api/visitor-observation', consent: 'accepted'
    expect(last_response.status).to eq(409)
    expect(last_response.headers['set-cookie'].to_s).not_to include('meme_visitor=')
    expect(described_class.snapshot[:counts].values).to eq([0, 0, 0])
    expect(DB.get_first_value('SELECT COUNT(*) FROM browser_visitors').to_i).to eq(1)
  end

  it 'reports failed deletion without expiring the cookie or claiming browser collection stopped' do
    post '/api/visitor-observation', consent: 'accepted'
    allow(DB).to receive(:execute).and_call_original
    allow(BrowserVisitorMetrics).to receive(:withdraw)
      .and_raise(PG::Error, 'private database detail')
    post '/api/visitor-withdrawal'
    expect(last_response.status).to eq(503)
    expect(last_response.body).to include('removal from visitor counts is not confirmed')
    expect(last_response.body).not_to include('private database detail', 'Collection is stopped')
    expect(last_response.headers['set-cookie'].to_s).not_to include('meme_visitor=')
    expect(DB.get_first_value('SELECT COUNT(*) FROM browser_visitors').to_i).to eq(1)
    allow(BrowserVisitorMetrics).to receive(:withdraw).and_call_original
    post '/api/visitor-withdrawal'
    expect(last_response.status).to eq(204)
    expect(DB.get_first_value('SELECT COUNT(*) FROM browser_visitors WHERE revoked_at IS NULL').to_i).to eq(0)
  end
end