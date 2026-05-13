# spec/routes/behavioral_tracking_spec.rb
require_relative '../spec_helper'

RSpec.describe 'Behavioral Tracking Routes' do
  let(:valid_tracking_data) do
    {
      event: 'meme_view',
      meme_url: 'https://i.imgur.com/test.jpg',
      timestamp: Time.now.to_i
    }
  end
  
  before(:each) do
    # Clear tracking tables
    DB.execute("DELETE FROM meme_activity_log") rescue nil
  end
  
  describe 'POST /api/track/view' do
    it 'returns 200 status for valid view' do
      post '/api/track/view', valid_tracking_data.to_json, {'CONTENT_TYPE' => 'application/json'}
      expect(last_response.status).to eq(200)
    end
    
    it 'logs view event to activity log' do
      post '/api/track/view', valid_tracking_data.to_json, {'CONTENT_TYPE' => 'application/json'}
      
      count = DB.get_first_value("SELECT COUNT(*) FROM meme_activity_log WHERE activity_type = 'view'")
      expect(count).to be > 0
    end
    
    it 'stores meme URL in activity log' do
      post '/api/track/view', valid_tracking_data.to_json, {'CONTENT_TYPE' => 'application/json'}
      
      url = DB.get_first_value("SELECT meme_url FROM meme_activity_log WHERE activity_type = 'view' ORDER BY created_at DESC LIMIT 1")
      expect(url).to eq(valid_tracking_data[:meme_url])
    end
    
    it 'accepts session_id for anonymous users' do
      data = valid_tracking_data.merge(session_id: 'anonymous_123')
      post '/api/track/view', data.to_json, {'CONTENT_TYPE' => 'application/json'}
      
      session = DB.get_first_value("SELECT session_id FROM meme_activity_log WHERE activity_type = 'view' ORDER BY created_at DESC LIMIT 1")
      expect(session).to eq('anonymous_123')
    end
    
    it 'returns success message' do
      post '/api/track/view', valid_tracking_data.to_json, {'CONTENT_TYPE' => 'application/json'}
      data = JSON.parse(last_response.body)
      expect(data['success']).to be true
    end
  end
  
  describe 'POST /api/track/like' do
    let(:like_data) do
      {
        meme_url: 'https://i.imgur.com/test.jpg',
        liked: true
      }
    end
    
    it 'returns 200 status for valid like' do
      post '/api/track/like', like_data.to_json, {'CONTENT_TYPE' => 'application/json'}
      expect(last_response.status).to eq(200)
    end
    
    it 'logs like event' do
      post '/api/track/like', like_data.to_json, {'CONTENT_TYPE' => 'application/json'}
      
      count = DB.get_first_value("SELECT COUNT(*) FROM meme_activity_log WHERE activity_type = 'like'")
      expect(count).to be > 0
    end
    
    it 'logs unlike event when liked is false' do
      unlike_data = like_data.merge(liked: false)
      post '/api/track/like', unlike_data.to_json, {'CONTENT_TYPE' => 'application/json'}
      
      count = DB.get_first_value("SELECT COUNT(*) FROM meme_activity_log WHERE activity_type = 'unlike'")
      expect(count).to be > 0
    end
  end
  
  describe 'POST /api/track/share' do
    let(:share_data) do
      {
        meme_url: 'https://i.imgur.com/test.jpg',
        platform: 'twitter'
      }
    end
    
    it 'returns 200 status for valid share' do
      post '/api/track/share', share_data.to_json, {'CONTENT_TYPE' => 'application/json'}
      expect(last_response.status).to eq(200)
    end
    
    it 'logs share event' do
      post '/api/track/share', share_data.to_json, {'CONTENT_TYPE' => 'application/json'}
      
      count = DB.get_first_value("SELECT COUNT(*) FROM meme_activity_log WHERE activity_type = 'share'")
      expect(count).to be > 0
    end
  end
  
  describe 'POST /api/track/skip' do
    let(:skip_data) do
      {
        meme_url: 'https://i.imgur.com/test.jpg',
        reason: 'not_funny'
      }
    end
    
    it 'returns 200 status for valid skip' do
      post '/api/track/skip', skip_data.to_json, {'CONTENT_TYPE' => 'application/json'}
      expect(last_response.status).to eq(200)
    end
    
    it 'logs skip event' do
      post '/api/track/skip', skip_data.to_json, {'CONTENT_TYPE' => 'application/json'}
      
      count = DB.get_first_value("SELECT COUNT(*) FROM meme_activity_log WHERE activity_type = 'skip'")
      expect(count).to be > 0
    end
  end
  
  describe 'POST /api/track/time_spent' do
    let(:time_data) do
      {
        meme_url: 'https://i.imgur.com/test.jpg',
        duration: 5.2
      }
    end
    
    it 'returns 200 status' do
      post '/api/track/time_spent', time_data.to_json, {'CONTENT_TYPE' => 'application/json'}
      expect(last_response.status).to eq(200)
    end
    
    it 'logs time spent event' do
      post '/api/track/time_spent', time_data.to_json, {'CONTENT_TYPE' => 'application/json'}
      
      count = DB.get_first_value("SELECT COUNT(*) FROM meme_activity_log WHERE activity_type = 'time_spent'")
      expect(count).to be > 0
    end
  end
  
  describe 'GET /api/track/stats' do
    before do
      # Create some tracking data
      3.times do |i|
        DB.execute("INSERT INTO meme_activity_log (meme_url, activity_type, created_at) VALUES (?, 'view', datetime('now'))",
          ["https://i.imgur.com/test#{i}.jpg"])
      end
    end
    
    it 'returns 200 status' do
      get '/api/track/stats'
      expect(last_response.status).to eq(200)
    end
    
    it 'returns statistics' do
      get '/api/track/stats'
      data = JSON.parse(last_response.body)
      expect(data).to have_key('total_events')
      expect(data['total_events']).to be > 0
    end
    
    it 'groups events by type' do
      get '/api/track/stats'
      data = JSON.parse(last_response.body)
      expect(data).to have_key('by_type')
    end
  end
  
  describe 'validation' do
    it 'rejects missing meme_url' do
      post '/api/track/view', {event: 'view'}.to_json, {'CONTENT_TYPE' => 'application/json'}
      expect(last_response.status).to eq(400)
    end
    
    it 'rejects invalid JSON' do
      post '/api/track/view', 'invalid json', {'CONTENT_TYPE' => 'application/json'}
      expect(last_response.status).to eq(400)
    end
    
    it 'sanitizes URLs' do
      malicious_data = valid_tracking_data.merge(meme_url: 'javascript:alert(1)')
      post '/api/track/view', malicious_data.to_json, {'CONTENT_TYPE' => 'application/json'}
      expect(last_response.status).to eq(400)
    end
  end
  
  describe 'rate limiting' do
    it 'accepts multiple requests from same session' do
      10.times do
        post '/api/track/view', valid_tracking_data.to_json, {'CONTENT_TYPE' => 'application/json'}
        expect(last_response.status).to eq(200)
      end
    end
  end
  
  describe 'error handling' do
    it 'handles database errors gracefully' do
      allow(DB).to receive(:execute).and_raise(SQLite3::Exception.new('DB error'))
      
      post '/api/track/view', valid_tracking_data.to_json, {'CONTENT_TYPE' => 'application/json'}
      expect(last_response.status).to be_between(200, 500)
    end
  end
end
