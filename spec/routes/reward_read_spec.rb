require_relative '../spec_helper'

RSpec.describe 'Reward read boundaries' do
  let(:json_headers) { { 'HTTP_ACCEPT' => 'application/json' } }

  it 'requires authentication for reward and boost reads' do
    ['/api/surprise-rewards/check', '/api/surprise-rewards/active-boosts'].each do |path|
      get path, {}, json_headers
      expect(last_response.status).to eq(401)
    end
  end

  it 'consumes a pending reward once without inventing another reward' do
    set_session(user_id: create_test_user('reward-read@example.com'), pending_surprise_reward: { 'type' => 'test-reward' })
    get '/api/surprise-rewards/check', {}, json_headers
    expect(last_response.status).to eq(200)
    expect(JSON.parse(last_response.body)['reward']).to eq('type' => 'test-reward')
    get '/api/surprise-rewards/check', {}, json_headers
    expect(JSON.parse(last_response.body)['reward']).to be_nil
  end

  it 'scopes boost lookup to the authenticated user' do
    user_id = create_test_user('boost-read@example.com')
    set_session(user_id: user_id)
    stub_const('SurpriseRewardsService', Class.new)
    expect(SurpriseRewardsService).to receive(:active_boosts).with(user_id.to_i).and_return([])
    get '/api/surprise-rewards/active-boosts', {}, json_headers
    expect(last_response.status).to eq(200)
    expect(JSON.parse(last_response.body)['boosts']).to eq([])
  end

  it 'reports boost service failure without internal exception details' do
    set_session(user_id: create_test_user('boost-error@example.com'))
    stub_const('SurpriseRewardsService', Class.new)
    allow(SurpriseRewardsService).to receive(:active_boosts).and_raise(StandardError, 'private connection details')
    get '/api/surprise-rewards/active-boosts', {}, json_headers
    expect(last_response.status).to eq(503)
    expect(last_response.body).not_to include('private connection details')
  end
end