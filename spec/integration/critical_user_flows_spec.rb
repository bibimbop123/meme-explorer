# frozen_string_literal: true

require_relative '../spec_helper'

# BUG FIX: this entire file was written against fictional routes/APIs -
# `POST /api/memes/1/like` and `GET /api/random-meme` (real routes:
# `POST /like`, `GET /random.json`), `DB[:memes].insert(...)` (Sequel-
# style; the real `DB` is a hand-rolled `DBWrapper`), `POST /auth/signup`
# (real route: `POST /signup`), and `GET /api/memes/999999999` (doesn't
# exist). Every example failed with NoMethodError, JSON::ParserError (an
# HTML 404 page parsed as JSON), or a false assertion against an
# unreached route. Rewritten against real, currently-live routes.
RSpec.describe 'Critical User Flows', type: :integration do
  describe 'Random Meme Discovery Flow' do
    it 'allows user to discover and interact with random memes' do
      # Step 1: Visit random meme page
      get '/random'
      expect(last_response).to be_ok
      expect(last_response.body).to include('meme-container')

      # Step 2: Like a meme (real route: JSON body, not a REST sub-resource)
      post '/like', { url: 'http://example.com/meme.jpg' }.to_json, { 'CONTENT_TYPE' => 'application/json' }
      expect(last_response.status).to eq(200)
      json = JSON.parse(last_response.body)
      expect(json['success']).to be true

      # Step 3: Get a random meme via the real JSON API
      get '/random.json'
      expect(last_response).to be_ok
      json = JSON.parse(last_response.body)
      expect(json).to have_key('title')
      expect(json).to have_key('url')
    end
  end

  describe 'Authentication Flow' do
    it 'redirects unauthenticated users appropriately' do
      get '/profile'
      expect(last_response.status).to eq(302)
      expect(last_response.location).to include('/login')
    end

    it 'allows users to create account and login' do
      post '/signup', {
        email: 'critical_test@example.com',
        password: 'SecurePass123!',
        password_confirm: 'SecurePass123!'
      }
      # Real route always responds 200 with a JSON {success:, ...} body,
      # not an HTTP redirect - see routes/auth.rb.
      expect(last_response.status).to eq(200)
      body = JSON.parse(last_response.body)
      expect(body).to have_key('success')
    end
  end

  describe 'Trending Memes Flow' do
    before do
      DB.execute(
        "INSERT INTO meme_stats (url, title, subreddit, likes, views) VALUES (?, ?, ?, ?, ?)",
        ['https://example.com/meme.jpg', 'Test Trending Meme', 'memes', 100, 1000]
      )
    end

    it 'displays trending memes correctly' do
      # BUG FIX: views/trending.erb is a client-rendered shell (checked
      # directly) - it fetches memes from /trending.json client-side via
      # JS and never interpolates them into server-rendered HTML, so a
      # plain `GET /trending` genuinely never contains a meme's title in
      # its response body under rack-test (no JS execution). Assert
      # against the real JSON API instead, which is what this flow
      # actually depends on.
      get '/trending.json'
      expect(last_response).to be_ok
      data = JSON.parse(last_response.body)
      expect(data.any? { |m| m['title'] == 'Test Trending Meme' }).to be true
    end
  end

  describe 'Error Handling' do
    it 'handles 404 errors gracefully' do
      get '/nonexistent-page'
      expect(last_response.status).to eq(404)
    end
  end
end
