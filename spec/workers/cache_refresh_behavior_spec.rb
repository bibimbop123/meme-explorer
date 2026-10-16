require_relative '../spec_helper'
require_relative '../../app/workers/cache_refresh_worker'

RSpec.describe 'Cache refresh publication and failures' do
  let(:worker) { CacheRefreshWorker.new }
  let(:cache) { double('cache', set: true) }
  let(:local) { { 'file' => '/images/local.jpg', 'title' => 'Local' } }

  before do
    allow(worker).to receive(:with_redis_lock).with('cache_refresh', ttl: 300).and_yield.and_return(true)
    allow(worker).to receive(:get_cache).and_return(cache)
    allow(worker).to receive(:load_local_memes).and_return([local])
    allow(worker).to receive(:fetch_with_reddit_service).and_return([])
    stub_const('ImageHealthService', Class.new)
    allow(ImageHealthService).to receive(:filter_blacklisted) { |memes| memes.reject { |m| m['url'].include?('blacklisted') } }
    stub_const('ImageValidationService', Class.new)
    allow(ImageValidationService).to receive(:validate) { |url| !url.include?('broken') }
  end

  it 'publishes only validated, nonblacklisted, deduplicated API content with local fallback' do
    valid = { 'url' => 'https://i.redd.it/valid.jpg' }
    allow(worker).to receive(:fetch_with_reddit_service).and_return([
      valid, valid.dup, { 'url' => '' }, {},
      { 'url' => 'https://i.redd.it/blacklisted.jpg' },
      { 'url' => 'https://i.redd.it/broken.jpg' }
    ])
    expect(cache).to receive(:set).with(:memes, match_array([valid, local]))
    expect(cache).to receive(:set).with(:last_refresh, kind_of(Time))
    worker.perform
    expect(ImageValidationService).not_to have_received(:validate).with('https://i.redd.it/blacklisted.jpg')
  end

  it 'publishes local fallback when all API content is rejected' do
    allow(worker).to receive(:fetch_with_reddit_service).and_return([{ 'url' => 'https://i.redd.it/broken.jpg' }])
    expect(cache).to receive(:set).with(:memes, [local])
    worker.perform
  end

  it 'does no fetching or publishing when another worker owns the lock' do
    allow(worker).to receive(:with_redis_lock).and_return(false)
    expect(worker).not_to receive(:fetch_with_reddit_service)
    expect(cache).not_to receive(:set)
    worker.perform
  end

  it 'does not mark refresh complete when publication fails and raises for retry' do
    allow(cache).to receive(:set).with(:memes, anything).and_raise(StandardError, 'write failed')
    expect(cache).not_to receive(:set).with(:last_refresh, anything)
    expect { worker.perform }.to raise_error(StandardError, 'write failed')
  end

  it 'does not fetch when the application cache is unavailable' do
    allow(worker).to receive(:get_cache).and_return(nil)
    expect(worker).not_to receive(:fetch_with_reddit_service)
    expect(cache).not_to receive(:set)
    worker.perform
  end
end