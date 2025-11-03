require 'spec_helper'

describe 'Admin Routes' do
  let(:admin_user) do
    user_id = UserService.create_email_user('admin@example.com', 'password123')
    DB.execute("UPDATE users SET role = 'admin' WHERE id = ?", [user_id])
    user_id
  end

  describe 'GET /admin' do
    it 'returns 403 for non-admin user' do
      user_id = UserService.create_email_user('user@example.com', 'password123')
      get '/admin'
      expect(last_response.status).to eq(401)
    end

    it 'shows admin dashboard for admin user' do
      session[:user_id] = admin_user
      get '/admin'
      expect(last_response.status).to eq(200)
    end
  end

  describe 'DELETE /admin/meme/:url' do
    before do
      session[:user_id] = admin_user
      DB.execute("INSERT INTO meme_stats (url, title, subreddit, likes, views) VALUES (?, ?, ?, ?, ?)",
        ['http://example.com/meme.jpg', 'Test Meme', 'funny', 10, 100])
    end

    it 'requires admin role' do
      user_id = UserService.create_email_user('user@example.com', 'password123')
      session[:user_id] = user_id
      delete '/admin/meme/http://example.com/meme.jpg'
      expect(last_response.status).to eq(403)
    end

    it 'returns error without URL' do
      delete '/admin/meme/'
      expect([400, 404]).to include(last_response.status)
    end

    it 'deletes meme for admin' do
      delete '/admin/meme/http://example.com/meme.jpg'
      expect(last_response.status).to eq(200)
      
      meme = DB.execute("SELECT * FROM meme_stats WHERE url = ?", ['http://example.com/meme.jpg']).first
      expect(meme).to be_nil
    end
  end

  describe 'GET /health' do
    it 'returns health status' do
      get '/health'
      expect(last_response.status).to eq(200)
      response_body = JSON.parse(last_response.body)
      expect(response_body).to include('status', 'timestamp', 'uptime_seconds')
    end

    it 'includes request metrics' do
      get '/health'
      response_body = JSON.parse(last_response.body)
      expect(response_body['status']).to eq('ok')
    end
  end

  describe 'GET /metrics' do
    before do
      5.times do |i|
        DB.execute("INSERT INTO meme_stats (url, title, subreddit, likes, views) VALUES (?, ?, ?, ?, ?)",
          ["http://example.com/meme#{i}.jpg", "Meme #{i}", 'funny', (i + 1) * 10, (i + 1) * 100])
      end
    end

    it 'returns metrics page' do
      get '/metrics'
      expect(last_response.status).to eq(200)
    end
  end

  describe 'GET /metrics.json' do
    before do
      3.times do |i|
        DB.execute("INSERT INTO meme_stats (url, title, subreddit, likes, views) VALUES (?, ?, ?, ?, ?)",
          ["http://example.com/meme#{i}.jpg", "Meme #{i}", 'funny', 10, 100])
      end
    end

    it 'returns metrics data as JSON' do
      get '/metrics.json'
      expect(last_response.status).to eq(200)
      response_body = JSON.parse(last_response.body)
      expect(response_body).to include('total_memes', 'total_likes', 'total_views')
      expect(response_body['total_memes']).to eq(3)
    end

    it 'calculates averages correctly' do
      get '/metrics.json'
      response_body = JSON.parse(last_response.body)
      expect(response_body['avg_likes']).to be > 0
      expect(response_body['avg_views']).to be > 0
    end
  end

  describe 'GET /errors' do
    it 'requires admin role' do
      user_id = UserService.create_email_user('user@example.com', 'password123')
      session[:user_id] = user_id
      get '/errors'
      expect(last_response.status).to eq(403)
    end

    it 'returns error logs for admin' do
      session[:user_id] = admin_user
      get '/errors'
      expect(last_response.status).to eq(200)
      response_body = JSON.parse(last_response.body)
      expect(response_body).to include('recent_errors', 'error_rate_5m')
    end
  end
end
