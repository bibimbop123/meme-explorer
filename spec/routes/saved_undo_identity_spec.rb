require_relative '../spec_helper'

RSpec.describe 'Restored Saved detail identity' do
  it 'returns the current account-owned ID after removal and restoration' do
    owner = create_test_user('undo-identity@example.test')
    other = create_test_user('undo-other@example.test')
    url = 'https://i.redd.it/undo-identity.jpg'
    UserService.save_meme(owner, url, 'Restored identity', 'cats')
    UserService.save_meme(other, url, 'Other account', 'cats')
    original_id = UserService.is_meme_saved?(owner, url)['id'].to_i
    set_session(user_id: owner)
    post '/api/unsave-meme', url: url
    post '/api/save-meme', url: url, title: 'Restored identity', subreddit: 'cats'
    response = JSON.parse(last_response.body)
    expect(response).to include('success' => true, 'saved' => true)
    expect(response['saved_id']).to eq(UserService.is_meme_saved?(owner, url)['id'].to_i)
    expect(response['saved_id']).not_to eq(original_id)
    expect(response['saved_id']).not_to eq(UserService.is_meme_saved?(other, url)['id'].to_i)
    get "/saved/#{response['saved_id']}"
    expect(last_response.status).to eq(200)
    expect(last_response.body).to include('Restored identity')
  end
end