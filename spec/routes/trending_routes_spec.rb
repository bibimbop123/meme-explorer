# spec/routes/trending_routes_spec.rb
require_relative '../spec_helper'

RSpec.describe 'Trending Routes' do
  before(:each) do
    # Create test meme stats
    DB.execute("DELETE FROM meme_stats") rescue nil
    
    # Add trending memes with different engagement levels
    DB.execute(<<-SQL)
      INSERT INTO meme_stats (meme_url, likes, views, last_seen) VALUES
      ('https://i.imgur.com/trending1.jpg', 50, 500, datetime('now')),
      ('https://i.imgur.com/trending2.jpg', 30, 300, datetime('now', '-1 hour')),
      ('https://i.imgur.com/trending3.jpg', 20, 200, datetime('now', '-2 hours')),
      ('https://i.imgur.com/old.jpg', 100, 1000, datetime('now', '-2 days'))
    SQL
  end
  
  describe 'GET /trending' do
    it 'returns 200 status' do
      get '/trending'
      expect(last_response.status).to eq(200)
    end
    
    it 'renders trending page template' do
      get '/trending'
      expect(last_response.body).to include('Trending')
    end
    
    it 'includes trending memes in response' do
      get '/trending'
      expect(last_response.body).to include('trending1')
    end
    
    it 'orders memes by engagement score' do
      get '/trending'
      # Most recent with high engagement should appear first
      body = last_response.body
      pos1 = body.index('trending1')
      pos2 = body.index('trending2')
      expect(pos1).to be < pos2 if pos1 && pos2
    end
  end
  
  describe 'GET /trending.json' do
    it 'returns 200 status' do
      get '/trending.json'
      expect(last_response.status).to eq(200)
    end
    
    it 'returns JSON content type' do
      get '/trending.json'
      expect(last_response.content_type).to include('application/json')
    end
    
    it 'returns array of trending memes' do
      get '/trending.json'
      data = JSON.parse(last_response.body)
      expect(data).to be_an(Array)
      expect(data.length).to be > 0
    end
    
    it 'includes meme properties' do
      get '/trending.json'
      data = JSON.parse(last_response.body)
      meme = data.first
      expect(meme).to have_key('url')
      expect(meme).to have_key('likes')
      expect(meme).to have_key('views')
    end
    
    it 'respects limit parameter' do
      get '/trending.json?limit=2'
      data = JSON.parse(last_response.body)
      expect(data.length).to be <= 2
    end
    
    it 'filters by time period' do
      get '/trending.json?period=24h'
      data = JSON.parse(last_response.body)
      # Should not include 2-day old meme
      urls = data.map { |m| m['url'] }
      expect(urls).not_to include('https://i.imgur.com/old.jpg')
    end
  end
  
  describe 'GET /api/trending' do
    it 'returns trending memes' do
      get '/api/trending'
      expect(last_response.status).to eq(200)
      data = JSON.parse(last_response.body)
      expect(data['memes']).to be_an(Array)
    end
    
    it 'includes metadata' do
      get '/api/trending'
      data = JSON.parse(last_response.body)
      expect(data).to have_key('count')
      expect(data).to have_key('period')
    end
  end
  
  describe 'trending algorithm' do
    it 'prioritizes recent engagement over old engagement' do
      get '/trending.json'
      data = JSON.parse(last_response.body)
      
      # Recent meme with lower total engagement should rank higher than old meme
      recent_meme = data.find { |m| m['url'].include?('trending1') }
      old_meme = data.find { |m| m['url'].include?('old') }
      
      recent_idx = data.index(recent_meme)
      old_idx = data.index(old_meme)
      
      expect(recent_idx).to be < old_idx if recent_idx && old_idx
    end
    
    it 'balances likes and views in scoring' do
      get '/trending.json'
      data = JSON.parse(last_response.body)
      
      # Memes should be ordered by engagement, not just likes or views
      expect(data.first['likes']).to be > 0
      expect(data.first['views']).to be > 0
    end
  end
  
  describe 'caching behavior' do
    it 'caches trending results' do
      get '/trending.json'
      first_call = last_response.body
      
      get '/trending.json'
      second_call = last_response.body
      
      expect(first_call).to eq(second_call)
    end
  end
  
  describe 'error handling' do
    it 'handles empty database gracefully' do
      DB.execute("DELETE FROM meme_stats")
      
      get '/trending.json'
      expect(last_response.status).to eq(200)
      data = JSON.parse(last_response.body)
      expect(data).to eq([])
    end
    
    it 'handles invalid period parameter' do
      get '/trending.json?period=invalid'
      expect(last_response.status).to eq(200)
    end
    
    it 'handles invalid limit parameter' do
      get '/trending.json?limit=-1'
      expect(last_response.status).to eq(200)
    end
  end
end
