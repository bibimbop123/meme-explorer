require_relative '../spec_helper'

RSpec.describe 'Shared layout metadata origin' do
  before do
    allow(SearchService).to receive(:search).and_return(success: true, results: [])
    allow(ENV).to receive(:[]).and_call_original
  end

  it 'uses configured origin for generic social and canonical URLs' do
    allow(ENV).to receive(:[]).with('PUBLIC_ORIGIN').and_return('https://memes.example')
    get '/search', { q: 'cats' }, { 'HTTP_ACCEPT' => 'text/html', 'HTTP_X_FORWARDED_HOST' => 'untrusted.example' }
    expect(last_response.status).to eq(200)
    head = last_response.body.split('</head>').first
    expect(head).to include('href="https://memes.example/search"', 'name="twitter:card" content="summary"')
    expect(head).not_to include('untrusted.example', 'property="og:image', 'name="twitter:image', 'image/svg+xml', 'summary_large_image')
  end

  it 'omits request-derived metadata in production without configured origin' do
    allow(ENV).to receive(:[]).with('PUBLIC_ORIGIN').and_return(nil)
    allow(MemeExplorer::App.settings).to receive(:environment).and_return(:production)
    get '/search', { q: 'cats' }, { 'HTTP_ACCEPT' => 'text/html', 'HTTP_X_FORWARDED_HOST' => 'untrusted.example' }
    expect(last_response.status).to eq(200)
    head = last_response.body.split('</head>').first
    expect(head).not_to include('untrusted.example', 'rel="canonical"', 'property="og:url"', 'name="twitter:url"', 'name="twitter:image"')
  end
end