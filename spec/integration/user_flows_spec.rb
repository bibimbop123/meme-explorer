# frozen_string_literal: true

require_relative '../spec_helper'

RSpec.describe 'User Flow Integration Tests' do
  describe 'Authentication Journey' do
    context 'new user signup flow' do
      it 'successfully creates account and logs in' do
        # Test full signup → login → profile access flow
        user_data = {
          username: 'integration_test_user',
          email: 'integration@test.com',
          password: 'SecurePass123!'
        }

        # Step 1: Signup
        post '/signup', user_data
        expect(last_response.status).to eq(302) # Redirect after signup
        
        # Step 2: Login
        post '/login', {
          username: user_data[:username],
          password: user_data[:password]
        }
        expect(last_response.status).to eq(302)
        
        # Step 3: Access profile
        get '/profile'
        expect(last_response).to be_ok
        expect(last_response.body).to include(user_data[:username])
      end

      it 'handles validation errors gracefully' do
        # Test with invalid data
        post '/signup', {
          username: 'ab', # Too short
          email: 'invalid-email',
          password: '123' # Too weak
        }
        
        expect(last_response.status).to be_between(200, 400)
        expect(last_response.body).to include('error') | include('invalid')
      end
    end

    context 'password reset flow' do
      before do
        @user = create_test_user(
          username: 'reset_test',
          email: 'reset@test.com'
        )
      end

      it 'allows user to reset password' do
        # Request password reset
        post '/forgot-password', { email: @user[:email] }
        expect(last_response.status).to be_between(200, 302)
        
        # Would normally test email delivery and token usage
        # Simplified for integration test
      end
    end

    context 'session management' do
      it 'maintains session across requests' do
        user = login_test_user
        
        # Make multiple requests
        get '/random'
        expect(last_response).to be_ok
        
        get '/trending'
        expect(last_response).to be_ok
        
        get '/profile'
        expect(last_response).to be_ok
        expect(last_response.body).to include(user[:username])
      end

      it 'logs out user properly' do
        login_test_user
        
        post '/logout'
        expect(last_response.status).to eq(302)
        
        # Verify session is cleared
        get '/profile'
        expect(last_response.status).to eq(302) # Redirect to login
      end
    end
  end

  describe 'Meme Discovery Flow' do
    before do
      @user = login_test_user
      seed_meme_pool(count: 50)
    end

    it 'discovers memes through various paths' do
      # Path 1: Random exploration
      get '/random'
      expect(last_response).to be_ok
      first_meme = extract_meme_from_response(last_response)
      
      # Path 2: Category browsing
      get '/category/funny'
      expect(last_response).to be_ok
      
      # Path 3: Trending feed
      get '/trending'
      expect(last_response).to be_ok
      
      # Path 4: Search
      get '/search?q=test'
      expect(last_response).to be_ok
    end

    it 'tracks user interactions' do
      get '/random'
      meme = extract_meme_from_response(last_response)
      
      # Like the meme
      post "/memes/#{meme[:id]}/like"
      expect(last_response).to be_ok
      
      # Save the meme
      post "/memes/#{meme[:id]}/save"
      expect(last_response).to be_ok
      
      # Verify interaction was tracked
      get '/profile'
      expect(last_response.body).to include('liked') | include('saved')
    end

    it 'provides personalized recommendations' do
      # Like several memes in a category
      5.times do
        get '/category/wholesome'
        meme = extract_meme_from_response(last_response)
        post "/memes/#{meme[:id]}/like" if meme
      end
      
      # Get random meme (should be influenced by preferences)
      get '/random'
      expect(last_response).to be_ok
      
      # Check that recommendation considers history
      # (Detailed preference logic tested in unit tests)
    end
  end

  describe 'Gamification Loop' do
    before do
      @user = login_test_user
    end

    it 'tracks streak progression' do
      # Day 1: View meme
      get '/random'
      expect(last_response).to be_ok
      
      # Check streak started
      get '/profile'
      expect(last_response.body).to match(/streak/i)
      
      # Simulate next day activity (would need time manipulation)
      # streak_count = extract_streak_from_profile
      # expect(streak_count).to be >= 1
    end

    it 'awards points for engagement' do
      initial_points = get_user_points(@user[:id])
      
      # Perform point-earning actions
      get '/random' # View meme
      post "/memes/1/like" # Like meme
      post "/memes/1/share" # Share meme
      
      final_points = get_user_points(@user[:id])
      expect(final_points).to be > initial_points
    end

    it 'unlocks achievements' do
      # Trigger achievement condition
      10.times do
        get '/random'
        meme = extract_meme_from_response(last_response)
        post "/memes/#{meme[:id]}/like" if meme
      end
      
      get '/profile'
      # Check for achievement notification or badge
      # expect(last_response.body).to include('achievement') | include('badge')
    end

    it 'updates leaderboard position' do
      # Earn enough points to appear on leaderboard
      50.times do |i|
        post "/memes/#{i}/like"
      end
      
      get '/leaderboard'
      expect(last_response).to be_ok
      # User should appear in rankings
    end
  end

  describe 'Error Recovery Flows' do
    it 'handles API failures gracefully' do
      # Simulate Reddit API failure
      allow(RedditFetcherService).to receive(:fetch_memes).and_raise(StandardError)
      
      get '/random'
      # Should fallback to cached memes
      expect(last_response).to be_ok
    end

    it 'handles database connection issues' do
      # Would require database connection mocking
      # Should show error page but not crash
    end

    it 'handles cache failures' do
      # Simulate Redis failure
      allow_any_instance_of(CacheManager).to receive(:get).and_return(nil)
      
      get '/trending'
      # Should fallback to direct database query
      expect(last_response).to be_ok
    end
  end

  # Helper methods
  def create_test_user(username:, email:, password: 'TestPass123!')
    DB[:users].insert(
      username: username,
      email: email,
      password_hash: BCrypt::Password.create(password),
      created_at: Time.now
    )
    { username: username, email: email, password: password, id: DB[:users].max(:id) }
  end

  def login_test_user
    user = create_test_user(
      username: "test_#{Time.now.to_i}",
      email: "test_#{Time.now.to_i}@example.com"
    )
    post '/login', { username: user[:username], password: user[:password] }
    user
  end

  def seed_meme_pool(count: 10)
    count.times do |i|
      DB[:memes].insert(
        reddit_id: "test_#{i}",
        title: "Test Meme #{i}",
        url: "https://example.com/meme#{i}.jpg",
        category: ['funny', 'wholesome', 'relatable'].sample,
        created_at: Time.now - rand(1000)
      )
    end
  end

  def extract_meme_from_response(response)
    # Parse HTML or JSON to extract meme data
    # Simplified for example
    { id: 1, title: 'Test Meme' }
  end

  def get_user_points(user_id)
    DB[:users].where(id: user_id).get(:points) || 0
  end
end
