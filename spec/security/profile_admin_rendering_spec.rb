require_relative '../spec_helper'

RSpec.describe 'Stored content rendering boundaries' do
  it 'provides keyboard-accessible saved links that reopen the selected favorite' do
    user_id = create_test_user('saved-recovery@example.com')
    set_session(user_id: user_id)
    UserService.save_meme(user_id, 'https://i.redd.it/favorite.jpg', 'Recovered favorite', 'funny')
    get '/profile'
    path = last_response.body[/href="(\/saved\/[0-9]+)"/, 1]
    expect(path).not_to be_nil
    expect(last_response.body).not_to include("onclick=\"window.location.href='/saved/")
    get path
    expect(last_response.status).to eq(200)
    expect(last_response.body).to include('Recovered favorite', 'https://i.redd.it/favorite.jpg')
  end

  it 'explains account saving and offers discovery in the empty Saved state' do
    user_id = create_test_user('empty-saved@example.com')
    set_session(user_id: user_id)
    get '/profile'
    expect(last_response.body).to include('keep favorites in your account', 'Find a meme to save')
  end

  it 'escapes saved profile metadata and rejects executable media URLs' do
    user_id = create_test_user('render-profile@example.com')
    set_session(user_id: user_id)
    UserService.save_meme(user_id, 'javascript:alert(1)', '<script>stored-title</script>', '<img src=x onerror=alert(1)>')
    get '/profile'
    expect(last_response.status).to eq(200)
    expect(last_response.body).to include('&lt;script&gt;stored-title&lt;/script&gt;')
    expect(last_response.body).not_to include('<script>stored-title', 'src="javascript:')
  end

  it 'escapes admin titles and stores deletion URLs outside JavaScript source' do
    user_id = create_test_user('render-admin@example.com', 'SecurePass123!', true)
    set_session(user_id: user_id)
    url = "https://example.com/a');alert(1);//"
    DB.execute('INSERT INTO meme_stats (url, title, subreddit, views, likes) VALUES (?, ?, ?, 1, 1)',
      [url, '<script>admin-title</script>', '<img src=x>'])
    get '/admin'
    expect(last_response.status).to eq(200)
    expect(last_response.body).to include('&lt;script&gt;admin-title&lt;/script&gt;', 'data-delete-meme=')
    expect(last_response.body).not_to include('<script>admin-title', 'onclick="deleteMeme(')
  end

  it 'does not interpolate session liked URLs into a layout script' do
    session[:liked_memes] = ['</script><script>session-injection</script>']
    get '/login'
    expect(last_response.status).to eq(200)
    expect(last_response.body).not_to include('<script>session-injection</script>')
  end
end