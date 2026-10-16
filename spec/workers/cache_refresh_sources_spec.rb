require_relative '../spec_helper'
require_relative '../../app/workers/cache_refresh_worker'

RSpec.describe 'Cache refresh source recovery' do
  let(:worker) { CacheRefreshWorker.new }
  let(:memes) { [{ 'url' => 'https://i.redd.it/source.jpg' }] }
  let(:fetcher) { instance_double(RedditFetcherService) }

  before do
    allow(ENV).to receive(:[]).and_call_original
    allow(ENV).to receive(:[]).with('REDDIT_CLIENT_ID').and_return('')
    allow(ENV).to receive(:[]).with('REDDIT_CLIENT_SECRET').and_return('')
    allow(YAML).to receive(:load_file).and_call_original
    allow(YAML).to receive(:load_file).with('data/subreddits.yml', aliases: true).and_return('popular' => ['funny', 'cats'])
  end

  it 'fetches configured communities unauthenticated when credentials are absent' do
    expect(RedditFetcherService).to receive(:new).with(auth_strategy: :static).and_return(fetcher)
    expect(fetcher).to receive(:fetch_memes).with(['funny', 'cats'], limit: 50).and_return(memes)
    expect(worker.send(:fetch_with_reddit_service)).to eq(memes)
  end

  it 'uses OAuth token without invoking static fallback on success' do
    allow(ENV).to receive(:[]).with('REDDIT_CLIENT_ID').and_return('test-client')
    allow(ENV).to receive(:[]).with('REDDIT_CLIENT_SECRET').and_return('test-secret')
    credentials = double(get_token: double(token: 'test-access-token'))
    expect(OAuth2::Client).to receive(:new).with('test-client', 'test-secret', hash_including(site: 'https://www.reddit.com')).and_return(double(client_credentials: credentials))
    expect(RedditFetcherService).to receive(:new).with(auth_strategy: :oauth, access_token: 'test-access-token').and_return(fetcher)
    expect(fetcher).to receive(:fetch_memes).with(['funny', 'cats'], limit: 50).and_return(memes)
    expect(worker.send(:fetch_with_reddit_service)).to eq(memes)
  end

  it 'falls back to static fetching after OAuth failure' do
    allow(ENV).to receive(:[]).with('REDDIT_CLIENT_ID').and_return('test-client')
    allow(ENV).to receive(:[]).with('REDDIT_CLIENT_SECRET').and_return('test-secret')
    allow(OAuth2::Client).to receive(:new).and_raise(StandardError, 'OAuth unavailable')
    expect(RedditFetcherService).to receive(:new).with(auth_strategy: :static).and_return(fetcher)
    expect(fetcher).to receive(:fetch_memes).with(['funny', 'cats'], limit: 50).and_return(memes)
    expect(worker.send(:fetch_with_reddit_service)).to eq(memes)
  end

  it 'returns no API content when static fetching fails' do
    allow(RedditFetcherService).to receive(:new).and_return(fetcher)
    allow(fetcher).to receive(:fetch_memes).and_raise(SocketError, 'offline')
    expect(worker.send(:fetch_with_reddit_service)).to eq([])
  end

  it 'returns no API content when community configuration cannot be loaded' do
    allow(YAML).to receive(:load_file).with('data/subreddits.yml', aliases: true).and_raise(Errno::ENOENT)
    expect(RedditFetcherService).not_to receive(:new)
    expect(worker.send(:fetch_with_reddit_service)).to eq([])
  end

  it 'flattens categorized local content and removes nil entries' do
    allow(YAML).to receive(:load_file).with('data/memes.yml', aliases: true).and_return('funny' => [memes.first, nil])
    expect(worker.send(:load_local_memes)).to eq(memes)
  end

  it 'supports array and empty local files' do
    allow(YAML).to receive(:load_file).with('data/memes.yml', aliases: true).and_return(memes, nil)
    expect(worker.send(:load_local_memes)).to eq(memes)
    expect(worker.send(:load_local_memes)).to eq([])
  end

  it 'rejects scalar local data and non-meme entries' do
    allow(YAML).to receive(:load_file).with('data/memes.yml', aliases: true).and_return('malformed', [nil, 'invalid', memes.first])
    expect(worker.send(:load_local_memes)).to eq([])
    expect(worker.send(:load_local_memes)).to eq(memes)
  end

  it 'recovers from unreadable local files' do
    allow(YAML).to receive(:load_file).with('data/memes.yml', aliases: true).and_raise(Errno::ENOENT)
    expect(worker.send(:load_local_memes)).to eq([])
  end
end