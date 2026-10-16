require_relative '../spec_helper'

RSpec.describe 'Navigation exposure and recovery helpers' do
  let(:helper) { Object.new.extend(MemeNavigationHelpers) }

  it 'does not query exposure for anonymous viewers' do
    expect(DB).not_to receive(:execute)
    expect(helper.should_exclude_from_exposure(nil, '/meme.jpg')).to eq(false)
  end

  it 'applies exponential repeat delays with a precise expiry boundary' do
    now = Time.utc(2026, 10, 15, 12)
    allow(Time).to receive(:now).and_return(now)
    allow(DB).to receive(:execute).with(anything, [1, '/meme.jpg']).and_return(
      [{ 'last_shown' => (now - 3599).iso8601, 'shown_count' => 1 }],
      [{ 'last_shown' => (now - 3600).iso8601, 'shown_count' => 1 }],
      [{ 'last_shown' => (now - 7200).iso8601, 'shown_count' => 2 }]
    )
    expect(helper.should_exclude_from_exposure(1, '/meme.jpg')).to eq(true)
    expect(helper.should_exclude_from_exposure(1, '/meme.jpg')).to eq(false)
    expect(helper.should_exclude_from_exposure(1, '/meme.jpg')).to eq(true)
  end

  it 'keeps discovery available for absent or malformed exposure records' do
    [[], [{ 'last_shown' => '' }], [{ 'last_shown' => 'not a timestamp', 'shown_count' => 1 }],
     [{ 'last_shown' => Time.now.iso8601, 'shown_count' => nil }]].each do |rows|
      allow(DB).to receive(:execute).and_return(rows)
      expect(helper.should_exclude_from_exposure(1, '/meme.jpg')).to eq(false)
    end
    allow(DB).to receive(:execute).and_raise(PG::ConnectionBad)
    expect(helper.should_exclude_from_exposure(1, '/meme.jpg')).to eq(false)
  end

  it 'skips the previous and known-broken candidate before returning valid content' do
    previous = { 'url' => 'https://i.redd.it/previous.jpg' }
    broken = { 'url' => 'https://i.redd.it/broken.jpg' }
    good = { 'url' => 'https://i.redd.it/good.jpg' }
    pool = [previous, broken, good]
    allow(pool).to receive(:sample).and_return(previous, broken, good)
    allow(helper).to receive(:session).and_return(meme_history: [previous['url']])
    allow(helper).to receive(:random_memes_pool).and_return(pool)
    allow(helper).to receive(:is_image_broken?).with(broken['url']).and_return(true)
    allow(helper).to receive(:is_image_broken?).with(good['url']).and_return(false)
    expect(helper.get_next_valid_meme).to eq(good)
  end

  it 'bounds attempts and returns nil for empty or repeatedly invalid pools' do
    allow(helper).to receive(:session).and_return(meme_history: [])
    allow(helper).to receive(:random_memes_pool).and_return([])
    expect(helper.get_next_valid_meme).to be_nil
    invalid = { 'url' => 'javascript:bad' }
    pool = Array.new(50, invalid)
    allow(helper).to receive(:random_memes_pool).and_return(pool)
    expect(pool).to receive(:sample).exactly(30).times.and_return(invalid)
    expect(helper.get_next_valid_meme).to be_nil
  end

  it 'uses API media before local fallback and marks loading content as a placeholder' do
    expect(helper.meme_image_src('url' => 'https://i.redd.it/a.jpg', 'file' => '/local.jpg')).to eq('https://i.redd.it/a.jpg')
    expect(helper.meme_image_src('url' => '', 'file' => '/local.jpg')).to eq('/local.jpg')
    expect(helper.meme_image_src(nil)).to eq('/images/funny1.jpeg')
    expect(helper.fallback_meme).to include('is_placeholder' => true, 'subreddit' => 'loading')
    expect(helper.sanitize_subreddit(nil)).to eq('local')
    expect(helper.sanitize_subreddit('FUNNY')).to eq('funny')
  end
end