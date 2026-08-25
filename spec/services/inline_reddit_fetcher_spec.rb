# frozen_string_literal: true

require_relative '../spec_helper'
require_relative '../../lib/services/inline_reddit_fetcher'

RSpec.describe InlineRedditFetcher do
  around do |example|
    original_id = ENV['REDDIT_CLIENT_ID']
    original_secret = ENV['REDDIT_CLIENT_SECRET']
    example.run
    ENV['REDDIT_CLIENT_ID'] = original_id
    ENV['REDDIT_CLIENT_SECRET'] = original_secret
  end

  describe '.fetch (private #fetch_oauth_token guard)' do
    # Regression test for the production incident (Aug 25, 2026) where
    # render.yaml set REDDIT_CLIENT_ID/SECRET via `value: ${REDDIT_CLIENT_ID}`,
    # which Render does NOT shell-interpolate - the app received the literal
    # placeholder string as a "configured" but garbage credential, silently
    # fell back to Reddit's unauthenticated (heavily rate-limited) endpoint,
    # and only ever served the 10-meme local fallback pool.
    it 'treats unresolved placeholder-style credentials as absent and does not attempt OAuth' do
      ENV['REDDIT_CLIENT_ID'] = '${REDDIT_CLIENT_ID}'
      ENV['REDDIT_CLIENT_SECRET'] = '${REDDIT_CLIENT_SECRET}'

      expect(Net::HTTP).not_to receive(:start)

      token = described_class.send(:fetch_oauth_token)
      expect(token).to be_nil
    end

    it 'returns nil when credentials are genuinely absent' do
      ENV['REDDIT_CLIENT_ID'] = ''
      ENV['REDDIT_CLIENT_SECRET'] = ''

      expect(described_class.send(:fetch_oauth_token)).to be_nil
    end

    it 'attempts OAuth when real-looking credentials are present' do
      ENV['REDDIT_CLIENT_ID'] = 'real_client_id'
      ENV['REDDIT_CLIENT_SECRET'] = 'real_client_secret'

      stub_request(:post, 'https://www.reddit.com/api/v1/access_token')
        .to_return(status: 200, body: { access_token: 'tok123', token_type: 'bearer', expires_in: 3600 }.to_json,
                   headers: { 'Content-Type' => 'application/json' })

      token = described_class.send(:fetch_oauth_token)
      expect(token).to eq('tok123')
    end
  end
end
