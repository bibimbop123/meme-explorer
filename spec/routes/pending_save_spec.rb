require_relative '../spec_helper'

RSpec.describe 'Pending save login recovery' do
  it 'rejects expired OAuth state without authenticating or losing pending context' do
    pending = { 'id' => 'a' * 64, 'expires_at' => Time.now.to_i + 60 }
    session[:pending_save] = pending
    session[:oauth_state] = 'expired-state'
    session[:oauth_state_timestamp] = Time.now.to_i - 601
    expect(AuthService).not_to receive(:verify_reddit_oauth)
    get '/auth/reddit/callback', code: 'test-code', state: 'expired-state'
    expect(last_response.headers['location']).to end_with('/login')
    expect(session[:user_id]).to be_nil
    expect(session[:pending_save]).to eq(pending)
  end

  it 'does not promise pending recovery when the catalog fails or the payload is malformed' do
    session[:pending_save] = { 'id' => 'a' * 64, 'expires_at' => Time.now.to_i + 60 }
    allow(MemeIdentityService).to receive(:find).and_raise(PG::ConnectionBad)
    post '/api/save-meme', { content_id: 'b' * 64 }.to_json, 'CONTENT_TYPE' => 'application/json'
    expect(last_response.status).to eq(401)
    expect(JSON.parse(last_response.body)['pending_save']).to eq(false)
    expect(session[:pending_save]).to be_nil
    post '/api/save-meme', '{broken', 'CONTENT_TYPE' => 'application/json'
    expect(last_response.status).to eq(401)
    expect(JSON.parse(last_response.body)['pending_save']).to eq(false)
  end

  it 'returns validated Reddit OAuth to pending content while rotating session state' do
    user_id = create_test_user('pending-oauth@example.com')
    session[:pending_save] = { 'id' => 'e' * 64, 'expires_at' => Time.now.to_i + 60 }
    session[:oauth_state] = 'expected-state'
    session[:oauth_state_timestamp] = Time.now.to_i
    session[:discard_me] = true
    allow(AuthService).to receive(:verify_reddit_oauth).and_return(success: true, username: 'test-redditor', id: 'reddit-id', token: 'test-token')
    allow(AuthService).to receive(:store_oauth_token)
    allow(UserService).to receive(:create_or_find_from_reddit).and_return(user_id)
    get '/auth/reddit/callback', code: 'test-code', state: 'expected-state'
    expect(last_response.status).to eq(302)
    expect(last_response.headers['location']).to end_with("/meme/#{'e' * 64}?save_after_login=1")
    expect(session[:user_id].to_i).to eq(user_id.to_i)
    expect(session[:discard_me]).to be_nil
    expect(session[:pending_save]).to be_nil
  end

  it 'does not exchange OAuth tokens or discard pending content on invalid state' do
    pending = { 'id' => 'f' * 64, 'expires_at' => Time.now.to_i + 60 }
    session[:pending_save] = pending
    session[:oauth_state] = 'expected-state'
    expect(AuthService).not_to receive(:verify_reddit_oauth)
    get '/auth/reddit/callback', code: 'test-code', state: 'wrong-state'
    expect(last_response.headers['location']).to end_with('/login')
    expect(session[:pending_save]).to eq(pending)
    expect(session[:user_id]).to be_nil
  end

  it 'preserves pending content after failed login and uses it after a successful retry' do
    create_test_user('pending-retry@example.com', 'SecurePass123!')
    pending = { 'id' => 'a' * 64, 'expires_at' => Time.now.to_i + 60 }
    session[:pending_save] = pending
    post '/login', { email: 'pending-retry@example.com', password: 'WrongPassword!' }
    expect(JSON.parse(last_response.body)['success']).to eq(false)
    expect(session[:pending_save]).to eq(pending)
    post '/login', { email: 'pending-retry@example.com', password: 'SecurePass123!' }
    expect(JSON.parse(last_response.body)['redirect']).to eq("/meme/#{'a' * 64}?save_after_login=1")
  end

  it 'returns signup to pending content without copying unrelated session state' do
    redis = MemeExplorer::App.settings.redis
    redis.del('signup_attempts:127.0.0.1') if redis
    session[:pending_save] = { 'id' => 'b' * 64, 'expires_at' => Time.now.to_i + 60 }
    session[:untrusted_old_state] = 'discard'
    post '/signup', { email: 'pending-signup@example.com', password: 'SecurePass123!', password_confirm: 'SecurePass123!' }
    expect(JSON.parse(last_response.body)).to include('success' => true, 'redirect' => "/meme/#{'b' * 64}?save_after_login=1")
    expect(session[:untrusted_old_state]).to be_nil
    expect(session[:pending_save]).to be_nil
  end

  it 'does not retain missing or removed content as a pending save' do
    post '/api/save-meme', { content_id: 'c' * 64 }.to_json, 'CONTENT_TYPE' => 'application/json'
    expect(JSON.parse(last_response.body)['pending_save']).to eq(false)
    expect(session[:pending_save]).to be_nil
    id = MemeIdentityService.register({ 'url' => 'https://i.redd.it/removed-pending.jpg' })
    DB.execute('UPDATE meme_catalog SET removed_at = CURRENT_TIMESTAMP WHERE id = ?', [id])
    post '/api/save-meme', { content_id: id }.to_json, 'CONTENT_TYPE' => 'application/json'
    expect(JSON.parse(last_response.body)['pending_save']).to eq(false)
  end

  it 'falls back to profile after expired pending context' do
    create_test_user('pending-expired@example.com', 'SecurePass123!')
    session[:pending_save] = { 'id' => 'd' * 64, 'expires_at' => 0 }
    post '/login', { email: 'pending-expired@example.com', password: 'SecurePass123!' }
    expect(JSON.parse(last_response.body)['redirect']).to eq('/profile')
  end

  it 'returns email login to the selected meme without automatically saving it' do
    user_id = create_test_user('pending-save@example.com', 'SecurePass123!')
    id = MemeIdentityService.register({ 'url' => 'https://i.redd.it/pending.jpg', 'title' => 'Pending' })
    post '/api/save-meme', { content_id: id }.to_json, 'CONTENT_TYPE' => 'application/json'
    expect(last_response.status).to eq(401)
    expect(JSON.parse(last_response.body)['pending_save']).to eq(true)
    post '/login', { email: 'pending-save@example.com', password: 'SecurePass123!' }
    expect(JSON.parse(last_response.body)).to include('success' => true, 'redirect' => "/meme/#{id}?save_after_login=1")
    expect(UserService.is_meme_saved?(user_id, 'https://i.redd.it/pending.jpg')).to be_nil
    expect(session[:pending_save]).to be_nil
  end

  it 'rejects expired or arbitrary redirect context' do
    helper = Object.new.extend(AuthHelpers)
    expect(helper.pending_save_target({ 'id' => '//evil.example', 'expires_at' => Time.now.to_i + 60 })).to be_nil
    expect(helper.pending_save_target({ 'id' => 'a' * 64, 'expires_at' => 0 })).to be_nil
  end
end