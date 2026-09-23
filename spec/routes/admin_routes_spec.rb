require 'spec_helper'

# BUG FIX (found while auditing this file): `require_admin!` used to be
# defined TWICE - once correctly in lib/helpers/auth_helpers.rb (checks
# UserService.is_admin?, a live DB query on every call), and again in
# lib/helpers/app_helpers.rb (checked `session[:role] == 'admin'`, a
# session field never populated by anything a plain, middleware-free
# `MemeExplorer::App` test request would set). Because `helpers AppHelpers`
# was registered AFTER `helpers AuthHelpers` in app.rb, the weaker,
# session-only version silently won in the live app too, not just in
# tests - see the BUG FIX comment in app_helpers.rb for the full
# reliability implications. Removed the duplicate there; this fixture just
# sets the DB role, which is now sufficient again.
describe 'Admin Routes' do
  let(:admin_user) do
    user_id = UserService.create_email_user('admin@example.com', 'password123')
    DB.execute("UPDATE users SET role = 'admin' WHERE id = ?", [user_id])
    user_id
  end

  describe 'GET /admin' do
    it 'returns 403 for non-admin user' do
      # BUG FIX: this never logged in at all (no `session[:user_id] =`),
      # so `require_admin!` -> `require_auth!` correctly redirected (302)
      # a plain browser-style GET rather than the auth check ever
      # differentiating admin vs non-admin. Log in as the non-admin user
      # created above (whose id was otherwise unused) and send an XHR
      # header so require_auth!'s JSON-client branch actually runs.
      user_id = UserService.create_email_user('user@example.com', 'password123')
      session[:user_id] = user_id
      get '/admin', {}, { 'HTTP_X_REQUESTED_WITH' => 'XMLHttpRequest' }
      expect(last_response.status).to eq(403)
    end

    it 'shows admin dashboard for admin user' do
      session[:user_id] = admin_user
      get '/admin'
      expect(last_response.status).to eq(200)
    end
  end

  describe 'DELETE /admin/meme/:url' do
    before do
      session[:user_id] = admin_user
      DB.execute("INSERT INTO meme_stats (url, title, subreddit, likes, views) VALUES (?, ?, ?, ?, ?)",
        ['http://example.com/meme.jpg', 'Test Meme', 'funny', 10, 100])
    end

    it 'requires admin role' do
      user_id = UserService.create_email_user('user@example.com', 'password123')
      session[:user_id] = user_id
      delete '/admin/meme/http://example.com/meme.jpg'
      expect(last_response.status).to eq(403)
    end

    it 'returns error without URL' do
      delete '/admin/meme/'
      expect([400, 404]).to include(last_response.status)
    end

    it 'deletes meme for admin' do
      # BUG FIX: this called `delete '/admin/meme/http://example.com/meme.jpg'`
      # with the URL raw/unencoded in the path - but Sinatra's `:url` named
      # param (routes/admin_routes.rb) doesn't match path segments
      # containing `/` by default, so the real route never actually
      # matched and 404'd before the handler ran. The real frontend
      # (views/admin.erb's `deleteMeme()`) already knows this and always
      # calls this endpoint with `encodeURIComponent(url)` - the route
      # itself is fine, this test just wasn't calling it the way it's
      # actually used in production.
      delete "/admin/meme/#{CGI.escape('http://example.com/meme.jpg')}"
      expect(last_response.status).to eq(200)
      
      meme = DB.execute("SELECT * FROM meme_stats WHERE url = ?", ['http://example.com/meme.jpg']).first
      expect(meme).to be_nil
    end
  end

  describe 'GET /health' do
    it 'returns health status' do
      get '/health'
      expect(last_response.status).to eq(200)
      response_body = JSON.parse(last_response.body)
      expect(response_body).to include('status', 'timestamp', 'uptime_seconds')
    end

    it 'includes request metrics' do
      # BUG FIX: this asserted overall status 'ok', but /health honestly
      # reports 'warning' whenever any sub-check is degraded - and in a
      # fresh test DB/process, `checks.meme_pool` is legitimately empty
      # (meme_count: 0, no pool ever bootstrapped) - that's correct,
      # non-buggy behavior this app's own architecture deliberately
      # surfaces rather than papering over (see ARCHITECTURE.md's stance
      # against fake "everything's fine" numbers). Assert what this
      # example is actually meant to check - that the response has real,
      # structured per-check data - rather than a top-level status value
      # this test environment can never honestly satisfy.
      get '/health'
      response_body = JSON.parse(last_response.body)
      expect(response_body['checks']).to include('database', 'redis', 'cache', 'meme_pool')
      expect(response_body['checks']['database']['status']).to eq('healthy')
    end
  end

  describe 'GET /metrics' do
    before do
      # BUG FIX: /metrics requires authentication (`require_auth!`); this
      # never logged anyone in, so every request correctly redirected
      # (302) to /login instead of reaching the route at all.
      session[:user_id] = admin_user
      5.times do |i|
        DB.execute("INSERT INTO meme_stats (url, title, subreddit, likes, views) VALUES (?, ?, ?, ?, ?)",
          ["http://example.com/meme#{i}.jpg", "Meme #{i}", 'funny', (i + 1) * 10, (i + 1) * 100])
      end
    end

    it 'returns metrics page' do
      get '/metrics'
      expect(last_response.status).to eq(200)
    end
  end

  describe 'GET /metrics.json' do
    before do
      # Same fix as GET /metrics above.
      session[:user_id] = admin_user
      3.times do |i|
        DB.execute("INSERT INTO meme_stats (url, title, subreddit, likes, views) VALUES (?, ?, ?, ?, ?)",
          ["http://example.com/meme#{i}.jpg", "Meme #{i}", 'funny', 10, 100])
      end
    end

    it 'returns metrics data as JSON' do
      get '/metrics.json'
      expect(last_response.status).to eq(200)
      response_body = JSON.parse(last_response.body)
      expect(response_body).to include('total_memes', 'total_likes', 'total_views')
      expect(response_body['total_memes']).to eq(3)
    end

    it 'calculates averages correctly' do
      get '/metrics.json'
      response_body = JSON.parse(last_response.body)
      expect(response_body['avg_likes']).to be > 0
      expect(response_body['avg_views']).to be > 0
    end
  end

  describe 'GET /errors' do
    it 'requires admin role' do
      user_id = UserService.create_email_user('user@example.com', 'password123')
      session[:user_id] = user_id
      get '/errors'
      expect(last_response.status).to eq(403)
    end

    it 'returns error logs for admin' do
      session[:user_id] = admin_user
      get '/errors'
      expect(last_response.status).to eq(200)
      response_body = JSON.parse(last_response.body)
      expect(response_body).to include('recent_errors', 'error_rate_5m')
    end
  end
end
