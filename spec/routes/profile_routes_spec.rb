require 'spec_helper'

# BUG FIX: every "requires authentication" example in this file expected a
# bare 401 from an unauthenticated request, but AuthHelpers#require_auth!
# (lib/helpers/auth_helpers.rb) only returns a JSON 401 for XHR/JSON
# clients - a plain browser-style GET/POST with no such header gets
# redirected (302) to /login instead, by design, so real logged-out users
# see a login page rather than a raw 401. These specs were failing against
# correct, intentional behavior; not against a bug. Send an
# `X-Requested-With: XMLHttpRequest` header (the same signal a real fetch()/
# XHR call sends) to exercise the JSON-client branch these tests actually
# mean to test.
describe 'Profile Routes' do
  let(:user_id) { UserService.create_email_user('user@example.com', 'password123') }

  def xhr_headers
    { 'HTTP_X_REQUESTED_WITH' => 'XMLHttpRequest' }
  end

  describe 'GET /profile' do
    it 'requires authentication' do
      get '/profile', {}, xhr_headers
      expect(last_response.status).to eq(401)
    end

    it 'returns profile page for authenticated user' do
      session[:user_id] = user_id
      get '/profile'
      expect(last_response.status).to eq(200)
    end
  end

  describe 'POST /api/save-meme' do
    before { session[:user_id] = user_id }

    it 'requires authentication' do
      session.clear
      refresh_csrf_token
      post '/api/save-meme', { url: 'http://example.com/meme.jpg' }, xhr_headers
      expect(last_response.status).to eq(401)
    end

    it 'requires URL parameter' do
      post '/api/save-meme', { title: 'Test', subreddit: 'funny' }
      expect(last_response.status).to eq(400)
    end

    it 'saves meme for user' do
      post '/api/save-meme', { url: 'http://example.com/meme.jpg', title: 'Funny Meme', subreddit: 'funny' }
      expect(last_response.status).to eq(200)
      response_body = JSON.parse(last_response.body)
      expect(response_body['saved']).to eq(true)
    end

    it 'returns JSON response' do
      post '/api/save-meme', { url: 'http://example.com/meme.jpg', title: 'Test', subreddit: 'funny' }
      response_body = JSON.parse(last_response.body)
      expect(response_body).to include('saved', 'message')
    end
  end

  describe 'POST /api/unsave-meme' do
    before do
      session[:user_id] = user_id
      UserService.save_meme(user_id, 'http://example.com/meme.jpg', 'Test', 'funny')
    end

    it 'requires authentication' do
      session.clear
      refresh_csrf_token
      post '/api/unsave-meme', { url: 'http://example.com/meme.jpg' }, xhr_headers
      expect(last_response.status).to eq(401)
    end

    it 'removes saved meme' do
      post '/api/unsave-meme', { url: 'http://example.com/meme.jpg' }
      expect(last_response.status).to eq(200)
      response_body = JSON.parse(last_response.body)
      expect(response_body['unsaved']).to eq(true)
    end

    it 'restores a removed favorite with its metadata through the save endpoint' do
      url = 'http://example.com/meme.jpg'
      post '/api/unsave-meme', { url: url }
      expect(UserService.is_meme_saved?(user_id, url)).to be_nil
      post '/api/save-meme', { url: url, title: 'Restored title', subreddit: 'cats' }
      expect(JSON.parse(last_response.body)['saved']).to eq(true)
      row = DB.execute('SELECT meme_title, meme_subreddit FROM saved_memes WHERE user_id = ? AND meme_url = ?', [user_id, url]).first
      expect(row).to include('meme_title' => 'Restored title', 'meme_subreddit' => 'cats')
    end

    it 'handles missing URL' do
      post '/api/unsave-meme', { url: '' }
      expect(last_response.status).to eq(400)
    end

    it 'does not claim removal when persistence fails' do
      allow(EngagementService).to receive(:track_save).and_return(success: false)
      post '/api/unsave-meme', { url: 'http://example.com/meme.jpg' }
      data = JSON.parse(last_response.body)
      expect(data).to include('success' => false, 'unsaved' => false, 'message' => 'Could not remove meme')
      expect(UserService.is_meme_saved?(user_id, 'http://example.com/meme.jpg')).not_to be_nil
    end
  end

  describe 'GET /saved/:id' do
    before do
      # BUG FIX: this never logged in (no `session[:user_id] = user_id`),
      # so `require_auth!` in the real route correctly redirected (302) to
      # /login on every example - not a bug in the route, just a missing
      # setup step in this spec.
      session[:user_id] = user_id
      UserService.save_meme(user_id, 'http://example.com/meme.jpg', 'Saved Meme', 'funny')
      @saved_meme = DB.execute("SELECT id FROM saved_memes WHERE user_id = ? LIMIT 1", [user_id]).first
    end

    it 'returns saved meme page' do
      get "/saved/#{@saved_meme['id']}"
      expect(last_response.status).to eq(200)
    end

    it 'returns 404 for non-existent saved meme' do
      get '/saved/99999'
      expect(last_response.status).to eq(404)
    end
  end

  describe 'GET /api/notifications' do
    before { session[:user_id] = user_id }

    it 'requires authentication' do
      session.clear
      get '/api/notifications', {}, xhr_headers
      expect(last_response.status).to eq(401)
    end

    it 'returns notification data as JSON' do
      get '/api/notifications'
      expect(last_response.status).to eq(200)
      response_body = JSON.parse(last_response.body)
      expect(response_body).to include('user_id', 'saved_count', 'timestamp')
    end

    it 'includes correct saved count' do
      3.times { |i| UserService.save_meme(user_id, "http://example.com/meme#{i}.jpg", "Meme #{i}", 'funny') }
      get '/api/notifications'
      response_body = JSON.parse(last_response.body)
      expect(response_body['saved_count']).to eq(3)
    end
  end
end
