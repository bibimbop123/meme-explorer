require_relative '../spec_helper'

RSpec.describe 'Like preference signal integrity' do
  it 'accepts explicit desired state retries and rejects nonboolean states' do
    set_session(user_id: create_test_user('desired-like@example.test'))
    url = 'https://example.com/desired-like.jpg'
    2.times do
      post '/like', { url: url, liked: true }.to_json, { 'CONTENT_TYPE' => 'application/json' }
      expect(last_response.status).to eq(200)
      expect(JSON.parse(last_response.body)).to include('liked' => true, 'likes' => 1)
    end
    post '/like', { url: url, liked: 'true' }.to_json, { 'CONTENT_TYPE' => 'application/json' }
    expect(last_response.status).to eq(400)
  end

  def toggle(url)
    post '/like', { url: url }.to_json, { 'CONTENT_TYPE' => 'application/json' }
    expect(last_response.status).to eq(200)
    body = JSON.parse(last_response.body)
    expect(body['success']).to be true
    body
  end

  it 'does not strengthen community preference by repeatedly toggling one meme' do
    user_id = create_test_user('like-signal@example.test')
    set_session(user_id: user_id)
    urls = %w[first second].map { |name| "https://example.com/#{name}-signal.jpg" }
    urls.each do |url|
      DB.execute('INSERT INTO meme_stats (url, title, subreddit, likes, views) VALUES (?, ?, ?, 0, 0)', [url, 'Signal fixture', 'funny'])
    end
    expect(toggle(urls.first)).to include('liked' => true, 'likes' => 1)
    3.times do
      expect(toggle(urls.first)).to include('liked' => false, 'likes' => 0)
      expect(toggle(urls.first)).to include('liked' => true, 'likes' => 1)
    end
    preference = DB.execute('SELECT preference_score, times_liked FROM user_subreddit_preferences WHERE user_id = ? AND subreddit = ?', [user_id, 'funny']).first
    expect(preference['preference_score'].to_f).to eq(1.0)
    expect(preference['times_liked'].to_i).to eq(1)
    expect(toggle(urls.last)).to include('liked' => true, 'likes' => 1)
    preference = DB.execute('SELECT preference_score, times_liked FROM user_subreddit_preferences WHERE user_id = ? AND subreddit = ?', [user_id, 'funny']).first
    expect(preference['preference_score'].to_f).to eq(1.2)
    expect(preference['times_liked'].to_i).to eq(2)
  end
end