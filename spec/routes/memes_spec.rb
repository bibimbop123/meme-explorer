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

  # ROADMAP.md Phase 1: real, new "skip" signal for personalization -
  # see lib/services/engagement_service.rb#track_skip for the full
  # rationale. This is the actual live route
  # public/js/modules/meme-navigation.js calls on every "next meme"
  # navigation.
  describe 'POST /api/skip-meme' do
    it 'records a skip for a logged-in user and decrements their preference' do
      hashed = BCrypt::Password.create("testpass123")
      DB.execute("INSERT INTO users (email, password_hash) VALUES (?, ?)", ["skip_route_1@example.com", hashed])
      user_id = DB.last_insert_row_id
      DB.execute(
        "INSERT INTO user_subreddit_preferences (user_id, subreddit, preference_score, times_liked) VALUES (?, ?, ?, ?)",
        [user_id, "funny", 1.5, 3]
      )
      set_session(user_id: user_id)

      post '/api/skip-meme', { subreddit: 'funny' }.to_json, { 'CONTENT_TYPE' => 'application/json' }

      expect(last_response.status).to eq(200)
      body = JSON.parse(last_response.body)
      expect(body['success']).to eq(true)
      expect(body['skipped']).to eq(true)

      pref = DB.execute("SELECT * FROM user_subreddit_preferences WHERE user_id = ? AND subreddit = ?", [user_id, "funny"]).first
      expect(pref["preference_score"].to_f).to be_within(0.001).of(1.45)
    end

    it 'returns success without tracking for an anonymous (no session) request' do
      post '/api/skip-meme', { subreddit: 'funny' }.to_json, { 'CONTENT_TYPE' => 'application/json' }

      expect(last_response.status).to eq(200)
      body = JSON.parse(last_response.body)
      expect(body['success']).to eq(true)
      expect(body['skipped']).to eq(false)
    end

    it 'accepts an optional dwell_ms field without error' do
      hashed = BCrypt::Password.create("testpass123")
      DB.execute("INSERT INTO users (email, password_hash) VALUES (?, ?)", ["skip_route_3@example.com", hashed])
      user_id = DB.last_insert_row_id
      set_session(user_id: user_id)

      post '/api/skip-meme', { subreddit: 'funny', dwell_ms: 1500 }.to_json, { 'CONTENT_TYPE' => 'application/json' }

      expect(last_response.status).to eq(200)
      body = JSON.parse(last_response.body)
      expect(body['success']).to eq(true)
    end

    it 'handles a malformed JSON body gracefully rather than 500ing' do
      hashed = BCrypt::Password.create("testpass123")
      DB.execute("INSERT INTO users (email, password_hash) VALUES (?, ?)", ["skip_route_2@example.com", hashed])
      user_id = DB.last_insert_row_id
      set_session(user_id: user_id)

      post '/api/skip-meme', 'not valid json', { 'CONTENT_TYPE' => 'application/json' }

      expect(last_response.status).to eq(200)
    end
  end
end
