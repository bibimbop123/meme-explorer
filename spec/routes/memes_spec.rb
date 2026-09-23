# frozen_string_literal: true

require_relative '../spec_helper'

# BUG FIX: this file used to also contain five empty placeholder examples
# (`pending "Add GET route tests"` etc., under "GET requests"/"POST
# requests"/"authentication"/"error handling" describe blocks) with no
# real assertions - `pending` in RSpec expects the block to actually
# fail; an empty block trivially "passes," and RSpec reports that
# mismatch as a failure ("Expected pending X to fail. No error was
# raised."), so these failed on every single run without ever testing
# anything. Real coverage for routes/memes.rb's GET/POST/auth/error-
# handling behavior already exists in spec/routes/memes_routes_spec.rb
# and spec/routes/like_spec.rb - removed these empty duplicates rather
# than leave permanently-red placeholder debt with zero test value.
RSpec.describe 'Routes: memes' do
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
