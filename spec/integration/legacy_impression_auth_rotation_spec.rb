require_relative '../spec_helper'
require 'rack/session/redis'
require 'rack/mock'

RSpec.describe 'Legacy ACK authentication rotation with Redis sessions' do
  it 'rejects pre-login and pre-logout credentials while allowing credentials from the new identity' do
    user_id = create_test_user('ack-rotation@example.test')
    allow(FeatureFlags).to receive(:enabled?).and_call_original
    allow(FeatureFlags).to receive(:enabled?).with('feed.legacy_pending_store').and_return(true)
    allow(MemePoolManager).to receive(:get_pool).and_return(success: true,
      memes: [{ 'url' => '/images/funny1.jpeg', 'title' => 'Rotation', 'subreddit' => 'local' }], pool_size: 1)
    bindings = []
    endpoint = lambda do |env|
      state = env.fetch('rack.session')
      if env['PATH_INFO'] == '/rotation-state'
        state['csrf'] ||= SecureRandom.hex(32)
        state[:impression_session_key] ||= SecureRandom.hex(32)
        bindings << [state[:impression_session_key], state[:user_id]]
        next [200, { 'content-type' => 'application/json' },
          [JSON.generate(csrf: state['csrf'], binding: state[:impression_session_key], user_id: state[:user_id], browsing: state[:feed_session_id])]]
      end
      MemeExplorer::App.call(env)
    end
    middleware = Rack::Session::Redis.new(endpoint, key: 'rotation.session',
      redis_server: { url: ENV.fetch('REDIS_URL'), namespace: "rotation-#{SecureRandom.hex(12)}" },
      secret: 'local-auth-rotation-test-' * 4, expire_after: 60)
    client = Rack::MockRequest.new(middleware)
    cookie = nil
    request = lambda do |method, path, options = {}|
      response = client.public_send(method, path, options.merge('HTTP_COOKIE' => cookie.to_s))
      session_cookie = Array(response['set-cookie']).flat_map { |header| header.split("\n") }
        .find { |header| header.start_with?('rotation.session=') }
      cookie = session_cookie.split(';').first if session_cookie
      response
    end
    state = -> { JSON.parse(request.call(:get, '/rotation-state').body) }
    select_id = lambda do
      response = request.call(:get, '/random.json')
      expect(response.status).to eq(200)
      JSON.parse(response.body).fetch('impression_id').tap { |id| expect(id).not_to be_nil }
    end
    ack = lambda do |id, csrf|
      request.call(:post, '/api/impressions', 'HTTP_X_CSRF_TOKEN' => csrf,
        'CONTENT_TYPE' => 'application/json', input: JSON.generate(impression_id: id))
    end

    anonymous = state.call
    anonymous_id = select_id.call
    browsing_identity = state.call.fetch('browsing')
    expect(browsing_identity).to match(/\A[a-f0-9]{64}\z/)
    DiscoveryPreferencesStore.call(browsing_identity, action: 'hide', community: 'other_community')
    anonymous_cookie = cookie
    login = request.call(:post, '/login', 'HTTP_X_CSRF_TOKEN' => anonymous.fetch('csrf'),
      params: { email: 'ack-rotation@example.test', password: 'password123' })
    expect(JSON.parse(login.body)['success']).to be true
    expect(cookie).not_to eq(anonymous_cookie)
    authenticated = state.call
    expect(authenticated['user_id']).to eq(user_id)
    expect(authenticated['binding']).not_to eq(anonymous['binding'])
    expect(authenticated['browsing']).to eq(browsing_identity)
    expect(DiscoveryPreferencesStore.call(browsing_identity)['hidden']).to eq(['other_community'])
    expect(ack.call(anonymous_id, authenticated.fetch('csrf')).status).to eq(404)
    authenticated_id = select_id.call
    expect(ack.call(authenticated_id, authenticated.fetch('csrf')).status).to eq(200)

    logout = request.call(:post, '/logout', 'HTTP_X_CSRF_TOKEN' => authenticated.fetch('csrf'))
    expect(logout.status).to eq(303)
    expect { DiscoveryPreferencesStore.call(browsing_identity) }.to raise_error(DiscoveryPreferencesStore::Revoked)
    logged_out = state.call
    expect(logged_out['user_id']).to be_nil
    expect(logged_out['binding']).not_to eq(authenticated['binding'])
    expect(ack.call(authenticated_id, logged_out.fetch('csrf')).status).to eq(404)
    expect(ack.call(anonymous_id, logged_out.fetch('csrf')).status).to eq(404)
    expect(ack.call(select_id.call, logged_out.fetch('csrf')).status).to eq(200)
    expect(state.call.fetch('browsing')).not_to eq(browsing_identity)
    expect(DB.get_first_value('SELECT COUNT(*) FROM meme_impressions').to_i).to eq(2)
  ensure
    DiscoveryPreferencesStore.delete(browsing_identity) if browsing_identity
    bindings&.uniq&.each do |binding, identity|
      RedisService.with_redis { |redis| redis.del(*LegacyImpressionStore.keys(binding, identity)) }
    end
  end
end