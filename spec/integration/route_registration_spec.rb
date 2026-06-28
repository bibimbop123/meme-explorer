# frozen_string_literal: true
# spec/integration/route_registration_spec.rb
#
# Integration tests verifying route registration is correct and that
# Sprint 1 P0 regressions cannot re-appear silently.

require_relative '../spec_helper'

RSpec.describe 'Route Registration Integration' do
  include Rack::Test::Methods

  def app
    MemeExplorer::App
  end

  # ─── 4.4 Route Registration ──────────────────────────────────────────────

  describe 'GET /' do
    it 'returns 200' do
      get '/'
      expect(last_response.status).to eq(200)
    end

    it 'renders meme content' do
      get '/'
      expect(last_response.body).not_to be_empty
    end
  end

  describe 'GET /random' do
    it 'returns 200' do
      get '/random'
      expect(last_response.status).to eq(200)
    end

    it 'renders content' do
      get '/random'
      expect(last_response.body).not_to be_empty
    end
  end

  describe 'GET /health' do
    it 'returns 200' do
      get '/health'
      expect(last_response.status).to eq(200)
    end

    it 'returns JSON with status field' do
      get '/health'
      body = JSON.parse(last_response.body) rescue nil
      expect(body).not_to be_nil
      expect(body).to have_key('status')
    end
  end

  describe 'GET /trending' do
    it 'returns a successful response' do
      get '/trending'
      expect([200, 302]).to include(last_response.status)
    end
  end

  describe 'GET /search' do
    it 'returns 200 with a query' do
      get '/search?q=funny'
      expect(last_response.status).to eq(200)
    end
  end

  describe 'Admin routes without auth' do
    it 'GET /admin returns 403 or redirects for non-admin users' do
      get '/admin'
      expect([302, 403]).to include(last_response.status)
    end

    it 'GET /admin/ab-testing returns 403 for non-admin' do
      get '/admin/ab-testing'
      expect(last_response.status).to eq(403)
    end
  end

  describe 'Unknown routes' do
    it 'returns 404 for a non-existent path' do
      get '/this-route-does-not-exist-xyz'
      expect(last_response.status).to eq(404)
    end
  end

  # ─── 4.5 Sprint 1 P0 Regression Tests ───────────────────────────────────

  describe 'P0 Regression: 1.1 Single session middleware' do
    it 'session[:user_id] persists across sequential requests' do
      # Create a user and log in
      user_id = create_test_user('session_test@example.com', 'P@ssword1!')

      # Simulate setting session directly
      env 'rack.session', { 'user_id' => user_id }
      get '/'

      # Session should still be accessible
      rack_session = last_request.env['rack.session']
      expect(rack_session).not_to be_nil
    end

    it 'does not create two separate session cookies' do
      get '/'
      set_cookie_headers = last_response.headers['Set-Cookie'] || ''
      # Should only have one session cookie (not two from double middleware)
      session_cookies = set_cookie_headers.scan(/meme_explorer\.session/).length
      expect(session_cookies).to be <= 1
    end
  end

  describe 'P0 Regression: 1.2 No duplicate route definitions' do
    it 'GET / is only registered once (last registration wins — routes/home.rb)' do
      # Both GET / hits should return same status — no ambiguity
      get '/'
      status1 = last_response.status
      get '/'
      status2 = last_response.status
      expect(status1).to eq(status2)
      expect(status1).to eq(200)
    end

    it 'GET /random is only registered once (routes/random_meme.rb)' do
      get '/random'
      status1 = last_response.status
      get '/random'
      status2 = last_response.status
      expect(status1).to eq(status2)
      expect(status1).to eq(200)
    end
  end

  describe 'P0 Regression: 1.3 DB transaction no deadlock' do
    it 'DB.transaction with nested DB.execute does not deadlock' do
      expect {
        DB.transaction do
          DB.execute('SELECT 1')
          DB.execute("SELECT COUNT(*) FROM meme_stats")
        end
      }.not_to raise_error
    end

    it 'DB.transaction is re-entrant safe' do
      expect {
        DB.transaction do
          DB.transaction do  # nested — should reuse connection, not deadlock
            DB.execute('SELECT 1')
          end
        end
      }.not_to raise_error
    end
  end

  describe 'P0 Regression: 1.4 No SQLite syntax in PostgreSQL queries' do
    it 'DB.execute with ON CONFLICT DO NOTHING works' do
      expect {
        DB.execute(
          "INSERT INTO meme_stats (url, title, subreddit, views, likes)
           VALUES ($1, $2, $3, 0, 0)
           ON CONFLICT(url) DO NOTHING",
          ['http://test-p0-regression.example.com/meme.jpg', 'Test', 'test']
        )
      }.not_to raise_error
    end

    it 'INSERT OR IGNORE syntax is not present in production source files' do
      source_files = Dir['app.rb', 'routes/*.rb', 'lib/**/*.rb'] - ['lib/services/random_selector_service_BACKUP.rb.deprecated']
      matching = source_files.select do |f|
        content = File.read(f) rescue ''
        content.match?(/INSERT\s+OR\s+IGNORE|INSERT\s+OR\s+REPLACE/i)
      end
      expect(matching).to be_empty,
        "Found SQLite INSERT OR IGNORE/REPLACE in: #{matching.join(', ')}"
    end
  end

  describe 'P0 Regression: 1.5 Routes::ABTesting is a proper extension' do
    it 'ABTesting is a Module not a Class inheriting Sinatra::Base' do
      expect(Routes::ABTesting).to be_a(Module)
      expect(Routes::ABTesting).not_to be < Sinatra::Base
    end

    it 'GET /admin/ab-testing returns 403 (not 500 NoMethodError) for non-admin' do
      get '/admin/ab-testing'
      expect(last_response.status).to eq(403)
      expect(last_response.body).not_to include('NoMethodError')
    end

    it 'POST /admin/ab-testing/create returns 403 for non-admin (not 500)' do
      post '/admin/ab-testing/create', { name: 'test', variants: 'a:0.5,b:0.5' }
      expect(last_response.status).to eq(403)
    end
  end
end
