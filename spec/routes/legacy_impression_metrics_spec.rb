require_relative '../spec_helper'

RSpec.describe 'Legacy impression metrics access' do
  it 'requires authentication' do
    get '/api/admin/legacy-impression-metrics'
    expect(last_response.status).to eq(401)
  end

  it 'rejects ordinary users' do
    session[:user_id] = create_test_user('metrics-reader@example.test')
    get '/api/admin/legacy-impression-metrics'
    expect(last_response.status).to eq(403)
  end

  it 'returns aggregate data to admins without caching' do
    session[:user_id] = create_test_user('metrics-admin@example.test', 'password123', true)
    get '/api/admin/legacy-impression-metrics'
    expect(last_response.status).to eq(200)
    expect(last_response.headers['Cache-Control']).to include('no-store')
    expect(JSON.parse(last_response.body)).to include('available' => true, 'counts' => a_kind_of(Hash))
  end

  it 'does not present unavailable metrics as zero' do
    session[:user_id] = create_test_user('metrics-outage@example.test', 'password123', true)
    allow(LegacyImpressionMetrics).to receive(:snapshot).and_return(available: false, counts: nil)
    get '/api/admin/legacy-impression-metrics'
    expect(last_response.status).to eq(503)
    expect(JSON.parse(last_response.body)).to include('available' => false, 'counts' => nil)
  end
end