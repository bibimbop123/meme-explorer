require_relative '../spec_helper'

RSpec.describe 'Account page cache boundaries' do
  it 'prevents caching authenticated profile and saved details, including missing records' do
    user_id = create_test_user('private-cache@example.com')
    set_session(user_id: user_id)
    UserService.save_meme(user_id, 'https://i.redd.it/private-cache.jpg', 'Private favorite', 'funny')
    id = DB.execute('SELECT id FROM saved_memes WHERE user_id = ?', [user_id]).first['id']
    { '/profile' => 200, "/saved/#{id}" => 200, '/saved/999999999' => 404 }.each do |path, expected|
      get path
      expect(last_response.status).to eq(expected)
      expect(last_response.headers['cache-control']).to include('no-store', 'private')
    end
  end

  it 'prevents caching authentication redirects for private pages' do
    ['/profile', '/saved/1'].each do |path|
      get path
      expect(last_response.status).to eq(302)
      expect(last_response.headers['cache-control']).to include('no-store', 'private')
    end
  end
end