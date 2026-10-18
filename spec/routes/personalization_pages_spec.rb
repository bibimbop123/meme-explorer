require_relative '../spec_helper'

RSpec.describe 'Personalization page compatibility' do
  %w[/saved /taste-evolution].each do |path|
    it "requires browser authentication for #{path}" do
      get path
      expect(last_response.status).to eq(302)
      expect(URI.parse(last_response.location).path).to eq('/login')
      expect(session[:return_to]).to eq(path)
    end

    it "requires JSON authentication for #{path}" do
      get path, {}, { 'HTTP_ACCEPT' => 'application/json' }
      expect(last_response.status).to eq(401)
      expect(JSON.parse(last_response.body)['error']).to eq('Authentication required')
    end
  end

  it 'redirects old favorites links to the implemented account favorites page' do
    user_id = create_test_user('favorites-alias@example.test')
    UserService.save_meme(user_id, '/images/favorite.jpg', 'My favorite', 'funny')
    set_session(user_id: user_id)
    get '/saved', { redirect: 'https://untrusted.example', user_id: 999 }
    expect(last_response.status).to eq(302)
    expect(URI.parse(last_response.location).path).to eq('/profile')
    expect(last_response.headers['cache-control']).to include('no-store')
    follow_redirect!
    expect(last_response.status).to eq(200)
    expect(last_response.body).to include('My favorite')
    expect(UserService.is_meme_saved?(user_id, '/images/favorite.jpg')).not_to be_nil
  end

  it 'explicitly retires unsupported taste insights without inventing a profile' do
    set_session(user_id: create_test_user('retired-taste@example.test'))
    get '/taste-evolution'
    expect(last_response.status).to eq(410)
    expect(last_response.headers['cache-control']).to include('no-store')
    expect(last_response.body).to include('Taste insights are unavailable', 'href="/profile"', 'href="/random"')
    expect(last_response.body).not_to include('taste maturity', 'Your taste evolution hasn', 'prediction-confidence')
  end
end