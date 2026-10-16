require_relative '../spec_helper'

RSpec.describe 'Reddit helper fetching recovery' do
  let(:helper) { Object.new.extend(RedditMediaHelpers) }
  let(:endpoint) { 'https://www.reddit.com/r/funny/top.json?t=week&limit=45' }
  let(:post) { { 'url' => 'https://i.redd.it/test.jpg', 'title' => 'Fetched meme', 'subreddit' => 'funny', 'ups' => 7, 'permalink' => '/r/funny/comments/abc123/test/' } }

  before { allow(helper).to receive(:sleep) }

  def listing(posts)
    { 'data' => { 'children' => posts.map { |data| { 'data' => data } } } }.to_json
  end

  it 'enriches image posts while excluding videos, self posts and missing URLs' do
    stub_request(:get, endpoint).to_return(status: 200, body: listing([
      post.merge('preview' => { 'images' => [] }, 'thumbnail' => 'https://i.redd.it/thumb.jpg'),
      post.merge('is_video' => true), post.merge('is_self' => true), post.reject { |key, _| key == 'url' }
    ]))
    memes = helper.fetch_reddit_memes(['funny'])
    expect(memes.size).to eq(1)
    expect(memes.first).to include('title' => 'Fetched meme', 'likes' => 7, 'preview' => { 'images' => [] }, 'thumbnail' => 'https://i.redd.it/thumb.jpg')
    expect(a_request(:get, endpoint)).to have_been_made.once
  end

  it 'retries non-success responses and stops after a successful response' do
    stub_request(:get, endpoint).to_return({ status: 503 }, { status: 200, body: listing([post]) })
    expect(helper.fetch_reddit_memes(['funny']).size).to eq(1)
    expect(a_request(:get, endpoint)).to have_been_made.twice
  end

  it 'bounds retries for invalid JSON' do
    stub_request(:get, endpoint).to_return(status: 200, body: 'invalid JSON')
    expect(helper.fetch_reddit_memes(['funny'])).to eq([])
    expect(a_request(:get, endpoint)).to have_been_made.times(3)
  end

  it 'bounds network retries and continues to another community' do
    stub_request(:get, endpoint).to_raise(SocketError)
    cats = 'https://www.reddit.com/r/cats/top.json?t=week&limit=45'
    stub_request(:get, cats).to_return(status: 200, body: listing([post.merge('subreddit' => 'cats')]))
    expect(helper.fetch_reddit_memes(['funny', 'cats']).map { |meme| meme['subreddit'] }).to eq(['cats'])
    expect(a_request(:get, endpoint)).to have_been_made.times(3)
  end

  it 'converts Imgur post URLs and does not invent media for ordinary links' do
    expect(helper.extract_image_url('url' => 'https://imgur.com/Abc123')).to eq('https://i.imgur.com/Abc123.jpg')
    expect(helper.extract_image_url('url' => 'https://example.com/article')).to be_nil
    expect(helper.extract_image_url('url' => nil)).to be_nil
  end
end