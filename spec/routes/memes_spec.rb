# frozen_string_literal: true

require_relative '../spec_helper'

RSpec.describe 'Routes: memes' do
  describe 'GET requests' do
    it 'returns successful response for valid requests' do
      # TODO: Add specific route tests
      pending "Add GET route tests"
    end
  end

  describe 'POST requests' do
    it 'handles POST requests correctly' do
      # TODO: Add POST route tests
      pending "Add POST route tests"
    end
  end

  describe 'authentication' do
    it 'requires authentication where needed' do
      # TODO: Add authentication tests
      pending "Add auth tests"
    end
  end

  describe 'error handling' do
    it 'handles 404 errors' do
      # TODO: Add 404 tests
      pending "Add error handling tests"
    end

    it 'handles 500 errors gracefully' do
      # TODO: Add 500 error tests
      pending "Add server error tests"
    end
  end

  describe 'GET /download' do
    it 'returns 400 when no url is given' do
      get '/download'
      expect(last_response.status).to eq(400)
    end

    it 'returns 403 for a host not on the allowlist' do
      get '/download', url: 'https://evil.example.com/malware.exe'
      expect(last_response.status).to eq(403)
    end

    it 'returns 403 for a non-http(s) URL (e.g. file:// or javascript:)' do
      get '/download', url: 'file:///etc/passwd'
      expect(last_response.status).to eq(403)
    end

    it 'proxies an allowed host and sets Content-Disposition: attachment' do
      stub_request(:get, 'https://i.redd.it/real_meme.jpg')
        .to_return(status: 200, body: 'fake-image-bytes', headers: { 'Content-Type' => 'image/jpeg' })

      get '/download', url: 'https://i.redd.it/real_meme.jpg'

      expect(last_response.status).to eq(200)
      expect(last_response.headers['Content-Disposition']).to include('attachment')
      expect(last_response.headers['Content-Disposition']).to include('.jpg')
      expect(last_response.headers['Content-Type']).to eq('image/jpeg')
      expect(last_response.body).to eq('fake-image-bytes')
    end

    it 'returns 502 when the upstream host fails' do
      stub_request(:get, 'https://i.redd.it/missing.jpg')
        .to_return(status: 404, body: 'not found')

      get '/download', url: 'https://i.redd.it/missing.jpg'
      expect(last_response.status).to eq(502)
    end

    it 'defaults to a .jpg extension when the URL has none' do
      stub_request(:get, 'https://i.redd.it/no_extension')
        .to_return(status: 200, body: 'bytes', headers: { 'Content-Type' => 'image/jpeg' })

      get '/download', url: 'https://i.redd.it/no_extension'

      expect(last_response.status).to eq(200)
      expect(last_response.headers['Content-Disposition']).to include('.jpg')
    end
  end
end
