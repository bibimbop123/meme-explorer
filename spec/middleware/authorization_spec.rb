require_relative '../spec_helper'
require_relative '../../lib/middleware/authorization'

RSpec.describe AuthorizationMiddleware do
  let(:middleware) { described_class.new(->(_env) { [200, {}, ['allowed']] }) }

  def invoke(path, role: 'user', user_id: nil, json: false)
    env = Rack::MockRequest.env_for(path).merge('rack.session' => { user_id: user_id, role: role })
    env['CONTENT_TYPE'] = 'application/json' if json
    middleware.call(env)
  end

  it 'denies every admin route family to ordinary users' do
    ['/admin', '/admin/settings', '/users/12/role', '/permissions'].each do |path|
      status, headers, body = invoke(path, user_id: 12, json: true)
      expect(status).to eq(403)
      expect(headers['Content-Type']).to eq('application/json')
      expect(JSON.parse(body.join)['error']).to eq('Admin access required')
    end
  end

  it 'requires an identity even if a guest session claims the admin role' do
    expect(invoke('/admin', role: 'admin')[0]).to eq(403)
  end

  it 'allows administrators through admin routes' do
    expect(invoke('/admin', role: 'admin', user_id: 12)[0]).to eq(200)
  end

  it 'allows moderator and administrator roles through moderation' do
    %w[moderator admin].each do |role|
      expect(invoke('/moderate/reports', role: role, user_id: 12)[0]).to eq(200)
    end
  end

  it 'denies moderation to ordinary users with browser and JSON responses' do
    expect(invoke('/moderate', user_id: 12)[0]).to eq(403)
    expect(JSON.parse(invoke('/moderate', user_id: 12, json: true)[2].join)['error']).to eq('Moderator access required')
  end

  it 'requires login across protected product route families' do
    ['/profile', '/saved', '/collections', '/premium'].each do |path|
      expect(invoke(path)[0]).to eq(302)
      expect(invoke(path, json: true)[0]).to eq(401)
      expect(invoke(path, user_id: 12)[0]).to eq(200)
    end
  end

  it 'keeps guest discovery and login public' do
    ['/', '/random', '/trending', '/login', '/signup', '/health'].each do |path|
      expect(invoke(path)[0]).to eq(200)
    end
  end
end