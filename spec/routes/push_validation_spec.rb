require_relative '../spec_helper'

RSpec.describe 'Push subscription boundaries' do
  def subscribe(payload)
    post '/api/subscribe-push', payload, 'CONTENT_TYPE' => 'application/json'
  end

  it 'requires authentication' do
    subscribe('{}')
    expect(last_response.status).to eq(401)
  end

  it 'rejects malformed payloads before any push database access' do
    set_session(user_id: create_test_user('push-validation@example.com'))
    allow(DB).to receive(:execute).and_call_original
    expect(DB).not_to receive(:execute).with(include('push_subscriptions'), anything)
    ['{broken', '[]', '{}', { endpoint: 'javascript:bad', keys: {} }.to_json,
     { endpoint: 'https://user:password@example.com/push', keys: { p256dh: 'abc', auth: 'def' } }.to_json,
     { endpoint: 'https://example.com/push', keys: { p256dh: 42, auth: 'def' } }.to_json].each do |payload|
      subscribe(payload)
      expect(last_response.status).to eq(400)
      expect(JSON.parse(last_response.body)['success']).to eq(false)
    end
  end

  it 'reports storage failure without exposing database or endpoint details' do
    set_session(user_id: create_test_user('push-storage@example.com'))
    allow(DB).to receive(:execute).and_call_original
    allow(DB).to receive(:execute).with(include('SELECT id FROM push_subscriptions'), anything).and_raise(PG::UndefinedColumn, 'private database details')
    subscribe({ endpoint: 'https://example.com/private-endpoint', keys: { p256dh: 'abc', auth: 'def' } }.to_json)
    expect(last_response.status).to eq(503)
    expect(last_response.body).not_to include('private database details', 'private-endpoint')
  end
end