require_relative '../spec_helper'
require_relative '../../lib/services/meme_pool_manager'

RSpec.describe 'Bootstrap inventory and cooldown' do
  let(:meme) { { 'url' => 'https://i.redd.it/bootstrap.jpg', 'title' => 'Bootstrap', 'subreddit' => 'funny' } }
  let(:fetcher) { instance_double(RedditFetcherService, rate_limited?: false) }

  before do
    allow(MemePoolManager).to receive(:create_fetcher).and_return(fetcher)
    allow(MemePoolManager).to receive(:load_tier_subreddits).and_return(%w[funny memes cats dogs])
  end

  it 'retains a cooldown and usable probe results after a partial rate limit' do
    allow(fetcher).to receive(:fetch_memes).and_return([meme], [])
    allow(fetcher).to receive(:rate_limited?).and_return(true)
    expect(MemePoolManager).to receive(:store_in_pool).with([meme]).and_return(1)
    expect(RedisService).to receive(:set).with(MemePoolManager::BOOTSTRAP_COOLDOWN_KEY, 'true', ttl: MemePoolManager::BOOTSTRAP_COOLDOWN_TTL)
    expect(RedisService).not_to receive(:delete).with(MemePoolManager::BOOTSTRAP_COOLDOWN_KEY)
    expect(MemePoolManager.send(:bootstrap_pool)).to include(success: true, size: 1, memes: [meme])
  end

  it 'publishes and reports unique probe/fetch URLs rather than overlapping counts' do
    allow(fetcher).to receive(:fetch_memes).and_return([meme], [meme.dup])
    expect(MemePoolManager).to receive(:store_in_pool).with([meme]).and_return(1)
    expect(RedisService).to receive(:delete).with(MemePoolManager::BOOTSTRAP_COOLDOWN_KEY)
    expect(MemePoolManager.send(:bootstrap_pool)).to include(success: true, size: 1, memes: [meme])
  end

  it 'keeps partial results and cooldown when Redis publication fails' do
    allow(fetcher).to receive(:fetch_memes).and_return([meme], [])
    allow(fetcher).to receive(:rate_limited?).and_return(true)
    allow(MemePoolManager).to receive(:store_in_pool).and_return(0)
    expect(RedisService).to receive(:set).with(MemePoolManager::BOOTSTRAP_COOLDOWN_KEY, 'true', ttl: MemePoolManager::BOOTSTRAP_COOLDOWN_TTL)
    expect(MemePoolManager.send(:bootstrap_pool)).to include(success: true, size: 1)
  end

  it 'keeps usable candidates while rejecting malformed and unsafe cold-start content' do
    invalid = [nil, 'not a meme', {}, meme.merge('url' => 'javascript:alert(1)'),
      meme.merge('url' => '//evil.example/image.jpg'), meme.merge('title' => ' '),
      meme.merge('subreddit' => 42)]
    allow(fetcher).to receive(:fetch_memes).and_return(invalid, [meme, meme.dup])
    expect(MemePoolManager).to receive(:store_in_pool).with([meme]).and_return(1)
    allow(RedisService).to receive(:delete)
    expect(MemePoolManager.send(:bootstrap_pool)).to include(success: true, size: 1, memes: [meme])
  end

  it 'returns no usable memes when every cold-start candidate fails basic validation' do
    allow(fetcher).to receive(:fetch_memes).and_return([meme.merge('url' => 'javascript:alert(1)')], [])
    expect(MemePoolManager).to receive(:store_in_pool).with([]).and_return(0)
    expect(MemePoolManager.send(:bootstrap_pool)).to include(success: false, size: 0, memes: [], error: 'No memes passed validation')
  end

  it 'keeps cold-start validation independent of the optional expensive pipeline' do
    stub_const('QualityPipelineService', Class.new)
    expect(QualityPipelineService).not_to receive(:passes_all_gates?)
    allow(fetcher).to receive(:fetch_memes).and_return([meme], [])
    allow(MemePoolManager).to receive(:store_in_pool).and_return(0)
    expect(MemePoolManager.send(:bootstrap_pool)).to include(success: true, memes: [meme])
  end
end