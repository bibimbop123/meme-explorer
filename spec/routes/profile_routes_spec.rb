require 'spec_helper'

describe 'Profile Routes' do
  let(:user_id) { UserService.create_email_user('user@example.com', 'password123') }

  describe 'GET /profile' do
    it 'requires authentication' do
      get '/profile'
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
      post '/api/save-meme', { url: 'http://example.com/meme.jpg' }
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
      post '/api/unsave-meme', { url: 'http://example.com/meme.jpg' }
      expect(last_response.status).to eq(401)
    end

    it 'removes saved meme' do
      post '/api/unsave-meme', { url: 'http://example.com/meme.jpg' }
      expect(last_response.status).to eq(200)
      response_body = JSON.parse(last_response.body)
      expect(response_body['unsaved']).to eq(true)
    end

    it 'handles missing URL' do
      post '/api/unsave-meme', { url: '' }
      expect(last_response.status).to eq(400)
    end
  end

  describe 'GET /saved/:id' do
    before do
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
      get '/api/notifications'
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
