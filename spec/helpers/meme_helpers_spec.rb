require_relative '../spec_helper'

RSpec.describe MemeHelpers do
  let(:helper) { Object.new.extend(described_class) }

  it 'renders safe user-controlled video without autoplay or fabricated MIME type' do
    html = helper.render_video_player('url' => 'https://v.redd.it/a.webm?x=1&y=2', 'thumbnail_url' => '/images/poster.jpg?x=1&y=2')
    expect(html).to include('controls', 'preload="metadata"', 'a.webm?x=1&amp;y=2', 'poster="/images/poster.jpg?x=1&amp;y=2"')
    expect(html).not_to include('autoplay', 'type="video/mp4"')
  end

  it 'rejects unsafe video sources and omits unsafe posters' do
    [nil, {}, { 'url' => 'javascript:alert(1)' }, { 'url' => 'https://example.com/a.mp4" onerror="bad' }].each do |meme|
      expect(helper.render_video_player(meme)).to eq('')
    end
    expect(helper.render_video_player('url' => '/video.mp4', 'thumbnail_url' => 'javascript:bad')).not_to include('poster=')
  end

  it 'detects explicit media and video, gallery, animation and image inputs' do
    cases = [
      [{ 'media_type' => 'gallery' }, 'gallery'], [{ 'is_video' => true }, 'video'],
      [{ 'video_url' => '/video.mp4' }, 'video'], [{ 'is_reddit_video' => true }, 'video'],
      [{ 'url' => 'https://v.redd.it/abc' }, 'video'], [{ 'url' => 'https://redgifs.com/watch/a' }, 'video'],
      [{ 'url' => '/a.MOV?x=1' }, 'video'], [{ 'is_gallery' => true }, 'gallery'],
      [{ 'gallery_images' => [{}] }, 'gallery'], [{ 'url' => '/a.gif' }, 'gif'],
      [{ 'url' => '/a.gifv' }, 'gif'], [{ 'url' => '/a.jpg' }, 'image'], [nil, nil]
    ]
    cases.each { |meme, type| expect(helper.detect_media_type_comprehensive(meme)).to eq(type) }
  end

  it 'normalizes local paths without mutating source objects' do
    meme = { 'file' => '/images/a.jpg' }
    expect(helper.normalize_meme_paths(meme)).to eq('file' => 'images/a.jpg')
    expect(meme['file']).to eq('/images/a.jpg')
    expect(helper.meme_identifier('url' => '/api.jpg', 'file' => '/local.jpg')).to eq('/api.jpg')
    expect(helper.meme_identifier(nil)).to be_nil
  end

  it 'checks recent history and truthful placeholder flags' do
    expect(helper.recently_shown?({ 'url' => '/a.jpg' }, ['/a.jpg'])).to eq(true)
    expect(helper.recently_shown?({}, [])).to eq(false)
    expect(helper.recently_shown?(nil, nil)).to eq(false)
    expect(helper.placeholder_meme?('is_placeholder' => true)).to eq(true)
    expect(helper.placeholder_meme?(nil)).to eq(false)
    expect(helper.engagement_score('likes' => '3', 'views' => '8')).to eq(14)
  end
end