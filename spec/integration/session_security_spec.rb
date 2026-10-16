require_relative '../spec_helper'
require 'rack/session/redis'
require_relative '../../lib/middleware/session_validator'
require_relative '../../lib/middleware/authorization'

RSpec.describe 'Real Redis-session security and interaction contract' do
  # Same session/validation/authorization ordering as config.ru, without startup
  # cache warming or fake session injection. Each browser owns its own cookies.
  def browser
    @browser ||= begin
      stack = Rack::Builder.new do
        use Rack::Session::Redis,
          key: 'meme_explorer.session',
          redis_server: { url: ENV.fetch('REDIS_URL'), namespace: 'session_security_spec' },
          httponly: true, same_site: :lax, expire_after: 2_592_000,
          secret: 'session-security-spec-' * 4
        use SessionValidator
        use AuthorizationMiddleware
        run MemeExplorer::App
      end
      client = Rack::Test::Session.new(Rack::MockSession.new(stack.to_app))
      # Distinct visitor IPs avoid sharing signup throttles across test browsers.
      client.env('REMOTE_ADDR', "127.#{rand(1..254)}.#{rand(1..254)}.#{rand(1..254)}")
      client
    end
  end

  def page_token(path = '/login')
    browser.get(path)
    expect(browser.last_response.status).to eq(200)
    token = browser.last_response.body[/name="csrf-token" content="([^"]+)"/, 1]
    expect(token).to match(/\A[0-9a-f]{64}\z/)
    token
  end

  def signup
    token = page_token('/signup')
    browser.post('/signup', {
      email: "session-#{SecureRandom.hex(6)}@example.com",
      password: 'SecurePass123!', password_confirm: 'SecurePass123!',
      authenticity_token: token
    })
    expect(browser.last_response.status).to eq(200)
    expect(JSON.parse(browser.last_response.body)['success']).to be true
    page_token('/profile')
  end

  def json_post(path, body, token)
    browser.post(path, body, 'CONTENT_TYPE' => 'application/json', 'HTTP_X_CSRF_TOKEN' => token)
  end

  it 'creates a cookie-backed account and saves/unsaves the browser JSON payload' do
    token = signup
    expect(browser.cookie_jar['meme_explorer.session']).not_to be_nil
    url = 'https://i.redd.it/session-save.jpg'
    json_post('/api/save-meme', { url: url, title: 'Session meme', subreddit: 'funny' }.to_json, token)
    expect(browser.last_response.status).to eq(200)
    expect(JSON.parse(browser.last_response.body)['saved']).to be true
    expect(DB.get_first_value('SELECT meme_title FROM saved_memes WHERE meme_url = ?', [url])).to eq('Session meme')
    json_post('/api/unsave-meme', { url: url }.to_json, token)
    expect(browser.last_response.status).to eq(200)
    expect(DB.get_first_value('SELECT COUNT(*) FROM saved_memes WHERE meme_url = ?', [url]).to_i).to eq(0)
  end

  it 'rejects a missing or forged token before mutating saved data' do
    token = signup
    ['/api/save-meme', '/api/unsave-meme', '/like', '/api/skip-meme'].each do |path|
      json_post(path, { url: 'https://i.redd.it/rejected.jpg' }.to_json, 'forged')
      expect(browser.last_response.status).to eq(403)
    end
    browser.post('/api/save-meme', '{}', 'CONTENT_TYPE' => 'application/json')
    expect(browser.last_response.status).to eq(403)
    expect(DB.get_first_value('SELECT COUNT(*) FROM saved_memes').to_i).to eq(0)
    expect(token).not_to eq('forged')
  end

  it 'rejects malformed JSON and non-object payloads with a valid session' do
    token = signup
    ['/api/save-meme', '/api/unsave-meme'].each do |path|
      ['not-json', '[]', 'null'].each do |body|
        json_post(path, body, token)
        expect(browser.last_response.status).to eq(400)
        expect(JSON.parse(browser.last_response.body)).to have_key('error')
      end
    end
  end

  it 'logs in with a fresh token, persists identity and toggles a like' do
    email = "login-#{SecureRandom.hex(6)}@example.com"
    UserService.create_email_user(email, 'SecurePass123!')
    token = page_token
    browser.post('/login', { email: email, password: 'SecurePass123!', authenticity_token: token })
    expect(JSON.parse(browser.last_response.body)['success']).to be true
    token = page_token('/profile')
    expect(browser.last_response.body).to include(email)
    json_post('/like', { url: 'https://i.redd.it/session-like.jpg' }.to_json, token)
    expect(browser.last_response.status).to eq(200)
    expect(JSON.parse(browser.last_response.body)['liked']).to be true
  end

  it 'does not log out through GET or an unprotected POST' do
    signup
    browser.get('/logout')
    expect(browser.last_response.status).to eq(303)
    page_token('/profile')
    browser.post('/logout')
    expect(browser.last_response.status).to eq(403)
    page_token('/profile')
    expect(browser.last_response.body).to include('action="/logout"', 'name="authenticity_token"')
  end

  it 'destroys the server session so a replayed old cookie cannot restore access' do
    token = signup
    cookie = browser.cookie_jar['meme_explorer.session']
    browser.post('/logout', { authenticity_token: token })
    expect(browser.last_response.status).to eq(303)
    expect(browser.last_response.headers['cache-control']).to include('no-store')
    browser.set_cookie("meme_explorer.session=#{cookie}")
    browser.get('/profile')
    expect(browser.last_response.status).to eq(302)
    expect(browser.last_response.location).to include('/login')
    json_post('/api/save-meme', { url: 'https://i.redd.it/after-logout.jpg' }.to_json, token)
    expect([401, 403]).to include(browser.last_response.status)
    expect(DB.get_first_value('SELECT COUNT(*) FROM saved_memes').to_i).to eq(0)
  end

  it 'rotates the anonymous session cookie and token on successful login' do
    email = "rotation-#{SecureRandom.hex(6)}@example.com"
    UserService.create_email_user(email, 'SecurePass123!')
    old_token = page_token
    old_cookie = browser.cookie_jar['meme_explorer.session']
    browser.post('/login', { email: email, password: 'SecurePass123!', authenticity_token: old_token })
    expect(JSON.parse(browser.last_response.body)['success']).to be true
    expect(browser.cookie_jar['meme_explorer.session']).not_to eq(old_cookie)
    new_token = page_token('/profile')
    expect(new_token).not_to eq(old_token)
    json_post('/api/save-meme', '{}', old_token)
    expect(browser.last_response.status).to eq(403)
  end

  it 'rejects an expired session before processing a save' do
    token = signup
    future = Time.now + SessionValidator::SESSION_TIMEOUT + 2
    allow(Time).to receive(:now).and_return(future)
    json_post('/api/save-meme', { url: 'https://i.redd.it/expired.jpg' }.to_json, token)
    expect(browser.last_response.status).to eq(401)
    expect(JSON.parse(browser.last_response.body)['error']).to include('inactivity')
    expect(DB.get_first_value('SELECT COUNT(*) FROM saved_memes').to_i).to eq(0)
  end

  it 'rejects a deleted account before processing a like' do
    token = signup
    DB.execute('DELETE FROM users')
    json_post('/like', { url: 'https://i.redd.it/deleted.jpg' }.to_json, token)
    expect(browser.last_response.status).to eq(401)
    expect(JSON.parse(browser.last_response.body)['error']).to include('no longer exists')
    expect(DB.get_first_value('SELECT COUNT(*) FROM user_liked_memes').to_i).to eq(0)
  end
end