# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Redis Chaos Tests', type: :chaos do
  describe 'Redis Failure Scenarios' do
    it 'handles Redis connection failures' do
      allow(RedisService).to receive(:connection).and_raise(Redis::CannotConnectError)
      
      get '/trending'
      
      # Should fallback to database
      expect(last_response.status).to eq(200)
    end

    it 'handles Redis timeouts' do
      allow_any_instance_of(Redis).to receive(:get).and_raise(Redis::TimeoutError)
      
      get '/random'
      
      # Should handle gracefully
      expect(last_response.status).to eq(200)
    end

    it 'handles Redis memory full' do
      allow_any_instance_of(Redis).to receive(:set).and_raise(Redis::CommandError.new('OOM'))
      
      post '/api/memes/1/like', {}, authenticated_session
      
      # Should degrade gracefully
      expect(last_response.status).to be_between(200, 503)
    end

    it 'handles Redis failover' do
      # Simulate primary failure
      allow(RedisService).to receive(:connection).and_raise(Redis::CannotConnectError).once
      
      get '/leaderboard'
      
      # Should retry or fallback
      expect(last_response.status).to eq(200)
    end
  end
end
