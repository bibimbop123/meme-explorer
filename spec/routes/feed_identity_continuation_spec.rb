require_relative '../spec_helper'

RSpec.describe 'Feed identity through authentication' do
  let(:identity) { SecureRandom.hex(32) }

  before { session[:feed_session_id] = identity }

  it 'preserves browsing identity on successful email login but rotates other session state' do
    create_test_user('feed-login@example.test', 'SecurePass123!')
    session[:discard_me] = true
    post '/login', email: 'feed-login@example.test', password: 'SecurePass123!'
    expect(JSON.parse(last_response.body)['success']).to eq(true)
    expect(session[:feed_session_id]).to eq(identity)
    expect(session[:discard_me]).to be_nil
  end

  it 'preserves browsing identity through signup' do
    post '/signup', email: 'feed-signup@example.test', password: 'SecurePass123!', password_confirm: 'SecurePass123!'
    expect(JSON.parse(last_response.body)['success']).to eq(true)
    expect(session[:feed_session_id]).to eq(identity)
  end

  it 'preserves browsing identity through a validated OAuth callback' do
    user_id = create_test_user('feed-oauth@example.test')
    session[:oauth_state] = 'expected-state'
    session[:oauth_state_timestamp] = Time.now.to_i
    allow(AuthService).to receive(:verify_reddit_oauth).and_return(success: true, username: 'fixture', id: 'fixture-id', token: 'fixture-token')
    allow(AuthService).to receive(:store_oauth_token)
    allow(UserService).to receive(:create_or_find_from_reddit).and_return(user_id)
    get '/auth/reddit/callback', code: 'fixture-code', state: 'expected-state'
    expect(last_response.status).to eq(302)
    expect(session[:feed_session_id]).to eq(identity)
  end

  it 'clears browsing identity on explicit logout' do
    user_id = create_test_user('feed-logout@example.test')
    session[:user_id] = user_id
    post '/logout'
    expect(session[:feed_session_id]).to be_nil
  end

  it 'migrates guest liked memes and subreddit preferences into the account upon login' do
    user_id = create_test_user('guest-migrate@example.test', 'SecurePass123!')
    session[:liked_memes] = ['https://i.redd.it/guest-like-1.jpg']
    session[:liked_subreddits] = { 'wholesomememes' => 1.6 }
    post '/login', email: 'guest-migrate@example.test', password: 'SecurePass123!'
    expect(JSON.parse(last_response.body)['success']).to eq(true)

    liked = DB.execute('SELECT meme_url FROM user_liked_memes WHERE user_id = ?', [user_id]).map { |r| r['meme_url'] }
    expect(liked).to include('https://i.redd.it/guest-like-1.jpg')

    pref = DB.execute('SELECT preference_score FROM user_subreddit_preferences WHERE user_id = ? AND subreddit = ?', [user_id, 'wholesomememes']).first
    expect(pref['preference_score'].to_f).to be_within(0.01).of(1.6)
  end

  it 'syncs account viewing history across browser sessions upon login' do
    user_id = create_test_user('sync-history@example.test', 'SecurePass123!')
    MemeExplorer::ViewingHistoryService.mark_seen("user:#{user_id}", 'https://i.redd.it/seen-on-desktop.jpg')
    MemeExplorer::ViewingHistoryService.mark_seen(identity, 'https://i.redd.it/seen-as-guest.jpg')

    post '/login', email: 'sync-history@example.test', password: 'SecurePass123!'
    expect(JSON.parse(last_response.body)['success']).to eq(true)

    expect(MemeExplorer::ViewingHistoryService.get_seen_memes(identity)).to include(
      'https://i.redd.it/seen-on-desktop.jpg',
      'https://i.redd.it/seen-as-guest.jpg'
    )
    expect(MemeExplorer::ViewingHistoryService.get_seen_memes("user:#{user_id}")).to include(
      'https://i.redd.it/seen-on-desktop.jpg',
      'https://i.redd.it/seen-as-guest.jpg'
    )
  ensure
    MemeExplorer::ViewingHistoryService.clear_history(identity)
    MemeExplorer::ViewingHistoryService.clear_history("user:#{user_id}") if user_id
  end
end