# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Network Chaos Tests', type: :chaos do
  describe 'Network Failure Scenarios' do
    it 'handles DNS resolution failures' do
      allow(Resolv).to receive(:getaddress).and_raise(Resolv::ResolvError)
      
      post '/force_refresh', {}, admin_session
      
      expect(last_response.status).to be_between(200, 503)
    end

    it 'handles intermittent network failures' do
      # Simulate 50% packet loss
      call_count = 0
      allow(Net::HTTP).to receive(:start) do
        call_count += 1
        raise Net::OpenTimeout if call_count.even?
        Net::HTTP.start
      end
      
      get '/random'
      
      expect(last_response.status).to eq(200)
    end

    it 'handles CDN failures' do
      # Simulate CDN unavailability
      stub_request(:get, /cdn.example.com/).to_return(status: 503)
      
      get '/meme/1'
      
      # Should fallback to direct links
      expect(last_response.status).to eq(200)
    end
  end
end
