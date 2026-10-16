require_relative '../spec_helper'

RSpec.describe 'Personalization mutation boundaries' do
  def json_post(path, payload)
    post path, payload, { 'CONTENT_TYPE' => 'application/json', 'HTTP_ACCEPT' => 'application/json' }
  end

  it 'rejects malformed, nonstring and oversized subscription emails' do
    ['{broken', '[]', '{"email":42}', '{"email":"bad"}', { email: "#{'a' * 255}@example.com" }.to_json].each do |payload|
      json_post('/api/subscribe', payload)
      expect(last_response.status).to eq(400)
      expect(JSON.parse(last_response.body)['success']).to eq(false)
    end
  end

  it 'reports subscription persistence failure without exception details' do
    allow(DB).to receive(:execute).and_call_original
    allow(DB).to receive(:execute).with(include('INSERT INTO email_subscriptions'), anything).and_raise(PG::ConnectionBad, 'private details')
    json_post('/api/subscribe', { email: 'valid@example.com' }.to_json)
    expect(last_response.status).to eq(503)
    expect(last_response.body).not_to include('private details')
    expect(session[:email_captured]).not_to eq(true)
  end

  it 'confirms subscription only after persistence succeeds' do
    allow(DB).to receive(:execute).and_call_original
    expect(DB).to receive(:execute).with(include('INSERT INTO email_subscriptions'), ['valid@example.com', nil, kind_of(Integer)]).and_return([])
    json_post('/api/subscribe', { email: 'valid@example.com' }.to_json)
    expect(last_response.status).to eq(200)
    expect(JSON.parse(last_response.body)['success']).to eq(true)
    expect(session[:email_captured]).to eq(true)
  end

  it 'requires authentication before removing saved content' do
    json_post('/api/saved/remove', '{"url":"/a.jpg"}')
    expect(last_response.status).to eq(401)
  end

  it 'rejects malformed saved-removal payloads for authenticated users' do
    set_session(user_id: create_test_user('remove-validation@example.com'))
    ['{broken', '[]', '{}', '{"url":42}', '{"url":" "}'].each do |payload|
      json_post('/api/saved/remove', payload)
      expect(last_response.status).to eq(400)
    end
  end

  it 'scopes removal to the authenticated account and reports database failures' do
    user_id = create_test_user('remove-scope@example.com')
    other_id = create_test_user('remove-other@example.com')
    UserService.save_meme(user_id, '/a.jpg', 'Owned', 'funny')
    UserService.save_meme(other_id, '/a.jpg', 'Other', 'funny')
    set_session(user_id: user_id)
    allow(DB).to receive(:execute).and_call_original
    json_post('/api/saved/remove', '{"url":"/a.jpg"}')
    expect(last_response.status).to eq(200)
    expect(UserService.is_meme_saved?(user_id, '/a.jpg')).to be_nil
    expect(UserService.is_meme_saved?(other_id, '/a.jpg')).not_to be_nil
    allow(DB).to receive(:execute).with(include('DELETE FROM saved_memes'), anything).and_raise(PG::ConnectionBad, 'private details')
    json_post('/api/saved/remove', '{"url":"/b.jpg"}')
    expect(last_response.status).to eq(503)
    expect(last_response.body).not_to include('private details')
  end
end