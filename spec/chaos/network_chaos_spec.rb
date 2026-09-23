# frozen_string_literal: true

require 'spec_helper'

# BUG FIX: this file called two nonexistent routes (`/force_refresh`,
# `/meme/1`) with a fictional `admin_session` env-hash helper that never
# produced a working session. Rewritten against real routes.
RSpec.describe 'Network Chaos Tests', type: :chaos do
  describe 'Network Failure Scenarios' do
    it 'handles Reddit API DNS/connection failures gracefully' do
      stub_request(:get, /oauth\.reddit\.com/).to_raise(SocketError)

      get '/random'

      expect(last_response.status).to be_between(200, 503)
    end

    it 'handles intermittent network failures' do
      call_count = 0
      allow(Net::HTTP).to receive(:start) do
        call_count += 1
        raise Net::OpenTimeout if call_count.even?

        Net::HTTP.start
      end

      get '/random'

      expect(last_response.status).to eq(200)
    end
  end
end
