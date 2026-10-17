require_relative '../spec_helper'
require 'rack/session/redis'
require 'rack/mock'
require 'timeout'

RSpec.describe 'Legacy pending-impression session concurrency' do
  [false, true].product([[0, 1], [1, 0]], [0, 1]).each do |repair_enabled, completion_order, repetition|
  it "handles overlapping full feed ACKs with repair enabled=#{repair_enabled}, order=#{completion_order}, repetition=#{repetition}" do
    allow(FeatureFlags).to receive(:enabled?).and_call_original
    allow(FeatureFlags).to receive(:enabled?).with('feed.legacy_pending_store').and_return(repair_enabled)
    completed = Queue.new
    release = [Queue.new, Queue.new]
    fixture = { 'url' => '/images/funny1.jpeg', 'title' => 'Race fixture', 'subreddit' => 'local' }
    allow(MemePoolManager).to receive(:get_pool).and_return(success: true, memes: [fixture], pool_size: 1)
    app = lambda do |env|
      if env['PATH_INFO'] == '/race-seed'
        state = env.fetch('rack.session')
        state['csrf'] = 'race-csrf'
        state[:feed_session_id] = SecureRandom.hex(32)
        state[:impression_session_key] = SecureRandom.hex(32)
        state[:pending_impressions] = {}
        next [200, { 'content-type' => 'text/plain' }, ['seeded']]
      end
      response = MemeExplorer::App.call(env)
      if env['PATH_INFO'] == '/random.json'
        # Hold both finished route responses before session middleware saves
        # either snapshot. This forces a valid overlapping-request schedule.
        completed << true
        Timeout.timeout(10) { release.fetch(env.fetch('race.worker')).pop }
      end
      response
    end
    middleware = Rack::Session::Redis.new(app,
      key: 'route-race.session',
      redis_server: { url: ENV.fetch('REDIS_URL'), namespace: "route-race-#{SecureRandom.hex(12)}" },
      secret: 'local-route-race-test-' * 4, expire_after: 60)
    client = Rack::MockRequest.new(middleware)
    cookie = client.get('/race-seed')['set-cookie'].split(';').first
    workers = []
    begin
      workers = 2.times.map do |index|
        Thread.new { Rack::MockRequest.new(middleware).get('/random.json', 'HTTP_COOKIE' => cookie, 'race.worker' => index) }
      end
      Timeout.timeout(10) { 2.times { completed.pop } }
      completion_order.each do |index|
        release.fetch(index) << true
        # Joining includes the middleware's Redis session save, so the next
        # released response deterministically writes its snapshot last.
        expect(workers.fetch(index).join(10)).not_to be_nil
      end
      selected = workers.map(&:value).map do |response|
        expect(response.status).to eq(200)
        JSON.parse(response.body)
      end
      expect(selected.map { |item| item.fetch('impression_id') }.uniq.size).to eq(2)
      foreign_cookie = client.get('/race-seed')['set-cookie'].split(';').first
      foreign_ack = client.post('/api/impressions', 'HTTP_COOKIE' => foreign_cookie,
        'HTTP_X_CSRF_TOKEN' => 'race-csrf', 'CONTENT_TYPE' => 'application/json',
        input: JSON.generate(impression_id: selected.first.fetch('impression_id')))
      expect(foreign_ack.status).to eq(404)
      expect(DB.get_first_value('SELECT COUNT(*) FROM meme_impressions').to_i).to eq(0)
      # Lookup compatibility must survive disabling issuance after rollout.
      allow(FeatureFlags).to receive(:enabled?).with('feed.legacy_pending_store').and_return(false)
      acknowledgments = selected.map do |item|
        client.post('/api/impressions', 'HTTP_COOKIE' => cookie,
          'HTTP_X_CSRF_TOKEN' => 'race-csrf', 'CONTENT_TYPE' => 'application/json',
          input: JSON.generate(impression_id: item.fetch('impression_id')))
      end
      # Current bug: both were issued legitimately, but only the surviving map
      # entry authorizes an ACK. Never compensate with client content fallback.
      expect(acknowledgments.map(&:status).sort).to eq(repair_enabled ? [200, 200] : [200, 404])
      selected.zip(acknowledgments).each do |item, response|
        next unless response.status == 200

        expect(JSON.parse(response.body)).to include('success' => true, 'recorded' => true)
        retry_ack = client.post('/api/impressions', 'HTTP_COOKIE' => cookie,
          'HTTP_X_CSRF_TOKEN' => 'race-csrf', 'CONTENT_TYPE' => 'application/json',
          input: JSON.generate(impression_id: item.fetch('impression_id')))
        expect(retry_ack.status).to eq(200)
        expect(JSON.parse(retry_ack.body)).to include('success' => true, 'recorded' => false)
      end
      expect(DB.get_first_value('SELECT COUNT(*) FROM meme_impressions').to_i).to eq(repair_enabled ? 2 : 1)
      expect(DB.get_first_value('SELECT COALESCE(SUM(views), 0) FROM meme_stats').to_i).to eq(repair_enabled ? 2 : 1)
    ensure
      release.each { |queue| queue << true }
      workers.each { |worker| worker.join(12) }
      workers.each { |worker| worker.kill if worker.alive? }
    end
  end
  end

  it 'reproduces a lost pending addition with real overlapping Redis session requests' do
    loaded = Queue.new
    release = Queue.new
    ids = %w[a b].map { |letter| letter * 64 }
    endpoint = lambda do |env|
      request = Rack::Request.new(env)
      session = env.fetch('rack.session')
      case request.path
      when '/seed'
        session[:impression_session_key] = 'race-test-owner'
        session[:pending_impressions] = {}
      when '/select'
        # Same read/copy/write shape as issue_impression. Both requests load
        # their session snapshot before either may finish and persist it.
        pending = (session[:pending_impressions] || {}).reject { |_, item| item['expires_at'] < Time.now.to_i }
        loaded << true
        Timeout.timeout(5) { release.pop }
        pending[request.params.fetch('id')] = { 'url' => '/fixture.jpg', 'expires_at' => Time.now.to_i + 1800 }
        session[:pending_impressions] = pending
      end
      [200, { 'content-type' => 'application/json' }, [JSON.generate(session[:pending_impressions])]]
    end
    middleware = Rack::Session::Redis.new(endpoint,
      key: 'race.session',
      redis_server: { url: ENV.fetch('REDIS_URL'), namespace: "race-test-#{SecureRandom.hex(12)}" },
      secret: 'local-session-race-test-' * 4, expire_after: 60)
    cookie = Rack::MockRequest.new(middleware).get('/seed')['set-cookie'].split(';').first
    workers = []
    begin
      workers = ids.map do |id|
        Thread.new do
          Rack::MockRequest.new(middleware).get("/select?id=#{id}", 'HTTP_COOKIE' => cookie)
        end
      end
      Timeout.timeout(5) { 2.times { loaded.pop } }
      2.times { release << true }
      responses = workers.map(&:value)
      expect(responses.map(&:status)).to eq([200, 200])
      expect(responses.map { |response| JSON.parse(response.body).keys.first }).to match_array(ids)
      stored = JSON.parse(Rack::MockRequest.new(middleware).get('/state', 'HTTP_COOKIE' => cookie).body)
      # Diagnostic reproduction: last whole-session write wins. This assertion
      # documents today's bug, not the desired future two-entry behavior.
      expect(stored.keys.size).to eq(1)
      expect(ids).to include(stored.keys.first)
    ensure
      2.times { release << true }
      workers.each { |worker| worker.join(6) }
      workers.each { |worker| worker.kill if worker.alive? }
      # Unique test namespace and 60s TTL avoid touching other sessions.
    end
  end
end