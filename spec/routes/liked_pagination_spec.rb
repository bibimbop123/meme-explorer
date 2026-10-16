require_relative '../spec_helper'

RSpec.describe 'Liked profile pagination' do
  it 'reaches old likes with stable ordering, account-wide totals and bounded pages' do
    user_id = create_test_user('likes-pages@example.com')
    set_session(user_id: user_id)
    51.times do |index|
      DB.execute('INSERT INTO user_liked_memes (user_id, meme_url, created_at) VALUES (?, ?, ?)',
        [user_id, "https://i.redd.it/liked-page-#{index}.jpg", '2026-01-01 00:00:00'])
    end
    get '/profile'
    expect(last_response.status).to eq(200)
    expect(last_response.body).to include('<strong>51</strong> memes liked', 'Likes page 1 of 3', 'liked-page-50.jpg', 'liked_page=2#liked-memes')
    expect(last_response.body).not_to include('liked-page-0.jpg')
    get '/profile', liked_page: '999'
    expect(last_response.body).to include('Likes page 3 of 3', 'liked-page-0.jpg', 'Previous likes')
    expect(last_response.body).not_to include('More likes', 'liked-page-50.jpg')
  end

  it 'does not expose another account likes' do
    owner = create_test_user('likes-owner@example.com')
    other = create_test_user('likes-other@example.com')
    DB.execute('INSERT INTO user_liked_memes (user_id, meme_url) VALUES (?, ?)', [other, 'https://i.redd.it/private-like.jpg'])
    set_session(user_id: owner)
    get '/profile'
    expect(last_response.body).to include('<strong>0</strong> memes liked', 'No liked memes yet')
    expect(last_response.body).not_to include('private-like.jpg', 'Liked meme pages')
  end

  it 'rejects malformed and nonpositive likes pages' do
    set_session(user_id: create_test_user('likes-invalid@example.com'))
    ['0', '-1', '1oops', '1000000000'].each do |page|
      get '/profile', liked_page: page
      expect(last_response.status).to eq(400)
      expect(last_response.body).to include('Likes page must be a positive integer')
    end
  end

  it 'offers a retry rather than an empty-state claim when likes cannot load' do
    set_session(user_id: create_test_user('likes-error@example.com'))
    allow(MemeExplorer::App::DB).to receive(:execute).and_call_original
    allow(MemeExplorer::App::DB).to receive(:execute).with('SELECT COUNT(*) AS count FROM user_liked_memes WHERE user_id = ?', anything).and_raise(PG::ConnectionBad, 'private failure')
    get '/profile', liked_page: '2'
    expect(last_response.status).to eq(200)
    expect(last_response.body).to include('could not load your liked memes', 'liked_page=2#liked-memes', '<strong>Unavailable</strong> memes liked')
    expect(last_response.body).not_to include('No liked memes yet', 'private failure', 'aria-label="Liked meme pages"')
  end
end