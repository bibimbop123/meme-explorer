# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Reddit API Contract Tests', type: :contract do
  describe 'OAuth Authentication' do
    it 'follows OAuth2 specification' do
      response = RestClient.post(
        'https://www.reddit.com/api/v1/access_token',
        {
          grant_type: 'client_credentials',
          device_id: 'test-device'
        },
        {
          'Authorization' => "Basic #{Base64.strict_encode64("#{ENV['REDDIT_CLIENT_ID']}:#{ENV['REDDIT_CLIENT_SECRET']}")}",
          'User-Agent' => 'MemeExplorer/1.0'
        }
      )
      
      data = JSON.parse(response.body)
      
      expect(data).to include('access_token')
      expect(data).to include('token_type')
      expect(data).to include('expires_in')
      expect(data['token_type']).to eq('bearer')
    end
  end

  describe 'Subreddit Listing' do
    it 'returns expected schema' do
      response = fetch_subreddit_posts('funny')
      data = JSON.parse(response.body)
      
      expect(data).to have_key('data')
      expect(data['data']).to have_key('children')
      expect(data['data']['children']).to be_an(Array)
      
      post = data['data']['children'].first['data']
      expect(post).to include('id', 'title', 'url', 'author', 'created_utc')
    end

    it 'respects pagination parameters' do
      response1 = fetch_subreddit_posts('memes', limit: 10)
      response2 = fetch_subreddit_posts('memes', limit: 25)
      
      data1 = JSON.parse(response1.body)['data']['children']
      data2 = JSON.parse(response2.body)['data']['children']
      
      expect(data1.size).to be <= 10
      expect(data2.size).to be <= 25
    end
  end

  describe 'Rate Limiting' do
    it 'includes rate limit headers' do
      response = fetch_subreddit_posts('pics')
      
      expect(response.headers).to include(:x_ratelimit_used)
      expect(response.headers).to include(:x_ratelimit_remaining)
      expect(response.headers).to include(:x_ratelimit_reset)
    end
  end

  describe 'Error Responses' do
    it 'returns proper error format' do
      # Invalid subreddit
      expect {
        fetch_subreddit_posts('thissubredditdoesnotexist12345')
      }.to raise_error do |error|
        expect(error.response.code).to be_between(400, 404)
      end
    end
  end

  private

  def fetch_subreddit_posts(subreddit, limit: 25)
    token = get_reddit_token
    
    RestClient.get(
      "https://oauth.reddit.com/r/#{subreddit}/hot.json",
      {
        params: { limit: limit },
        'Authorization' => "Bearer #{token}",
        'User-Agent' => 'MemeExplorer/1.0'
      }
    )
  end

  def get_reddit_token
    # Use cached token or fetch new one
    @token ||= RedditFetcherService.get_access_token
  end
end
