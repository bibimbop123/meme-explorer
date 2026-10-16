require_relative '../spec_helper'

RSpec.describe RedditMediaHelpers do
  let(:helper) { Object.new.extend(described_class) }

  it 'rejects unsafe direct image URLs and malformed gallery shapes without raising' do
    [nil, [], { 'url' => 'https://user:pass@example.com/a.jpg' },
     { 'url' => "https://example.com/a.jpg\n" },
     { 'url' => 'https://reddit.com/gallery/a', 'gallery_data' => { 'items' => ['invalid'] }, 'media_metadata' => 'invalid', 'preview' => { 'images' => [nil] } }].each do |post|
      expect(helper.extract_image_url(post)).to be_nil
    end
  end

  it 'uses a safe preview when gallery metadata is malformed and ignores executable previews' do
    post = { 'url' => 'https://reddit.com/gallery/a', 'gallery_data' => 'invalid',
      'preview' => { 'images' => [{ 'source' => { 'url' => 'javascript:bad.jpg' } },
        { 'source' => { 'url' => 'https://preview.redd.it/safe.PNG?width=900&amp;format=png' } }] } }
    expect(helper.extract_image_url(post)).to eq('https://preview.redd.it/safe.PNG?width=900&format=png')
  end

  it 'preserves preview source/resolution order, decodes entities and deduplicates thumbnails' do
    source = 'https://preview.redd.it/source.jpg?width=900&amp;format=jpg'
    small = 'https://preview.redd.it/small.jpg'
    meme = { 'preview' => { 'images' => [{ 'source' => { 'url' => source }, 'resolutions' => [{ 'url' => small }, { 'url' => small }] }] }, 'thumbnail' => small }
    expect(helper.extract_preview_images(meme)).to eq([source.gsub('&amp;', '&'), small])
  end

  it 'rejects malformed nested metadata and executable or credentialed candidates' do
    [nil, [], { 'preview' => 'invalid' }, { 'preview' => { 'images' => {} } }].each do |meme|
      expect(helper.extract_preview_images(meme)).to eq([])
    end
    meme = { 'preview' => { 'images' => [nil, 'invalid', {
      'source' => { 'url' => 42 },
      'resolutions' => [nil, { 'url' => 'javascript:alert(1)' }, { 'url' => 'https://user:pass@example.com/a.jpg' }, { 'url' => '/images/safe.jpg' }]
    }] }, 'thumbnail' => '//evil.example/a.jpg' }
    expect(helper.extract_preview_images(meme)).to eq(['/images/safe.jpg'])
  end

  it 'ignores Reddit sentinel thumbnails and supports valid thumbnail-only fallback' do
    %w[self default nsfw].each { |value| expect(helper.extract_preview_images('thumbnail' => value)).to eq([]) }
    expect(helper.extract_preview_images('thumbnail' => 'https://i.redd.it/thumb.jpg')).to eq(['https://i.redd.it/thumb.jpg'])
  end

  it 'detects video and animation extensions independently of query strings and case' do
    { 'https://v.redd.it/a.MP4?x=1' => 'video', '/a.webm#t=1' => 'video', '/a.mov' => 'video',
      '/a.GIF?x=1' => 'gif', '/a.gifv' => 'gif', '/a.jpg?name=video.mp4' => 'image', nil => 'image' }.each do |url, type|
      expect(helper.detect_media_type(url)).to eq(type)
    end
  end

  it 'chooses only category-appropriate local fallback images' do
    { 'aww' => 'wholesome', 'fitness' => 'selfcare', 'dankmemes' => 'dank', 'programming' => 'funny' }.each do |subreddit, category|
      expect(helper.get_category_fallback('subreddit' => subreddit)).to match(%r{\A/images/#{category}[1-3]\.jpeg\z})
    end
    expect(helper.get_category_fallback(nil)).to eq('/images/funny1.jpeg')
  end
end