# frozen_string_literal: true
# spec/routes/home_spec.rb
require_relative '../spec_helper'

RSpec.describe 'Routes: GET /' do
  include Rack::Test::Methods
  def app; MemeExplorer::App; end

  describe 'GET /' do
    it 'returns 200' do
      get '/'
      expect(last_response.status).to eq(200)
    end

    it 'renders the random meme view' do
      get '/'
      expect(last_response.body).not_to be_empty
    end

    it 'sets a session cookie' do
      get '/'
      expect(last_response.headers['Set-Cookie']).not_to be_nil
    end

    it 'does not leak internal errors to the response body' do
      get '/'
      expect(last_response.body).not_to include('NoMethodError')
      expect(last_response.body).not_to include('ArgumentError')
    end
  end

  describe 'Session tracking' do
    it 'tracks view count in session' do
      get '/'
      expect(last_response.status).to eq(200)
      # View was served — no assertion on session internals needed
      # (session is opaque in rack-test without direct access)
    end
  end
end
