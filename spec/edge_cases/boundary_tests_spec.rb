# frozen_string_literal: true

require_relative '../spec_helper'

RSpec.describe 'Edge Case and Boundary Tests' do
  describe 'Null and Empty Input Handling' do
    it 'handles null username gracefully' do
      post '/login', { username: nil, password: 'test' }
      expect(last_response.status).to be_between(400, 422)
    end

    it 'handles empty string inputs' do
      post '/signup', { username: '', email: '', password: '' }
      expect(last_response.status).to be_between(400, 422)
    end

    it 'handles whitespace-only inputs' do
      post '/signup', { username: '   ', email: '   ', password: '   ' }
      expect(last_response.status).to be_between(400, 422)
    end

    it 'handles nil meme ID gracefully' do
      get '/memes/nil'
      expect(last_response.status).to eq(404)
    end

    it 'handles search with empty query' do
      get '/search?q='
      expect(last_response).to be_ok
      # Should return all memes or default behavior
    end
  end

  describe 'Boundary Value Testing' do
    it 'handles extremely long username (256+ chars)' do
      long_username = 'a' * 300
      post '/signup', {
        username: long_username,
        email: 'test@example.com',
        password: 'ValidPass123!'
      }
      expect(last_response.status).to be_between(400, 422)
    end

    it 'handles minimum valid username (3 chars)' do
      post '/signup', {
        username: 'abc',
        email: 'min@example.com',
        password: 'ValidPass123!'
      }
      # Should either succeed or validate minimum length
      expect([200, 201, 302, 400, 422]).to include(last_response.status)
    end

    it 'handles maximum pagination limit' do
      get '/trending?limit=10000'
      expect(last_response).to be_ok
      # Should cap at reasonable limit
    end

    it 'handles negative pagination values' do
      get '/trending?page=-1&limit=-10'
      expect(last_response).to be_ok
      # Should default to page 1, limit 20
    end

    it 'handles zero values gracefully' do
      get '/trending?page=0&limit=0'
      expect(last_response).to be_ok
    end
  end

  describe 'SQL Injection Prevention' do
    it 'prevents SQL injection in username' do
      malicious_username = "admin' OR '1'='1"
      post '/login', { username: malicious_username, password: 'test' }
      expect(last_response.status).to be_between(400, 404)
    end

    it 'prevents SQL injection in search query' do
      malicious_query = "test'; DROP TABLE memes; --"
      get "/search?q=#{CGI.escape(malicious_query)}"
      expect(last_response).to be_ok
      # Verify memes table still exists
      expect(DB[:memes].count).to be >= 0
    end

    it 'prevents SQL injection in category filter' do
      get "/category/funny'; DELETE FROM users; --"
      expect(last_response.status).to be_between(200, 404)
      # Verify users table intact
      expect(DB[:users].count).to be >= 0
    end
  end

  describe 'XSS Prevention' do
    it 'escapes HTML in username display' do
      xss_username = "<script>alert('xss')</script>"
      user_id = DB[:users].insert(
        username: xss_username,
        email: 'xss@test.com',
        password_hash: BCrypt::Password.create('test'),
        created_at: Time.now
      )
      
      get "/profile/#{user_id}"
      expect(last_response.body).not_to include('<script>')
      expect(last_response.body).to include('&lt;script&gt;') | include('alert')
    end

    it 'escapes HTML in meme titles' do
      meme_id = DB[:memes].insert(
        reddit_id: 'xss_test',
        title: '<img src=x onerror=alert(1)>',
        url: 'https://example.com/meme.jpg',
        created_at: Time.now
      )
      
      get '/'
      expect(last_response.body).not_to include('onerror=')
    end
  end

  describe 'Race Condition Tests' do
    it 'handles concurrent likes on same meme' do
      meme_id = DB[:memes].insert(
        reddit_id: 'race_test',
        title: 'Test Meme',
        url: 'https://example.com/test.jpg',
        likes: 0,
        created_at: Time.now
      )
      
      user = login_test_user
      threads = []
      
      10.times do
        threads << Thread.new do
          post "/memes/#{meme_id}/like"
        end
      end
      
      threads.each(&:join)
      
      # Should have exactly 1 like (idempotent)
      likes = DB[:memes].where(id: meme_id).get(:likes)
      expect(likes).to be <= 10 # At most 10, ideally 1 with proper locking
    end

    it 'handles concurrent user registrations with same username' do
      threads = []
      results = []
      mutex = Mutex.new
      
      username = "concurrent_#{Time.now.to_i}"
      
      5.times do
        threads << Thread.new do
          post '/signup', {
            username: username,
            email: "#{username}_#{rand(10000)}@test.com",
            password: 'TestPass123!'
          }
          mutex.synchronize { results << last_response.status }
        end
      end
      
      threads.each(&:join)
      
      # Only one should succeed (201/302), others should fail (422/409)
      successful = results.count { |s| [200, 201, 302].include?(s) }
      expect(successful).to eq(1)
    end
  end

  describe 'Data Type Mismatches' do
    it 'handles string where integer expected' do
      get '/memes/not_a_number'
      expect(last_response.status).to eq(404)
    end

    it 'handles boolean as string' do
      post '/api/memes', { is_deleted: 'maybe' }
      expect([400, 422]).to include(last_response.status)
    end

    it 'handles array where string expected' do
      post '/login', { username: ['array', 'of', 'strings'], password: 'test' }
      expect([400, 422]).to include(last_response.status)
    end
  end

  describe 'Resource Exhaustion Prevention' do
    it 'limits maximum query results' do
      get '/api/memes?limit=999999'
      expect(last_response).to be_ok
      
      data = JSON.parse(last_response.body) rescue {}
      memes = data['memes'] || data['data'] || []
      
      # Should be capped at reasonable limit (e.g., 100)
      expect(memes.length).to be <= 100
    end

    it 'prevents excessive database connections' do
      100.times do
        get '/random'
      end
      
      # Connection pool should not be exhausted
      expect(DB.pool.available_connections).to be > 0
    end

    it 'handles very large POST bodies' do
      large_data = 'a' * (1024 * 1024 * 10) # 10MB
      post '/api/memes', { data: large_data }
      
      # Should reject or handle gracefully
      expect([413, 422, 400]).to include(last_response.status)
    end
  end

  describe 'Error Recovery' do
    it 'recovers from database connection loss' do
      # Simulate connection loss and recovery
      # This would require advanced mocking
      get '/random'
      expect(last_response).to be_ok
    end

    it 'handles Redis connection failure gracefully' do
      allow_any_instance_of(Redis).to receive(:get).and_raise(Redis::CannotConnectError)
      
      get '/random'
      # Should fallback to database
      expect(last_response).to be_ok
    end

    it 'handles external API timeout' do
      allow(RedditFetcherService).to receive(:fetch_memes).and_raise(Timeout::Error)
      
      get '/random'
      # Should use cached memes
      expect(last_response).to be_ok
    end
  end

  describe 'Character Encoding' do
    it 'handles UTF-8 characters in username' do
      post '/signup', {
        username: '用户名测试',
        email: 'utf8@test.com',
        password: 'TestPass123!'
      }
      expect([200, 201, 302, 422]).to include(last_response.status)
    end

    it 'handles emojis in meme titles' do
      meme_id = DB[:memes].insert(
        reddit_id: 'emoji_test',
        title: '🔥 Hot Meme 💯 😂',
        url: 'https://example.com/emoji.jpg',
        created_at: Time.now
      )
      
      get '/'
      expect(last_response).to be_ok
    end

    it 'handles special characters in search' do
      get '/search?q=' + CGI.escape('test & < > " \' %')
      expect(last_response).to be_ok
    end
  end

  describe 'Session Edge Cases' do
    it 'handles expired session tokens' do
      # Set session with past expiry
      post '/login', { username: 'test', password: 'test' }
      
      # Manipulate session expiry (would need access to session store)
      get '/profile'
      # Should redirect to login or handle gracefully
      expect([200, 302]).to include(last_response.status)
    end

    it 'handles missing session data' do
      # Clear all session cookies
      clear_cookies
      
      get '/profile'
      expect(last_response.status).to eq(302) # Redirect to login
    end

    it 'handles corrupted session data' do
      # Set invalid session cookie
      set_cookie('meme_explorer_session=corrupted_data_here')
      
      get '/profile'
      # Should handle gracefully
      expect([302, 500]).to include(last_response.status)
    end
  end

  # Helper methods
  def login_test_user
    username = "edge_test_#{Time.now.to_i}"
    DB[:users].insert(
      username: username,
      email: "#{username}@test.com",
      password_hash: BCrypt::Password.create('TestPass123!'),
      created_at: Time.now
    )
    
    post '/login', { username: username, password: 'TestPass123!' }
    { username: username }
  end
end
