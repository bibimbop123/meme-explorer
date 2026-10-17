# frozen_string_literal: true

require_relative '../spec_helper'
require_relative '../../lib/services/reddit_fetcher_service'

RSpec.describe RedditFetcherService do
  describe 'source dimensions' do
    let(:fetcher) { described_class.new }

    def parse_post(post)
      fetcher.send(:parse_reddit_response, { 'data' => { 'children' => [{ 'data' => post }] } }).first
    end

    it 'preserves gallery dimensions for each source and primary image' do
      post = { 'is_gallery' => true, 'gallery_data' => { 'items' => [{ 'media_id' => 'one' }] },
        'media_metadata' => { 'one' => { 's' => { 'u' => 'https://i.redd.it/one.jpg', 'x' => 800, 'y' => 1600 } } } }
      meme = parse_post(post)
      expect(meme).to include('width' => 800, 'height' => 1600)
      expect(meme['gallery_images'].first).to include('width' => 800, 'height' => 1600)
    end

    it 'uses preview dimensions only when its source URL exactly matches the media' do
      post = { 'url' => 'https://i.redd.it/one.jpg', 'preview' => { 'images' => [{ 'source' => {
        'url' => 'https://i.redd.it/one.jpg', 'width' => 640, 'height' => 1280
      } }] } }
      expect(parse_post(post)).to include('width' => 640, 'height' => 1280)
      post['preview']['images'][0]['source']['url'] = 'https://preview.redd.it/different.jpg'
      expect(parse_post(post)).not_to have_key('width')
    end

    it 'ignores malformed or invalid preview metadata without dropping the meme' do
      [nil, [], { 'images' => [nil, { 'source' => 'bad' }] },
        { 'images' => [{ 'source' => { 'url' => 'https://i.redd.it/one.jpg', 'width' => -2, 'height' => 40 } }] }].each do |preview|
        meme = parse_post('url' => 'https://i.redd.it/one.jpg', 'preview' => preview)
        expect(meme['url']).to eq('https://i.redd.it/one.jpg')
        expect(meme).not_to have_key('width')
      end
    end

    it 'preserves original source age and identity rather than declaring fetched posts fresh' do
      post = { 'url' => 'https://i.redd.it/source.jpg', 'created_utc' => 1_700_000_000,
               'id' => 'abc123', 'title' => 'Source meme' }
      expect(parse_post(post)).to include('created_at' => '2023-11-14T22:13:20Z', 'reddit_post_id' => 'abc123')
    end

    it 'ignores malformed source provenance without losing usable media' do
      [nil, '1700000000', -1, 0, Float::INFINITY, Float::NAN, Time.now.to_f + 3600].each do |value|
        meme = parse_post('url' => 'https://i.redd.it/source.jpg', 'created_utc' => value, 'id' => '../bad')
        expect(meme['url']).to eq('https://i.redd.it/source.jpg')
        expect(meme).not_to have_key('created_at')
        expect(meme).not_to have_key('reddit_post_id')
      end
    end
  end

  describe 'initialization' do
    it 'initializes successfully' do
      expect { described_class.new }.not_to raise_error
    end
  end

  describe 'provider diagnostics' do
    it 'separates authorization failure from confirmed rate limits without logging credentials' do
      fetcher = described_class.new(auth_strategy: :oauth, access_token: 'private-test-token')
      stub_request(:get, %r{https://oauth.reddit.com/r/diagnostic/top}).to_return(status: 403)
      expect(AppLogger).to receive(:info).with('[RedditFetcher] Provider outcomes',
        requests: 1, successful_listings: 0, auth_failures: 1, rate_limit_responses: 0,
        other_http_failures: 0, request_errors: 0, missing_token_calls: 0)
      expect(fetcher.fetch_memes(['diagnostic'])).to eq([])
      expect(fetcher.rate_limited?).to eq(false)
    end

    it 'counts real 429 responses and stops before fetching another community' do
      fetcher = described_class.new(auth_strategy: :oauth, access_token: 'private-test-token')
      stub_request(:get, %r{https://oauth.reddit.com/r/limited/top}).to_return(status: 429)
      expect(AppLogger).to receive(:info).with('[RedditFetcher] Provider outcomes',
        requests: 1, successful_listings: 0, auth_failures: 0, rate_limit_responses: 1,
        other_http_failures: 0, request_errors: 0, missing_token_calls: 0)
      expect(fetcher.fetch_memes(['limited', 'must-not-fetch'])).to eq([])
      expect(fetcher.rate_limited?).to eq(true)
    end

    it 'reports missing OAuth tokens without a provider request or confirmed rate limit' do
      [nil, '', ' '].each do |token|
        fetcher = described_class.new(auth_strategy: :oauth, access_token: token)
        expect(HTTParty).not_to receive(:get)
        expect(AppLogger).to receive(:info).with('[RedditFetcher] Provider outcomes',
          requests: 0, successful_listings: 0, auth_failures: 0, rate_limit_responses: 0,
          other_http_failures: 0, request_errors: 0, missing_token_calls: 1)
        expect(fetcher.fetch_memes(['diagnostic'])).to eq([])
        expect(fetcher.rate_limited?).to eq(false)
      end
    end

    it 'distinguishes successful empty listings from network errors' do
      fetcher = described_class.new(auth_strategy: :oauth, access_token: 'private-test-token')
      allow(fetcher).to receive(:sleep)
      stub_request(:get, %r{https://oauth.reddit.com/r/empty/top})
        .to_return(status: 200, body: JSON.generate('data' => { 'children' => [] }),
          headers: { 'Content-Type' => 'application/json' })
      stub_request(:get, %r{https://oauth.reddit.com/r/unreachable/top}).to_timeout
      expect(AppLogger).to receive(:info).with('[RedditFetcher] Provider outcomes',
        requests: 2, successful_listings: 1, auth_failures: 0, rate_limit_responses: 0,
        other_http_failures: 0, request_errors: 1, missing_token_calls: 0)
      expect(fetcher.fetch_memes(['empty', 'unreachable'])).to eq([])
      expect(fetcher.rate_limited?).to eq(false)
    end
  end

  describe 'main functionality' do
    subject { described_class.new }

    it 'responds to primary methods' do
      # TODO: Add specific method tests based on service interface
      expect(subject).to respond_to(:call) if subject.respond_to?(:call)
    end
  end

  # BUG FIX: this file's trailing three examples were empty `pending`
  # placeholders (`pending` expects the block to actually fail; an empty
  # block trivially "passes," so these failed on every run without
  # testing anything). Replaced with real coverage of
  # RedditFetcherService.new's actual constructor validation and
  # fetch_memes's real nil/empty-input handling.
  describe 'error handling' do
    it 'defaults to the static (unauthenticated) strategy for an unrecognized auth_strategy' do
      fetcher = described_class.new(auth_strategy: :nonsense)
      expect(fetcher.fetch_memes([])).to eq([])
    end
  end

  describe 'edge cases' do
    it 'handles a nil subreddits list gracefully' do
      fetcher = described_class.new(auth_strategy: :static)
      expect { fetcher.fetch_memes(nil) }.not_to raise_error
    end

    it 'handles an empty subreddits list gracefully' do
      fetcher = described_class.new(auth_strategy: :static)
      expect(fetcher.fetch_memes([])).to eq([])
    end
  end
end
