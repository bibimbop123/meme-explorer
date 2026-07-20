# frozen_string_literal: true

require_relative '../spec_helper'

RSpec.describe 'Critical User Flows', type: :integration do
  describe 'Random Meme Discovery Flow' do
    it 'allows user to discover and interact with random memes' do
      # Step 1: Visit random meme page
      get '/random'
      expect(last_response).to be_ok
      expect(last_response.body).to include('meme-container')
      
      # Step 2: Like a meme
      post '/api/memes/1/like'
      expect(last_response.status).to eq(200)
      json = JSON.parse(last_response.body)
      expect(json['success']).to be true
      
      # Step 3: Get next random meme
      get '/api/random-meme'
      expect(last_response).to be_ok
      json = JSON.parse(last_response.body)
      expect(json).to have_key('meme')
      expect(json['meme']).to have_key('id')
    end
    
    it 'maintains viewing history across session' do
      # First meme
      get '/api/random-meme'
      json1 = JSON.parse(last_response.body)
      meme_id_1 = json1.dig('meme', 'id')
      
      # Second meme should be different
      get '/api/random-meme'
      json2 = JSON.parse(last_response.body)
      meme_id_2 = json2.dig('meme', 'id')
      
      expect(meme_id_1).not_to eq(meme_id_2)
    end
  end
  
  describe 'Authentication Flow' do
    it 'redirects unauthenticated users appropriately' do
      get '/profile'
      expect(last_response.status).to eq(302)
      expect(last_response.location).to include('/login')
    end
    
    it 'allows users to create account and login' do
      # Skip if auth service not configured
      skip 'Auth service not configured' unless ENV['ENABLE_AUTH']
      
      post '/auth/signup', {
        username: 'testuser',
        email: 'test@example.com',
        password: 'SecurePass123!'
      }
      expect(last_response.status).to be_between(200, 302)
    end
  end
  
  describe 'Trending Memes Flow' do
    before do
      # Seed some trending data
      DB[:memes].insert(
        reddit_id: 'test123',
        title: 'Test Trending Meme',
        url: 'https://example.com/meme.jpg',
        score: 1000,
        subreddit: 'memes',
        created_at: Time.now
      )
    end
    
    it 'displays trending memes correctly' do
      get '/trending'
      expect(last_response).to be_ok
      expect(last_response.body).to include('Test Trending Meme')
    end
    
    it 'filters trending by category' do
      get '/trending?category=funny'
      expect(last_response).to be_ok
    end
  end
  
  describe 'Error Handling' do
    it 'handles 404 errors gracefully' do
      get '/nonexistent-page'
      expect(last_response.status).to eq(404)
      expect(last_response.body).to include('404')
    end
    
    it 'handles API errors gracefully' do
      get '/api/memes/999999999'
      expect(last_response.status).to be_between(400, 500)
      json = JSON.parse(last_response.body)
      expect(json).to have_key('error')
    end
  end
end
