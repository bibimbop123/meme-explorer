require_relative '../spec_helper'

RSpec.describe QueryOptimizationHelpers do
  it 'binds leaderboard week before its limit' do
    expect(DB).to receive(:execute).with(include('AND wl.week_start = ?'), ['2026-10-12', 10]).and_return([])
    expect(described_class.fetch_leaderboard_with_users(limit: 10, week_start: '2026-10-12')).to eq([])
    expect(DB).to receive(:execute).with(include('LIMIT ?'), [5]).and_return([])
    described_class.fetch_leaderboard_with_users(limit: 5)
  end

  it 'preserves column alignment across differently ordered record hashes' do
    records = [{ 'url' => '/a.jpg', 'likes' => 1 }, { 'likes' => 2, 'url' => '/b.jpg' }]
    expect(DB).to receive(:execute).with(include('INSERT INTO meme_stats (url, likes)'), ['/a.jpg', 1, '/b.jpg', 2])
    expect(described_class.batch_insert('meme_stats', records)).to eq(2)
  end

  it 'bounds insert batch size and propagates write failures' do
    expect(DB).to receive(:execute).with(anything, ['/a.jpg']).ordered
    expect(DB).to receive(:execute).with(anything, ['/b.jpg']).ordered
    expect(described_class.batch_insert('meme_stats', [{ 'url' => '/a.jpg' }, { 'url' => '/b.jpg' }], batch_size: 1)).to eq(2)
    allow(DB).to receive(:execute).and_raise(PG::ConnectionBad)
    expect { described_class.batch_insert('meme_stats', [{ 'url' => '/c.jpg' }]) }.to raise_error(PG::ConnectionBad)
    expect(described_class.batch_insert('meme_stats', [])).to eq(0)
  end

  it 'groups preference records by user and avoids empty bulk queries' do
    rows = [{ 'user_id' => 1, 'subreddit' => 'cats' }, { 'user_id' => 2, 'subreddit' => 'funny' }]
    expect(DB).to receive(:execute).with(include('WHERE user_id IN (?,?)'), [1, 2]).and_return(rows)
    expect(described_class.fetch_user_preferences_bulk([1, 2])).to eq(1 => [rows.first], 2 => [rows.last])
    expect(described_class.fetch_user_preferences_bulk([])).to eq({})
    expect(described_class.fetch_memes_with_users(nil)).to eq([])
  end

  it 'binds meme URLs and account-scoped saved pagination' do
    expect(DB).to receive(:execute).with(include('WHERE ms.url IN (?)'), ['/a.jpg']).and_return([])
    described_class.fetch_memes_with_users(['/a.jpg'])
    expect(DB).to receive(:execute).with(include('WHERE sm.user_id = ?'), [4, 24, 48]).and_return([])
    described_class.fetch_saved_memes_with_stats(4, limit: 24, offset: 48)
  end

  it 'returns empty read fallbacks on database failures' do
    allow(DB).to receive(:execute).and_raise(PG::ConnectionBad)
    expect(described_class.fetch_memes_with_users(['/a.jpg'])).to eq([])
    expect(described_class.fetch_leaderboard_with_users).to eq([])
    expect(described_class.fetch_saved_memes_with_stats(1)).to eq([])
    expect(described_class.fetch_user_preferences_bulk([1])).to eq({})
  end
end