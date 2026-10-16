require_relative '../spec_helper'

RSpec.describe 'Saved favorites search' do
  it 'matches titles and communities case-insensitively without exposing other accounts' do
    owner = create_test_user('search-owner@example.com')
    other = create_test_user('search-other@example.com')
    UserService.save_meme(owner, 'https://i.redd.it/cat.jpg', 'Sleepy CAT', 'funny')
    UserService.save_meme(owner, 'https://i.redd.it/dog.jpg', 'Good dog', 'wholesome')
    UserService.save_meme(other, 'https://i.redd.it/private.jpg', 'Private cat', 'funny')
    set_session(user_id: owner)
    get '/profile', saved_q: 'cat'
    expect(last_response.status).to eq(200)
    expect(last_response.body).to include('Sleepy CAT', '1 saved matches', '<strong>2</strong> memes saved')
    expect(last_response.body).not_to include('Good dog', 'Private cat')
    get '/profile', saved_q: 'WHOLESOME'
    expect(last_response.body).to include('Good dog')
    expect(last_response.body).not_to include('Sleepy CAT')
  end

  it 'uses literal matching and distinguishes no matches from an empty account' do
    owner = create_test_user('search-literal@example.com')
    UserService.save_meme(owner, 'https://i.redd.it/literal.jpg', '100%_fun', 'funny')
    set_session(user_id: owner)
    get '/profile', saved_q: '%_'
    expect(last_response.body).to include('100%_fun')
    get '/profile', saved_q: "' OR 1=1 --"
    expect(last_response.body).to include('No saved memes match this search', '0 saved matches')
    expect(last_response.body).not_to include('100%_fun', 'No saved memes yet')
  end

  it 'preserves a safe escaped search when opening and returning from a favorite' do
    owner = create_test_user('search-context@example.com')
    UserService.save_meme(owner, 'https://i.redd.it/context.jpg', 'Cats & dogs', 'funny')
    id = DB.execute('SELECT id FROM saved_memes WHERE user_id = ?', [owner]).first['id']
    set_session(user_id: owner)
    get '/profile', saved_q: 'Cats & dogs'
    expect(last_response.body).to include("/saved/#{id}?saved_page=1&amp;saved_q=Cats+%26+dogs")
    get "/saved/#{id}", saved_q: 'Cats & dogs', saved_page: '1'
    expect(last_response.body).to include("/profile?saved_page=1&amp;saved_q=Cats+%26+dogs#saved-card-#{id}")
    expect(last_response.body).to include('id="saved-media-recovery" hidden', 'id="retry-saved-media"', 'data-saved-media="available"')
    expect(last_response.body).not_to include('nextElementSibling')
  end

  it 'rejects oversized and structured query inputs' do
    set_session(user_id: create_test_user('search-invalid@example.com'))
    ['x' * 201, ['cats']].each do |query|
      get '/profile', saved_q: query
      expect(last_response.status).to eq(400)
    end
  end
end