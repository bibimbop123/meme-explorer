require_relative '../spec_helper'
require 'cgi'

RSpec.describe 'Search fallback endpoint integration' do
  let(:query) { 'fallbackcommunity' }
  let(:cached_url) { 'https://i.redd.it/fallback-cache.jpg' }
  let(:database_url) { 'https://i.redd.it/fallback-database.jpg' }

  before do
    allow(MemeService).to receive(:fetch_reddit_memes).and_return([])
    allow(SearchService).to receive(:flatten_memes).and_return([])
    allow(MemeExplorer::App::MEME_CACHE).to receive(:[]).and_call_original
    allow(MemeExplorer::App::MEME_CACHE).to receive(:[]).with(:memes).and_return([
      { 'url' => cached_url, 'title' => 'Cached discovery', 'subreddit' => query }
    ])
    DB.execute('INSERT INTO meme_stats (url, title, subreddit, likes, views) VALUES (?, ?, ?, 3, 4)',
      [database_url, 'Database discovery', query])
  end

  it 'renders both sparse sources and opens the supplemented exact meme with search context' do
    get '/search', { q: query }, { 'HTTP_ACCEPT' => 'text/html' }
    expect(last_response.status).to eq(200)
    expect(last_response.body).to include('Cached discovery', 'Database discovery', '2 results found.')
    id = Digest::SHA256.hexdigest("meme-url-v1:#{database_url}")
    path = CGI.unescapeHTML(last_response.body[/href="(\/meme\/#{id}[^\"]*)"/, 1].to_s)
    expect(path).to include("/meme/#{id}?", "search_q=#{query}", 'search_page=1')
    get path
    expect(last_response.status).to eq(200)
    expect(last_response.body).to include('Database discovery', database_url, 'Back to search results')
  end

  ['/api/search.json', '/search'].each do |path|
    it "returns both sparse sources through #{path} JSON without duplicates" do
      get path, { q: query }, { 'HTTP_ACCEPT' => 'application/json' }
      expect(last_response.status).to eq(200)
      payload = JSON.parse(last_response.body)
      expect(payload['query']).to eq(query)
      expect(payload['total']).to eq(2)
      expect(payload['results'].map { |meme| meme['url'] }).to contain_exactly(cached_url, database_url)
    end
  end
end