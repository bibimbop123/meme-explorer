require_relative '../spec_helper'

RSpec.describe 'Search discovery rendering' do
  it 'registers and renders only the requested result page and preserves the query' do
    results = 50.times.map { |index| { 'url' => "https://i.redd.it/page#{index}.jpg", 'title' => "Result #{index}" } }
    stub_search(results)
    expect(MemeIdentityService).to receive(:register).exactly(24).times.and_return('a' * 64)
    get '/search', { q: 'cats & dogs', page: 2 }, { 'HTTP_ACCEPT' => 'text/html' }
    expect(last_response.status).to eq(200)
    expect(last_response.body).to include('Page 2 of 3', 'q=cats+%26+dogs&amp;page=3', 'Result 24', 'Result 47')
    expect(last_response.body).not_to include('Result 48', 'Result 0<')
  end

  it 'clamps oversized pages to the last page without registering off-page results' do
    results = 25.times.map { |index| { 'url' => "https://i.redd.it/boundary#{index}.jpg", 'title' => "Boundary #{index}" } }
    stub_search(results)
    expect(MemeIdentityService).to receive(:register).with(results.last).once.and_return('b' * 64)
    get '/search', { q: 'boundary', page: 999 }, { 'HTTP_ACCEPT' => 'text/html' }
    expect(last_response.status).to eq(200)
    expect(last_response.body).to include('Page 2 of 2', 'Boundary 24', 'rel="prev"')
    expect(last_response.body).not_to include('rel="next"', 'Boundary 0<')
  end

  it 'rejects invalid page input without invoking search or catalog registration' do
    expect(SearchService).not_to receive(:search)
    expect(MemeIdentityService).not_to receive(:register)
    get '/search', { q: 'cats', page: 0 }, { 'HTTP_ACCEPT' => 'text/html' }
    expect(last_response.status).to eq(400)
    expect(last_response.body).to include('Page must be positive integer')
  end

  def stub_search(results)
    allow(SearchService).to receive(:search).and_return(success: true, results: results)
  end

  it 'provides a labeled search form and preserves the query safely' do
    stub_search([])
    get '/search', { q: '"><script>query</script>' }, { 'HTTP_ACCEPT' => 'text/html' }
    expect(last_response.status).to eq(200)
    expect(last_response.body).to include('role="search"', 'for="meme-search"', 'name="q"', '&lt;script&gt;query&lt;/script&gt;')
    expect(last_response.body).not_to include('<script>query</script>')
  end

  it 'opens exact app detail pages rather than raw media or invented saved routes' do
    stub_search([{ 'url' => 'https://i.redd.it/search.jpg', 'title' => 'Found meme', 'subreddit' => 'funny' }])
    get '/search', { q: 'found' }, { 'HTTP_ACCEPT' => 'text/html' }
    path = last_response.body[/href="(\/meme\/[a-f0-9]{64}[^\"]*)"/, 1]
    path = path.gsub('&amp;', '&') if path
    expect(path).not_to be_nil
    expect(last_response.body).to include('View Meme')
    expect(last_response.body).not_to include('href="#"', 'href="/saved/funny"')
    get path
    expect(last_response.status).to eq(200)
    expect(last_response.body).to include('Found meme', 'https://i.redd.it/search.jpg')
  end

  it 'keeps search usable when catalog registration fails' do
    stub_search([{ 'url' => 'https://i.redd.it/fallback.jpg', 'title' => 'Fallback' }])
    allow(MemeIdentityService).to receive(:register).and_raise(PG::ConnectionBad)
    get '/search', { q: 'fallback' }, { 'HTTP_ACCEPT' => 'text/html' }
    expect(last_response.status).to eq(200)
    expect(last_response.body).to include('href="https://i.redd.it/fallback.jpg"')
  end

  it 'escapes result metadata and rejects executable image URLs' do
    stub_search([{ 'url' => 'javascript:alert(1)', 'title' => '<script>result</script>', 'subreddit' => '<img src=x>' }])
    get '/search', { q: 'result' }, { 'HTTP_ACCEPT' => 'text/html' }
    expect(last_response.status).to eq(200)
    expect(last_response.body).to include('&lt;script&gt;result&lt;/script&gt;', '/images/meme-placeholder.svg')
    expect(last_response.body).not_to include('<script>result</script>', 'src="javascript:', 'href="javascript:')
  end
end