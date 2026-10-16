require_relative '../spec_helper'
require_relative '../../lib/security/media_url'

RSpec.describe 'Media rendering safety and fallback contracts' do
  let(:gallery) { Object.new.extend(GalleryHelpers) }
  let(:reddit) { Object.new.extend(RedditMediaHelpers) }
  let(:renderer) { SmartMediaRendererService }

  it 'allows HTTP(S) and local absolute paths but rejects executable and ambiguous URLs' do
    ['https://i.redd.it/meme.jpg?a=1&b=2', 'http://i.imgur.com/a.gif', '/images/funny1.jpeg'].each do |url|
      expect(MediaUrl.safe(url)).to eq(url)
    end
    ['javascript:alert(1)', 'data:image/svg+xml,test', '//attacker.example/a', '/\\attacker/a', "https://x/a\n", 'https://user:pass@example.com/a', 'https://x/"bad', nil, 123].each do |url|
      expect(MediaUrl.safe(url)).to be_nil
    end
  end

  it 'escapes gallery titles and captions and rejects dangerous image sources' do
    html = gallery.render_gallery_carousel([
      { 'url' => 'javascript:alert(1)', 'caption' => '<script>alert(1)</script>' },
      { 'url' => 'https://i.redd.it/ok.jpg' }
    ], '" onerror="alert(1)')
    expect(html).not_to include('<script>', 'src="javascript:', 'alt="" onerror=')
    expect(html).to include('&lt;script&gt;', '&quot;', '/images/meme-placeholder.svg', 'loading="eager"', 'loading="lazy"')
  end

  it 'extracts actual gallery URLs instead of numeric dimensions' do
    post = { 'url' => 'https://reddit.com/gallery/id', 'gallery_data' => { 'items' => [{ 'media_id' => 'abc' }] },
      'media_metadata' => { 'abc' => { 's' => { 'x' => 640, 'u' => 'https://i.redd.it/a.jpg?a=1&amp;b=2' } } } }
    expect(reddit.extract_image_url(post)).to eq('https://i.redd.it/a.jpg?a=1&b=2')
  end

  it 'detects query-string video and GIF extensions' do
    expect(reddit.detect_media_type('https://example.com/a.mp4?token=abc')).to eq('video')
    expect(reddit.detect_media_type('https://example.com/a.gif#preview')).to eq('gif')
  end

  it 'normalizes and deduplicates safe preview fallback sources' do
    data = { 'url' => 'javascript:alert(1)', 'thumbnail' => 'https://i.redd.it/thumb.jpg',
      'preview' => { 'images' => [{ 'source' => { 'url' => 'https://i.redd.it/a.jpg?a=1&amp;b=2' },
        'resolutions' => [{ 'url' => 'data:text/html,bad' }] }] } }
    config = renderer.prepare_media_render(data)
    expect(config[:primary_url]).to be_nil
    expect(config[:fallback_urls]).to contain_exactly('https://i.redd.it/thumb.jpg', 'https://i.redd.it/a.jpg?a=1&b=2')
    expect(config[:media_type]).to eq('unknown')
  end

  it 'escapes image and video attributes' do
    %w[jpg gif mp4].each do |extension|
      html = renderer.render_with_smart_fallback({ 'url' => "https://i.redd.it/a.#{extension}" },
        alt: '<script>bad</script>', element_id: '" onload="bad', class: '" onclick="bad')
      expect(html).not_to include('<script>bad', 'id="" onload=', 'class="" onclick=')
      expect(html).to include('&lt;script&gt;')
    end
  end

  it 'uses script-safe JSON literals and textContent for fallback messages' do
    script = renderer.generate_fallback_script("x');alert(1)//", ['https://i.redd.it/a.jpg'],
      placeholder_message: '</script><script>alert(1)</script>')
    expect(script).not_to include('</script>', 'picsum.photos')
    expect(script).to include('\\u003c', '.textContent =', 'document.getElementById("')
  end

  it 'honors explicit placeholder opt-out and hide-on-failure' do
    expect(renderer.generate_fallback_script('image', [], show_placeholder: false)).not_to include('document.createElement')
    expect(renderer.generate_fallback_script('image', [], hide_on_failure: true)).to include("elem.style.display = 'none'")
  end

  it 'handles absent galleries and excludes invalid thumbnails' do
    expect(gallery.render_gallery_carousel(nil)).to eq('')
    expect(gallery.extract_gallery_images(nil)).to be_nil
    [nil, '', 'self', 'nsfw', 'http-not-a-url', 'javascript:bad', 12].each do |thumbnail|
      expect(renderer.valid_thumbnail?(thumbnail)).to be false
    end
  end
end