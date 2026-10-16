require_relative '../spec_helper'
require_relative '../../lib/services/reddit_fetcher_service'

RSpec.describe 'Bounded Reddit listing pagination' do
  [:static, :oauth].each do |strategy|
    [:timeout, :server_error, :malformed_json].each do |failure|
      it "retains first-page #{strategy} media after #{failure}" do
        fetcher = RedditFetcherService.new(auth_strategy: strategy, access_token: 'test-token')
        allow(fetcher).to receive(:sleep)
        base = strategy == :oauth ? 'https://oauth.reddit.com/r/cats/top?t=week&limit=50' : 'https://www.reddit.com/r/cats/top.json?t=week&limit=50'
        post = { 'data' => { 'url' => 'https://i.redd.it/retained.jpg', 'title' => 'Retained', 'subreddit' => 'cats' } }
        stub_request(:get, base).to_return(body: { data: { children: [post], after: 't3_next' } }.to_json, headers: { 'Content-Type' => 'application/json' })
        second_page = stub_request(:get, "#{base}&after=t3_next")
        case failure
        when :timeout
          second_page.to_timeout
        when :server_error
          second_page.to_return(status: 503)
        when :malformed_json
          second_page.to_return(body: '{invalid', headers: { 'Content-Type' => 'application/json' })
        end
        expect(fetcher.fetch_memes(['cats'], pages: 2).map { |m| m['title'] }).to eq(['Retained'])
        expect(fetcher.rate_limited?).to eq(false)
      end
    end

    it "stops the entire #{strategy} batch on rate limiting while retaining fetched media" do
      fetcher = RedditFetcherService.new(auth_strategy: strategy, access_token: 'test-token')
      allow(fetcher).to receive(:sleep)
      base = strategy == :oauth ? 'https://oauth.reddit.com/r/cats/top?t=week&limit=50' : 'https://www.reddit.com/r/cats/top.json?t=week&limit=50'
      post = { 'data' => { 'url' => 'https://i.redd.it/retained.jpg', 'title' => 'Retained', 'subreddit' => 'cats' } }
      stub_request(:get, base).to_return(body: { data: { children: [post], after: 't3_next' } }.to_json, headers: { 'Content-Type' => 'application/json' })
      stub_request(:get, "#{base}&after=t3_next").to_return(status: 429)
      expect(fetcher.fetch_memes(['cats', 'funny'], pages: 2).map { |m| m['title'] }).to eq(['Retained'])
      expect(fetcher.rate_limited?).to eq(true)
      expect(fetcher.fetch_memes(['funny'], pages: 2)).to eq([])
      expect(a_request(:get, %r{/r/funny/})).not_to have_been_made
    end

    [nil, 'https://evil.example/cursor', 'bad cursor'].each do |cursor|
      it "stops #{strategy} pagination on cursor #{cursor.inspect}" do
        fetcher = RedditFetcherService.new(auth_strategy: strategy, access_token: 'test-token')
        allow(fetcher).to receive(:sleep)
        base = strategy == :oauth ? 'https://oauth.reddit.com/r/cats/top?t=week&limit=50' : 'https://www.reddit.com/r/cats/top.json?t=week&limit=50'
        stub_request(:get, base).to_return(body: { data: { children: [], after: cursor } }.to_json, headers: { 'Content-Type' => 'application/json' })
        expect(fetcher.fetch_memes(['cats'], pages: 2)).to eq([])
        expect(a_request(:get, base)).to have_been_made.once
      end
    end

    it "follows one cursor and deduplicates #{strategy} media" do
      fetcher = RedditFetcherService.new(auth_strategy: strategy, access_token: 'test-token')
      allow(fetcher).to receive(:sleep)
      base = strategy == :oauth ? 'https://oauth.reddit.com/r/cats/top?t=week&limit=50' : 'https://www.reddit.com/r/cats/top.json?t=week&limit=50'
      post = ->(id) { { 'data' => { 'url' => "https://i.redd.it/#{id}.jpg", 'title' => id, 'subreddit' => 'cats' } } }
      stub_request(:get, base).to_return(body: { data: { children: [post.call('first')], after: 't3_next' } }.to_json, headers: { 'Content-Type' => 'application/json' })
      stub_request(:get, "#{base}&after=t3_next").to_return(body: { data: { children: [post.call('first'), post.call('second')], after: 't3_more' } }.to_json, headers: { 'Content-Type' => 'application/json' })
      expect(fetcher.fetch_memes(['cats'], pages: 100).map { |m| m['title'] }).to eq(['first', 'second'])
      expect(a_request(:get, base)).to have_been_made.once
      expect(a_request(:get, "#{base}&after=t3_next")).to have_been_made.once
    end
  end

  it 'keeps default fetching single-page even with an available cursor' do
    fetcher = RedditFetcherService.new(auth_strategy: :static)
    allow(fetcher).to receive(:sleep)
    endpoint = 'https://www.reddit.com/r/cats/top.json?t=week&limit=50'
    stub_request(:get, endpoint).to_return(body: { data: { children: [], after: 't3_next' } }.to_json)
    expect(fetcher.fetch_memes(['cats'])).to eq([])
    expect(a_request(:get, endpoint)).to have_been_made.once
  end
end