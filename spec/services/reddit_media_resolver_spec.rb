require_relative '../spec_helper'
require_relative '../../lib/services/reddit_media_resolver'

RSpec.describe RedditMediaResolver do
  it 'preserves GIF type and deepest parent attribution through nested crossposts' do
    parent = { 'url' => 'https://i.redd.it/animation.GIF?width=900', 'subreddit' => 'original' }
    nested = { 'subreddit' => 'middle', 'crosspost_parent_list' => [parent] }
    result = described_class.resolve({ 'crosspost_parent_list' => [nested] })
    expect(result).to include('media_type' => 'gif', 'original_subreddit' => 'original')
  end

  it 'normalizes website and crosspost media in the primary fetcher while retaining outer attribution' do
    posts = [
      { 'url' => 'https://example.com/article', 'title' => 'Website post', 'subreddit' => 'funny',
        'preview' => { 'images' => [{ 'source' => { 'url' => 'https://preview.redd.it/article.jpg' } }] } },
      { 'url' => 'https://reddit.com/comments/abc', 'title' => 'Shared post', 'subreddit' => 'cats',
        'crosspost_parent_list' => [{ 'url' => 'https://i.redd.it/parent.jpg', 'subreddit' => 'original' }] }
    ]
    result = RedditFetcherService.new.send(:parse_reddit_response, 'data' => { 'children' => posts.map { |post| { 'data' => post } } })
    expect(result.map { |m| m['url'] }).to eq(['https://preview.redd.it/article.jpg', 'https://i.redd.it/parent.jpg'])
    expect(result.last).to include('title' => 'Shared post', 'subreddit' => 'cats', 'original_subreddit' => 'original')
  end

  it 'resolves Imgur pages to direct images' do
    expect(described_class.resolve({ 'url' => 'https://imgur.com/Ab12' })['url']).to eq('https://i.imgur.com/Ab12.jpg')
  end

  it 'fails closed for missing, unsafe and cyclic media metadata' do
    [nil, {}, { 'url' => 'https://example.com/article' }, { 'url' => 'javascript:bad.jpg' },
     { 'preview' => { 'images' => ['bad', { 'source' => { 'url' => '//evil.example/a.jpg' } }] } }].each do |post|
      expect(described_class.resolve(post)).to be_nil
    end
    cyclic = {}; cyclic['crosspost_parent_list'] = [cyclic]
    expect(described_class.resolve(cyclic)).to be_nil
  end

  it 'resolves parent galleries while rejecting malformed and unsafe entries' do
    parent = { 'subreddit' => 'original', 'gallery_data' => { 'items' => [nil, { 'media_id' => 'one' }, { 'media_id' => 'bad' }] },
      'media_metadata' => { 'one' => { 's' => { 'u' => 'https://i.redd.it/one.png', 'x' => 800, 'y' => 1200 } }, 'bad' => { 's' => { 'u' => 'javascript:bad.jpg' } } } }
    media = described_class.resolve({ 'crosspost_parent_list' => [parent] })
    expect(media).to include('is_gallery' => true, 'is_crosspost' => true, 'url' => 'https://i.redd.it/one.png')
    expect(media['gallery_images'].size).to eq(1)
  end
end