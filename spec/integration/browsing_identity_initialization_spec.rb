require_relative '../spec_helper'
require 'rack/session/redis'
require 'rack/mock'

RSpec.describe 'Browsing identity initialization with Redis sessions' do
  it 'preserves an existing browsing identity without consulting the rotated Rack ID' do
    helper = Class.new do
      include AuthHelpers
      attr_accessor :session
    end.new
    identity = SecureRandom.hex(32)
    state = { feed_session_id: identity }
    allow(state).to receive(:id).and_raise('must not derive over existing identity')
    helper.session = state
    expect(helper.feed_session_id).to eq(identity)
  end

  it 'initializes the same browsing identity in overlapping established-session snapshots' do
    namespace = "browsing-init-#{SecureRandom.hex(12)}"
    helper = Class.new do
      include AuthHelpers
      attr_accessor :session
    end
    client = nil
    cookie = nil
    nested_identity = nil
    rack_ids = []
    endpoint = lambda do |env|
      state = env.fetch('rack.session')
      if env['PATH_INFO'] == '/seed'
        state[:seed] = true
        next [200, {}, ['seed']]
      end
      # Force snapshot load before the nested request commits its identity.
      state[:seed]
      if env['PATH_INFO'] == '/overlap'
        nested_identity = client.get('/identity', 'HTTP_COOKIE' => cookie).body
      end
      instance = helper.new
      instance.session = state
      rack_ids << state.id.private_id
      [200, {}, [instance.feed_session_id]]
    end
    middleware = Rack::Session::Redis.new(endpoint, key: 'browsing.session',
      redis_server: { url: ENV.fetch('REDIS_URL'), namespace: namespace }, expire_after: 60)
    client = Rack::MockRequest.new(middleware)
    cookie = client.get('/seed')['set-cookie'].split(';').first
    outer_identity = client.get('/overlap', 'HTTP_COOKIE' => cookie).body
    expect(outer_identity).to match(/\A[a-f0-9]{64}\z/)
    expect(outer_identity).to eq(nested_identity)
    expect(client.get('/identity', 'HTTP_COOKIE' => cookie).body).to eq(outer_identity)
    expect(rack_ids).not_to include(outer_identity)
    expect(cookie).not_to include(outer_identity)
    other_cookie = client.get('/seed')['set-cookie'].split(';').first
    other_identity = client.get('/identity', 'HTTP_COOKIE' => other_cookie).body
    expect(other_identity).to match(/\A[a-f0-9]{64}\z/)
    expect(other_identity).not_to eq(outer_identity)
    expect(rack_ids).not_to include(other_identity)
  ensure
    REDIS_POOL.with do |redis|
      redis.scan_each(match: "#{namespace}:*").each { |key| redis.del(key) }
    end if namespace
  end
end