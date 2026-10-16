require_relative '../spec_helper'

RSpec.describe 'Saved profile pagination' do
  it 'reaches older favorites with stable ordering and an account-wide count' do
    user_id = create_test_user('saved-pages@example.com')
    set_session(user_id: user_id)
    25.times do |index|
      DB.execute('INSERT INTO saved_memes (user_id, meme_url, meme_title, meme_subreddit, saved_at) VALUES (?, ?, ?, ?, ?)',
        [user_id, "https://i.redd.it/page#{index}.jpg", "Favorite #{index}", 'funny', '2026-01-01 00:00:00'])
    end
    get '/profile'
    expect(last_response.status).to eq(200)
    expect(last_response.body).to include('<strong>25</strong> memes saved', 'Favorite 24', 'Page 1 of 2', 'saved_page=2#saved-memes')
    expect(last_response.body).not_to include('Favorite 0<')
    get '/profile', saved_page: '999'
    expect(last_response.status).to eq(200)
    expect(last_response.body).to include('Favorite 0', 'Page 2 of 2', 'Previous favorites')
    expect(last_response.body).not_to include('More favorites', 'Favorite 24')
    path = last_response.body[/href="(\/saved\/[0-9]+\?saved_page=2)"/, 1]
    expect(path).not_to be_nil
    id = path[/\/saved\/([0-9]+)/, 1]
    get path
    expect(last_response.status).to eq(200)
    expect(last_response.body).to include("href=\"/profile?saved_page=2#saved-card-#{id}\"")
    get "/saved/#{id}", saved_page: '//evil.example'
    expect(last_response.body).to include("href=\"/profile?saved_page=1#saved-card-#{id}\"")
  end

  it 'does not include another account favorites in counts, pages or detail access' do
    owner = create_test_user('saved-owner@example.com')
    other = create_test_user('saved-other@example.com')
    UserService.save_meme(owner, 'https://i.redd.it/owned.jpg', 'Owned favorite', 'funny')
    UserService.save_meme(other, 'https://i.redd.it/private.jpg', 'Private other favorite', 'funny')
    other_id = DB.execute('SELECT id FROM saved_memes WHERE user_id = ?', [other]).first['id']
    set_session(user_id: owner)
    get '/profile'
    expect(last_response.body).to include('<strong>1</strong> memes saved', 'Owned favorite')
    expect(last_response.body).not_to include('Private other favorite', 'More favorites')
    get "/saved/#{other_id}"
    expect(last_response.status).to eq(404)
  end

  it 'shows a retryable Saved error when the total cannot be loaded' do
    set_session(user_id: create_test_user('saved-count-error@example.com'))
    allow(UserService).to receive(:get_saved_memes_count).and_raise(PG::ConnectionBad, 'private count failure')
    get '/profile', saved_page: '2'
    expect(last_response.status).to eq(200)
    expect(last_response.body).to include('could not load your saved memes', 'saved_page=2#saved-memes', '<strong>Unavailable</strong> memes saved')
    expect(last_response.body).not_to include('No saved memes yet', 'private count failure', 'aria-label="Saved meme pages"')
  end

  it 'rejects malformed or nonpositive pages' do
    set_session(user_id: create_test_user('invalid-saved-page@example.com'))
    ['0', '-1', '1oops', '1000000000'].each do |page|
      get '/profile', saved_page: page
      expect(last_response.status).to eq(400)
      expect(last_response.body).to include('Saved page must be a positive integer')
    end
  end
end