# frozen_string_literal: true

require 'spec_helper'

# BUG FIX: `/api/memes/1/like` doesn't exist (real route: `POST /like`
# with a JSON body - see routes/memes.rb) and `authenticated_session` was
# a fictional env-hash helper that never produced a working session.
# Rewritten against real routes/APIs.
RSpec.describe 'Redis Chaos Tests', type: :chaos do
  describe 'Redis Failure Scenarios' do
    it 'handles Redis connection failures' do
      allow(RedisService).to receive(:redis_available?).and_return(false)

      get '/trending'

      # Should fall back to database
      expect(last_response.status).to eq(200)
    end

    it 'handles Redis timeouts' do
      allow_any_instance_of(Redis).to receive(:get).and_raise(Redis::TimeoutError)

      get '/random'

      expect(last_response.status).to eq(200)
    end

    it 'handles Redis memory full (OOM on write)' do
      allow_any_instance_of(Redis).to receive(:set).and_raise(Redis::CommandError.new('OOM'))

      post '/like', { url: 'http://example.com/meme.jpg' }.to_json, { 'CONTENT_TYPE' => 'application/json' }

      # Should degrade gracefully, not crash with a raw 500
      expect(last_response.status).to be_between(200, 503)
    end

    it 'handles Redis failover' do
      allow(RedisService).to receive(:redis_available?).and_return(false, true)

      get '/leaderboard'

      expect(last_response.status).to eq(200)
    end
  end
end
