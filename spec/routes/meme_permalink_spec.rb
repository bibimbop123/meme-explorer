require_relative '../spec_helper'
require_relative '../../lib/services/meme_identity_service'

RSpec.describe 'Public exact-meme recipient pages' do
  it 'serves exact large-image metadata to Twitterbot without a sender session' do
    allow(ENV).to receive(:[]).and_call_original
    allow(ENV).to receive(:[]).with('PUBLIC_ORIGIN').and_return('https://memes.example')
    id = MemeIdentityService.register({ 'url' => 'https://i.redd.it/tweet-exact.jpg', 'title' => 'Exact tweet meme 😎' })
    set_session({})
    get "/meme/#{id}", {}, { 'HTTP_USER_AGENT' => 'Twitterbot/1.0' }
    expect(last_response.status).to eq(200)
    head = last_response.body.split('</head>').first
    expect(head).to include('name="twitter:card" content="summary_large_image"',
      'name="twitter:image" content="https://i.redd.it/tweet-exact.jpg"',
      "name=\"twitter:url\" content=\"https://memes.example/meme/#{id}\"", 'Exact tweet meme 😎')
  end

  it 'uses the exact video thumbnail as preview rather than advertising video as an image' do
    id = MemeIdentityService.register({ 'url' => 'https://v.redd.it/tweet-video.mp4', 'media_type' => 'video',
      'thumbnail_url' => 'https://i.redd.it/tweet-poster.jpg', 'title' => 'Video poster' })
    get "/meme/#{id}"
    head = last_response.body.split('</head>').first
    expect(head).to include('name="twitter:card" content="summary_large_image"', 'name="twitter:image" content="https://i.redd.it/tweet-poster.jpg"')
    expect(head).not_to include('name="twitter:image" content="https://v.redd.it/tweet-video.mp4"')
  end
  it 'retains crosspost origin when a registered image is opened by a recipient' do
    id = MemeIdentityService.register({ 'url' => 'https://i.redd.it/crosspost-recipient.jpg',
      'title' => 'Shared image', 'subreddit' => 'funny', 'is_crosspost' => true, 'original_subreddit' => 'original<community>' })
    get "/meme/#{id}"
    expect(last_response.status).to eq(200)
    expect(last_response.body).to include('crosspost-badge', 'from r/original&lt;community&gt;')
    expect(last_response.body).not_to include('from r/original<community>')
  end

  it 'shows content and a discovery link without ad slots even when ads are enabled' do
    allow(ENV).to receive(:[]).and_call_original
    allow(ENV).to receive(:[]).with('DISABLE_ADS').and_return('false')
    id = MemeIdentityService.register({ 'url' => '/images/funny1.jpeg', 'title' => 'Content first' })
    get "/meme/#{id}"
    expect(last_response.status).to eq(200)
    expect(last_response.body).to include('id="meme-display"', 'Find your next favorite')
    expect(last_response.body).not_to include('class="ad-container"', 'class="ad-anchor-bottom"', 'id="ad-unit-')
  end

  [nil, 'http://invalid.example', 'https://invalid.example/path'].each do |origin|
    it "omits request-derived recipient metadata in production with origin #{origin.inspect}" do
      allow(ENV).to receive(:[]).and_call_original
      allow(ENV).to receive(:[]).with('PUBLIC_ORIGIN').and_return(origin)
      allow(MemeExplorer::App.settings).to receive(:environment).and_return(:production)
      id = MemeIdentityService.register({ 'url' => '/images/funny1.jpeg', 'title' => 'Still viewable' })
      get "/meme/#{id}", {}, { 'HTTP_X_FORWARDED_HOST' => 'untrusted.example' }
      expect(last_response.status).to eq(200)
      expect(last_response.body).to include('id="meme-display"', 'Still viewable')
      head = last_response.body.split('</head>').first
      expect(head).to include('name="twitter:card" content="summary"')
      expect(head).not_to include('rel="canonical"', 'property="og:url"', 'name="twitter:url"', 'property="og:image"', 'name="twitter:image"', 'untrusted.example')
    end
  end

  it 'uses configured public origin rather than request headers in social URLs' do
    allow(ENV).to receive(:[]).and_call_original
    allow(ENV).to receive(:[]).with('PUBLIC_ORIGIN').and_return('https://memes.example/')
    id = MemeIdentityService.register({ 'url' => '/images/funny1.jpeg', 'title' => 'Trusted' })
    get "/meme/#{id}", {}, { 'HTTP_X_FORWARDED_HOST' => 'untrusted.example', 'HTTP_X_FORWARDED_PROTO' => 'http' }
    head = last_response.body.split('</head>').first
    expect(head).to include("content=\"https://memes.example/meme/#{id}\"", 'content="https://memes.example/images/funny1.jpeg"')
    expect(head).not_to include('untrusted.example')
  end

  it 'uses absolute local raster previews with escaped query strings' do
    id = MemeIdentityService.register({ 'url' => '/images/funny1.jpeg?size=2&format=jpeg', 'title' => 'Local' })
    get "/meme/#{id}"
    head = last_response.body.split('</head>').first
    expect(head).to include('property="og:image" content="http://example.org/images/funny1.jpeg?size=2&amp;format=jpeg"')
  end

  it 'uses the first gallery raster rather than the gallery landing URL' do
    id = MemeIdentityService.register({ 'url' => 'https://www.reddit.com/gallery/abc', 'title' => 'Gallery', 'is_gallery' => true, 'gallery_images' => [{ 'url' => 'https://i.redd.it/first.png?width=900' }, { 'url' => 'https://i.redd.it/second.jpg' }] })
    get "/meme/#{id}"
    expect(last_response.status).to eq(200)
    head = last_response.body.split('</head>').first
    expect(head).to include('property="og:image" content="https://i.redd.it/first.png?width=900"')
    expect(head).not_to include('second.jpg')
  end

  it 'returns to the selected search result without adding context to sharing metadata' do
    id = MemeIdentityService.register({ 'url' => 'https://i.redd.it/return.jpg', 'title' => 'Return' })
    get "/meme/#{id}", search_q: 'cats & dogs', search_page: '2', search_result: '7'
    expect(last_response.status).to eq(200)
    expect(last_response.body).to include('/search?q=cats+%26+dogs&amp;page=2#search-result-7', 'Back to search results', "data-share-path=\"/meme/#{id}\"")
    head = last_response.body.split('</head>').first
    expect(head).not_to include('search_q', 'search_page')
    get "/meme/#{id}", search_q: '//evil.example', search_page: '0', search_result: '24'
    expect(last_response.body).not_to include('Back to search results')
  end

  it 'renders exact escaped social metadata without conflicting placeholder tags' do
    id = MemeIdentityService.register({ 'url' => 'https://i.redd.it/card.jpg', 'title' => 'A "quoted" <meme>', 'subreddit' => 'funny' })
    get "/meme/#{id}"
    head = last_response.body.split('</head>').first
    expect(head).to include("/meme/#{id}", 'A &quot;quoted&quot; &lt;meme&gt;', 'content="https://i.redd.it/card.jpg"')
    expect(head.scan('property="og:url"').length).to eq(1)
    expect(head.scan('property="og:image"').length).to eq(1)
    expect(head).not_to include('image/svg+xml', 'og:image:width', '<meme>')
  end

  it 'does not advertise video as a social image' do
    id = MemeIdentityService.register({ 'url' => 'https://v.redd.it/video.mp4', 'title' => 'Video', 'media_type' => 'video' })
    get "/meme/#{id}"
    head = last_response.body.split('</head>').first
    expect(head).to include('name="twitter:card" content="summary"')
    expect(head).not_to include('property="og:image"')
  end
  it 'resolves registered content without the sender session and issues a new impression' do
    id = MemeIdentityService.register({ 'url' => 'https://i.redd.it/recipient.jpg', 'title' => 'Exact recipient meme', 'subreddit' => 'funny' })
    set_session({})
    get "/meme/#{id}"
    expect(last_response.status).to eq(200)
    expect(last_response.body).to include('Exact recipient meme', 'https://i.redd.it/recipient.jpg', "data-share-path=\"/meme/#{id}\"")
    expect(last_response.body).to match(/data-impression-id="[a-f0-9]{64}"/)
  end

  it 'does not replace missing or removed content with a random meme' do
    get '/meme/not-an-id'
    expect(last_response.status).to eq(404)
    expect(last_response.body).to include('This meme is unavailable')
    expect(last_response.headers['x-robots-tag']).to eq('noindex, nofollow')
    expect(last_response.body).to include('name="robots" content="noindex, nofollow"', 'Meme unavailable | Meme Explorer')
    expect(last_response.body).not_to include('rel="canonical"', 'property="og:', 'Try this meme again')
    id = MemeIdentityService.register({ 'url' => '/images/funny1.jpeg', 'title' => 'Removed meme' })
    DB.execute('UPDATE meme_catalog SET removed_at = CURRENT_TIMESTAMP WHERE id = ?', [id])
    get "/meme/#{id}"
    expect(last_response.status).to eq(404)
    expect(last_response.body).not_to include('id="meme-display"')
  end

  it 'recovers the exact meme after a temporary catalog outage without retaining error metadata' do
    meme = { 'url' => 'https://i.redd.it/recovered.jpg', 'title' => 'Recovered exact meme' }
    id = MemeIdentityService.register(meme)
    attempts = 0
    allow(MemeIdentityService).to receive(:find).with(id).and_wrap_original do |original, *args|
      attempts += 1
      raise PG::ConnectionBad if attempts == 1
      original.call(*args)
    end
    get "/meme/#{id}"
    expect(last_response.status).to eq(503)
    expect(last_response.body).to include("href=\"/meme/#{id}\"")
    get "/meme/#{id}"
    expect(last_response.status).to eq(200)
    expect(last_response.body).to include('Recovered exact meme', 'https://i.redd.it/recovered.jpg', 'name="robots" content="index, follow"', 'rel="canonical"')
    expect(last_response.body).not_to include('Meme unavailable |', 'Try this meme again', 'noindex, nofollow')
    expect(last_response.headers['retry-after']).to be_nil
    expect(last_response.headers['x-robots-tag']).to be_nil
    expect(last_response.headers['cache-control']).to eq('no-store')
  end

  it 'returns a retryable status when the registry is unavailable' do
    allow(MemeIdentityService).to receive(:find).and_raise(PG::ConnectionBad)
    get "/meme/#{'a' * 64}"
    expect(last_response.status).to eq(503)
    expect(last_response.body).to include('This meme is unavailable')
    expect(last_response.headers['retry-after']).to eq('60')
    expect(last_response.headers['x-robots-tag']).to eq('noindex, nofollow')
    expect(last_response.body).to include("href=\"/meme/#{'a' * 64}\"", 'Try this meme again')
    expect(last_response.body).not_to include('rel="canonical"', 'property="og:')
  end
end