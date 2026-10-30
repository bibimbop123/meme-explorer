require 'spec_helper'

# BUG FIX: every "requires authentication" example in this file expected a
# bare 401 from an unauthenticated request, but AuthHelpers#require_auth!
# (lib/helpers/auth_helpers.rb) only returns a JSON 401 for XHR/JSON
# clients - a plain browser-style GET/POST with no such header gets
# redirected (302) to /login instead, by design, so real logged-out users
# see a login page rather than a raw 401. These specs were failing against
# correct, intentional behavior; not against a bug. Send an
# `X-Requested-With: XMLHttpRequest` header (the same signal a real fetch()/
# XHR call sends) to exercise the JSON-client branch these tests actually
# mean to test.
describe 'Profile Routes' do
  let(:user_id) { UserService.create_email_user('user@example.com', 'password123') }

  def xhr_headers
    { 'HTTP_X_REQUESTED_WITH' => 'XMLHttpRequest' }
  end

  describe 'GET /profile' do
    it 'requires authentication' do
      get '/profile', {}, xhr_headers
      expect(last_response.status).to eq(401)
    end

    it 'returns profile page for authenticated user' do
      session[:user_id] = user_id
      get '/profile'
      expect(last_response.status).to eq(200)
    end

    it 'enriches liked memes with title and subreddit from meme_stats when available' do
      session[:user_id] = user_id
      DB.execute("INSERT INTO meme_stats (url, title, subreddit, likes, views) VALUES (?, ?, ?, 5, 20)",
        ['https://i.redd.it/enriched-like.jpg', 'Hilarious Cat Meme', 'cats'])
      DB.execute("INSERT INTO user_liked_memes (user_id, meme_url) VALUES (?, ?)",
        [user_id, 'https://i.redd.it/enriched-like.jpg'])

      get '/profile'
      expect(last_response.status).to eq(200)
      expect(last_response.body).to include('Hilarious Cat Meme', 'r/cats')
    end

    it 'allows authenticated users to clear their unseen browsing history from profile' do
      session[:user_id] = user_id
      session[:feed_session_id] = SecureRandom.hex(32)
      MemeExplorer::ViewingHistoryService.mark_seen(session[:feed_session_id], 'https://i.redd.it/seen1.jpg')
      expect(MemeExplorer::ViewingHistoryService.seen_count(session[:feed_session_id])).to eq(1)

      post '/profile/clear-history'
      expect(last_response.status).to eq(303)
      expect(MemeExplorer::ViewingHistoryService.seen_count(session[:feed_session_id])).to eq(0)
    end

    it 'exports user account, saved memes, and liked memes as JSON' do
      session[:user_id] = user_id
      UserService.save_meme(user_id, 'https://i.redd.it/export-save.jpg', 'Exported Save', 'funny')
      DB.execute('INSERT INTO user_liked_memes (user_id, meme_url) VALUES (?, ?)', [user_id, 'https://i.redd.it/export-like.jpg'])

      get '/profile/export.json'
      expect(last_response.status).to eq(200)
      data = JSON.parse(last_response.body)
      expect(data['account']['id']).to eq(user_id)
      expect(data['saved_memes'].first['meme_url']).to eq('https://i.redd.it/export-save.jpg')
      expect(data['liked_memes'].first['meme_url']).to eq('https://i.redd.it/export-like.jpg')
    end

    it 'allows confirmed self-serve account deletion and anonymizes activity logs' do
      del_user = UserService.create_email_user('delete-me@example.com', 'password123')
      session[:user_id] = del_user
      UserService.save_meme(del_user, 'https://i.redd.it/del.jpg', 'Del', 'funny')
      DB.execute("INSERT INTO meme_activity_log (meme_url, activity_type, user_id) VALUES ('https://i.redd.it/del.jpg', 'view', ?)", [del_user])

      post '/profile/delete-account', { confirm_delete: 'nope' }
      expect(last_response.status).to eq(400)
      expect(UserService.find_by_id(del_user)).not_to be_nil

      post '/profile/delete-account', { confirm_delete: 'DELETE' }
      expect(last_response.status).to eq(303)
      expect(UserService.find_by_id(del_user)).to be_nil
      expect(UserService.get_saved_memes_count(del_user)).to eq(0)
      expect(DB.get_first_value('SELECT COUNT(*) FROM meme_activity_log WHERE user_id = ?', [del_user]).to_i).to eq(0)
    end

    it 'allows removing a liked meme directly from /profile/unlike' do
      session[:user_id] = user_id
      url = 'https://i.redd.it/unlike-from-profile.jpg'
      EngagementService.set_like(user_id: user_id, meme_url: url, desired: true, db: DB)
      expect(EngagementService.user_liked?(user_id: user_id, meme_url: url, db: DB)).to eq(true)

      post '/profile/unlike', { url: url, liked_page: '1', saved_page: '1' }
      expect(last_response.status).to eq(303)
      expect(EngagementService.user_liked?(user_id: user_id, meme_url: url, db: DB)).to eq(false)
    end

    it 'renders Your Top Communities on /profile when user has positive subreddit preferences' do
      session[:user_id] = user_id
      DB.execute(
        'INSERT INTO user_subreddit_preferences (user_id, subreddit, preference_score, times_liked) VALUES (?, ?, 1.8, 3)',
        [user_id, 'wholesomememes']
      )
      get '/profile'
      expect(last_response.status).to eq(200)
      expect(last_response.body).to include('Your Top Communities', 'r/wholesomememes', '/search?q=wholesomememes', 'Reset community boosts')

      post '/profile/reset-preferences'
      expect(last_response.status).to eq(303)
      expect(DB.get_first_value('SELECT COUNT(*) FROM user_subreddit_preferences WHERE user_id = ?', [user_id]).to_i).to eq(0)
      get '/profile'
      expect(last_response.body).to include('Your community feed preferences have been reset.')
    end

    it 'filters liked memes by title or community via liked_q search' do
      session[:user_id] = user_id
      DB.execute("INSERT INTO meme_stats (url, title, subreddit, likes, views) VALUES (?, ?, ?, 5, 20)",
        ['https://i.redd.it/like-cat.jpg', 'Purring Kitten', 'cats'])
      DB.execute("INSERT INTO meme_stats (url, title, subreddit, likes, views) VALUES (?, ?, ?, 5, 20)",
        ['https://i.redd.it/like-dog.jpg', 'Barking Puppy', 'dogs'])
      DB.execute('INSERT INTO user_liked_memes (user_id, meme_url) VALUES (?, ?)', [user_id, 'https://i.redd.it/like-cat.jpg'])
      DB.execute('INSERT INTO user_liked_memes (user_id, meme_url) VALUES (?, ?)', [user_id, 'https://i.redd.it/like-dog.jpg'])

      get '/profile', { liked_q: 'Purring' }
      expect(last_response.status).to eq(200)
      expect(last_response.body).to include('1 liked matches', 'Purring Kitten')
      expect(last_response.body).not_to include('Barking Puppy')
    end
  end

  describe 'POST /api/save-meme' do
    before { session[:user_id] = user_id }

    it 'requires authentication' do
      session.clear
      refresh_csrf_token
      post '/api/save-meme', { url: 'http://example.com/meme.jpg' }, xhr_headers
      expect(last_response.status).to eq(401)
    end

    it 'requires URL parameter' do
      post '/api/save-meme', { title: 'Test', subreddit: 'funny' }
      expect(last_response.status).to eq(400)
    end

    it 'saves meme for user' do
      post '/api/save-meme', { url: 'http://example.com/meme.jpg', title: 'Funny Meme', subreddit: 'funny' }
      expect(last_response.status).to eq(200)
      response_body = JSON.parse(last_response.body)
      expect(response_body['saved']).to eq(true)
    end

    it 'returns JSON response' do
      post '/api/save-meme', { url: 'http://example.com/meme.jpg', title: 'Test', subreddit: 'funny' }
      response_body = JSON.parse(last_response.body)
      expect(response_body).to include('saved', 'message')
    end
  end

  describe 'POST /api/unsave-meme' do
    before do
      session[:user_id] = user_id
      UserService.save_meme(user_id, 'http://example.com/meme.jpg', 'Test', 'funny')
    end

    it 'requires authentication' do
      session.clear
      refresh_csrf_token
      post '/api/unsave-meme', { url: 'http://example.com/meme.jpg' }, xhr_headers
      expect(last_response.status).to eq(401)
    end

    it 'removes saved meme' do
      post '/api/unsave-meme', { url: 'http://example.com/meme.jpg' }
      expect(last_response.status).to eq(200)
      response_body = JSON.parse(last_response.body)
      expect(response_body['unsaved']).to eq(true)
    end

    it 'restores a removed favorite with its metadata through the save endpoint' do
      url = 'http://example.com/meme.jpg'
      post '/api/unsave-meme', { url: url }
      expect(UserService.is_meme_saved?(user_id, url)).to be_nil
      post '/api/save-meme', { url: url, title: 'Restored title', subreddit: 'cats' }
      expect(JSON.parse(last_response.body)['saved']).to eq(true)
      row = DB.execute('SELECT meme_title, meme_subreddit FROM saved_memes WHERE user_id = ? AND meme_url = ?', [user_id, url]).first
      expect(row).to include('meme_title' => 'Restored title', 'meme_subreddit' => 'cats')
    end

    it 'handles missing URL' do
      post '/api/unsave-meme', { url: '' }
      expect(last_response.status).to eq(400)
    end

    it 'does not claim removal when persistence fails' do
      allow(EngagementService).to receive(:track_save).and_return(success: false)
      post '/api/unsave-meme', { url: 'http://example.com/meme.jpg' }
      data = JSON.parse(last_response.body)
      expect(data).to include('success' => false, 'unsaved' => false, 'message' => 'Could not remove meme')
      expect(UserService.is_meme_saved?(user_id, 'http://example.com/meme.jpg')).not_to be_nil
    end
  end

  describe 'GET /saved/:id' do
    before do
      # BUG FIX: this never logged in (no `session[:user_id] = user_id`),
      # so `require_auth!` in the real route correctly redirected (302) to
      # /login on every example - not a bug in the route, just a missing
      # setup step in this spec.
      session[:user_id] = user_id
      UserService.save_meme(user_id, 'http://example.com/meme.jpg', 'Saved Meme', 'funny')
      @saved_meme = DB.execute("SELECT id FROM saved_memes WHERE user_id = ? LIMIT 1", [user_id]).first
    end

    it 'returns saved meme page' do
      get "/saved/#{@saved_meme['id']}"
      expect(last_response.status).to eq(200)
    end

    it 'reflects persisted liked state on /saved/:id and links the subreddit to search' do
      EngagementService.set_like(user_id: user_id, meme_url: 'http://example.com/meme.jpg', desired: true, db: DB)
      get "/saved/#{@saved_meme['id']}"
      expect(last_response.status).to eq(200)
      expect(last_response.body).to include('Unlike', '/search?q=funny')
    end

    it 'returns 404 for non-existent saved meme' do
      get '/saved/99999'
      expect(last_response.status).to eq(404)
    end
  end

  describe 'GET /api/notifications' do
    before { session[:user_id] = user_id }

    it 'requires authentication' do
      session.clear
      get '/api/notifications', {}, xhr_headers
      expect(last_response.status).to eq(401)
    end

    it 'returns notification data as JSON' do
      get '/api/notifications'
      expect(last_response.status).to eq(200)
      response_body = JSON.parse(last_response.body)
      expect(response_body).to include('user_id', 'saved_count', 'timestamp')
    end

    it 'includes correct saved count' do
      3.times { |i| UserService.save_meme(user_id, "http://example.com/meme#{i}.jpg", "Meme #{i}", 'funny') }
      get '/api/notifications'
      response_body = JSON.parse(last_response.body)
      expect(response_body['saved_count']).to eq(3)
    end
  end
end
