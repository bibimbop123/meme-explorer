require_relative '../spec_helper'
require_relative '../../lib/services/api_cache_service'

RSpec.describe 'API cache HTTP fetching' do
  let(:service) { ApiCacheService }
  let(:post) do
    { 'url' => 'https://i.redd.it/cache.jpg', 'title' => 'Quality meme', 'subreddit' => 'funny',
      'domain' => 'i.redd.it', 'post_hint' => 'image', 'ups' => 200, 'upvote_ratio' => 0.9, 'num_comments' => 10 }
  end

  before do
    allow(service).to receive(:rate_limit_delay)
    allow(service).to receive(:sleep)
  end

  def listing(posts)
    { 'data' => { 'children' => posts.map { |data| { 'data' => data } } } }.to_json
  end

  [:authenticated, :unauthenticated].each do |strategy|
    context strategy.to_s do
      let(:endpoint) do
        strategy == :authenticated ? 'https://oauth.reddit.com/r/funny/hot?limit=25' : 'https://www.reddit.com/r/funny/hot.json?limit=25'
      end

      def fetch(strategy, communities = ['funny'])
        args = strategy == :authenticated ? ['test-token', communities, 25] : [communities, 25]
        service.send("fetch_reddit_memes_#{strategy}", *args)
      end

      it 'accepts quality media and excludes crossposts, self posts and low-quality content' do
        rejected = [{ 'is_crosspost' => true }, { 'crosspost_parent' => 'parent' },
          { 'crosspost_parent_list' => [{}] }, { 'num_crossposts' => 1 }, { 'is_self' => true },
          { 'post_hint' => 'rich:video' }, { 'domain' => 'example.com' }, { 'ups' => 1 },
          { 'upvote_ratio' => 0.1 }, { 'num_comments' => 0 }].map { |overrides| post.merge(overrides) }
        stub_request(:get, endpoint).to_return(status: 200, body: listing([post] + rejected), headers: { 'Content-Type' => 'application/json' })
        result = fetch(strategy)
        expect(result.size).to eq(1)
        expect(result.first).to include('title' => 'Quality meme', 'likes' => 200, 'is_video' => false)
      end

      it 'retains hosted video and gallery media metadata' do
        video = post.merge('is_video' => true, 'post_hint' => 'hosted:video', 'domain' => 'v.redd.it',
          'media' => { 'reddit_video' => { 'fallback_url' => 'https://v.redd.it/video.mp4' } })
        gallery = post.merge('is_gallery' => true, 'gallery_data' => { 'items' => [{ 'media_id' => 'first', 'caption' => 'Caption' }] },
          'media_metadata' => { 'first' => { 's' => { 'u' => 'https://i.redd.it/gallery.jpg?a=1&amp;b=2' } } })
        stub_request(:get, endpoint).to_return(status: 200, body: listing([video, gallery]), headers: { 'Content-Type' => 'application/json' })
        result = fetch(strategy)
        expect(result.first).to include('is_video' => true, 'url' => 'https://v.redd.it/video.mp4')
        expect(result.last['gallery_images'].first).to include('url' => 'https://i.redd.it/gallery.jpg?a=1&b=2', 'caption' => 'Caption')
      end

      it 'returns no content on malformed responses without leaking exceptions' do
        stub_request(:get, endpoint).to_return(status: 200, body: '{broken', headers: { 'Content-Type' => 'application/json' })
        expect(fetch(strategy)).to eq([])
      end

      it 'handles rate limiting with bounded requests' do
        stub_request(:get, endpoint).to_return(status: 429, headers: { 'Retry-After' => '2' })
        expect(fetch(strategy)).to eq([])
        expect(a_request(:get, endpoint)).to have_been_made.times(strategy == :authenticated ? 1 : 4)
        expect(service).to have_received(:sleep).at_least(:once)
      end

      it 'handles non-success and network errors without producing content' do
        stub_request(:get, endpoint).to_return(status: 503)
        expect(fetch(strategy)).to eq([])
        stub_request(:get, endpoint).to_raise(SocketError)
        expect(fetch(strategy)).to eq([])
      end
    end
  end
end