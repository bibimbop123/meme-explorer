# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Chaos Engineering Tests', type: :chaos do
  describe 'System Resilience' do
    it 'handles database connection failures gracefully' do
      # Simulate database failure
      allow_any_instance_of(SQLite3::Database).to receive(:execute).and_raise(SQLite3::BusyException)
      
      get '/'
      
      # Should return error page, not crash
      expect(last_response.status).to eq(503)
      expect(last_response.body).to include('temporarily unavailable')
    end

    it 'handles Redis connection failures' do
      # Simulate Redis failure
      allow(RedisService).to receive(:connection).and_raise(Redis::CannotConnectError)
      
      get '/random'
      
      # Should fallback to database
      expect(last_response.status).to eq(200)
    end

    it 'handles external API timeouts' do
      # Simulate Reddit API timeout
      stub_request(:get, /oauth.reddit.com/).to_timeout
      
      # Force cache refresh
      post '/force_refresh', {}, admin_session
      
      # Should handle gracefully
      expect(last_response.status).to be_between(200, 503)
    end

    it 'handles high memory pressure' do
      # Allocate large amount of memory
      large_array = Array.new(1000) { 'x' * 10_000 }
      
      get '/trending'
      
      # Should complete without crashing
      expect(last_response.status).to eq(200)
      
      # Cleanup
      large_array = nil
      GC.start
    end

    it 'handles concurrent requests' do
      threads = []
      results = []
      
      # Simulate 50 concurrent requests
      50.times do
        threads << Thread.new do
          get '/random'
          results << last_response.status
        end
      end
      
      threads.each(&:join)
      
      # Most requests should succeed
      success_rate = results.count(200) / results.size.to_f
      expect(success_rate).to be >= 0.8  # 80% success rate
    end

    it 'recovers from deadlocks' do
      # Simulate potential deadlock scenario
      Thread.new do
        get_db_connection.transaction do
          sleep 0.1
        end
      end
      
      sleep 0.05
      
      get '/profile/1'
      
      # Should not hang indefinitely
      expect(last_response.status).to be_between(200, 500)
    end

    it 'handles disk full scenarios' do
      # Simulate disk full
      allow(File).to receive(:write).and_raise(Errno::ENOSPC)
      
      post '/api/memes/1/like', {}, authenticated_session
      
      # Should handle gracefully
      expect(last_response.status).to eq(503)
      expect(json_response['error']).to include('storage')
    end

    it 'handles network partitions' do
      # Simulate network partition to Redis
      allow(RedisService).to receive(:connection).and_raise(Redis::TimeoutError)
      
      get '/leaderboard'
      
      # Should fallback to database
      expect(last_response.status).to eq(200)
    end
  end

  describe 'Data Consistency' do
    it 'maintains data integrity during failures' do
      # Start a transaction
      user_id = create_test_user
      initial_points = get_user_points(user_id)
      
      # Simulate failure mid-transaction
      allow_any_instance_of(SQLite3::Database).to receive(:execute)
        .and_call_original
        .once
        .and_raise(SQLite3::BusyException)
      
      # Attempt to award points
      post "/api/users/#{user_id}/award_points", { points: 100 }, admin_session rescue nil
      
      # Points should not be partially awarded
      final_points = get_user_points(user_id)
      expect(final_points).to eq(initial_points)
    end
  end

  describe 'Performance Degradation' do
    it 'maintains acceptable performance under load' do
      start_time = Time.now
      
      # Make 100 requests
      100.times { get '/random' }
      
      duration = Time.now - start_time
      avg_response_time = duration / 100
      
      # Average response time should be under 500ms even under load
      expect(avg_response_time).to be < 0.5
    end
  end

  # Helper methods
  def admin_session
    { 'rack.session' => { user_id: 1, admin: true } }
  end

  def authenticated_session
    { 'rack.session' => { user_id: 2 } }
  end

  def json_response
    JSON.parse(last_response.body)
  end

  def create_test_user
    db = get_db_connection
    db.execute(
      'INSERT INTO users (username, email, password_hash) VALUES (?, ?, ?)',
      ["test_#{SecureRandom.hex(4)}", "test@example.com", 'hash']
    )
    db.last_insert_row_id
  end

  def get_user_points(user_id)
    db = get_db_connection
    result = db.execute('SELECT points FROM users WHERE id = ?', [user_id]).first
    result ? result['points'] : 0
  end
end
