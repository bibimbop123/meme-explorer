require_relative '../spec_helper'
require_relative '../../lib/middleware/session_validator'
require_relative '../../lib/middleware/authorization'

RSpec.describe SessionValidator do
  let(:identity) { create_test_user('session-validator@example.com') }
  let(:state) { FakeSessionHash.new.merge(user_id: identity, role: 'admin') }
  let(:endpoint) { ->(_env) { [200, {}, ['allowed']] } }
  let(:middleware) { described_class.new(AuthorizationMiddleware.new(endpoint)) }

  def invoke(path = '/admin', headers = {})
    env = Rack::MockRequest.env_for(path).merge('rack.session' => state).merge(headers)
    middleware.call(env)
  end

  it 'downgrades a stale admin role before authorization using one database lookup' do
    expect(DB).to receive(:execute).with('SELECT id, role FROM users WHERE id = ?', [identity]).once.and_call_original
    expect(invoke[0]).to eq(403)
    expect(state[:role]).to eq('user')
  end

  it 'allows a verified administrator' do
    DB.execute("UPDATE users SET role = 'admin' WHERE id = ?", [identity])
    expect(invoke[0]).to eq(200)
    expect(state[:last_activity]).to be_within(2).of(Time.now.to_i)
  end

  it 'blocks database outages without destroying the session or trusting cached roles' do
    identity
    allow(DB).to receive(:execute).and_raise(PG::ConnectionBad, 'simulated outage')
    status, headers, body = invoke
    expect(status).to eq(503)
    expect(headers['retry-after']).to eq('5')
    expect(JSON.parse(body.join)['error']).to include('temporarily unavailable')
    expect(state[:user_id]).to eq(identity)
    expect(state.options[:drop]).not_to be true
  end

  it 'invalidates an inactive session and returns JSON to API clients' do
    state[:last_activity] = Time.now.to_i - described_class::SESSION_TIMEOUT - 1
    expect(invoke('/profile', 'HTTP_X_REQUESTED_WITH' => 'XMLHttpRequest')[0]).to eq(401)
    expect(state).to be_empty
    expect(state.options[:drop]).to be true
  end

  it 'invalidates sessions beyond the maximum lifetime even with recent activity' do
    state[:last_activity] = Time.now.to_i
    state[:login_timestamp] = Time.now.to_i - described_class::MAX_SESSION_LIFETIME - 1
    response = invoke('/profile')
    expect(response[0]).to eq(302)
    expect(response[1]['Location']).to include('expired=1')
    expect(state).to be_empty
  end

  it 'invalidates deleted users' do
    identity
    DB.execute('DELETE FROM users WHERE id = ?', [identity])
    expect(invoke('/profile')[0]).to eq(302)
    expect(state).to be_empty
  end

  it 'enforces optional strict IP validation' do
    previous = ENV['STRICT_IP_VALIDATION']
    ENV['STRICT_IP_VALIDATION'] = 'true'
    state[:login_ip] = '192.0.2.1'
    expect(invoke('/profile', 'REMOTE_ADDR' => '192.0.2.2')[0]).to eq(302)
  ensure
    ENV['STRICT_IP_VALIDATION'] = previous
  end

  it 'allows guest access to public discovery without a database query' do
    expect(DB).not_to receive(:execute)
    env = Rack::MockRequest.env_for('/random').merge('rack.session' => FakeSessionHash.new)
    expect(middleware.call(env)[0]).to eq(200)
  end

  it 'redirects anonymous protected browser requests and returns JSON for XHR' do
    state.clear
    expect(invoke('/profile')[0]).to eq(302)
    expect(invoke('/profile', 'HTTP_X_REQUESTED_WITH' => 'XMLHttpRequest')[0]).to eq(401)
  end
end