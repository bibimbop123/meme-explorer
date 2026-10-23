require_relative '../spec_helper'
require_relative '../../config/rack_attack'

RSpec.describe 'Visitor observation abuse limit' do
  before { Rack::Attack.cache.store.clear }
  after { Rack::Attack.cache.store.clear }

  it 'bounds observations without applying that limit to withdrawal or other clients' do
    middleware = Rack::Attack.new(->(_env) { [204, {}, []] })
    request = lambda do |path, ip = '198.51.100.12'|
      middleware.call(Rack::MockRequest.env_for(path, method: 'POST', 'REMOTE_ADDR' => ip))
    end
    60.times { expect(request.call('/api/visitor-observation')[0]).to eq(204) }
    response = request.call('/api/visitor-observation')
    expect(response[0]).to eq(429)
    expect(response[1]['Retry-After']).to eq('60')
    expect(request.call('/api/visitor-withdrawal')[0]).to eq(204)
    expect(request.call('/api/visitor-observation', '198.51.100.13')[0]).to eq(204)
    expect(request.call('/api/visitor-observation', '127.0.0.1')[0]).to eq(204)
  end
end