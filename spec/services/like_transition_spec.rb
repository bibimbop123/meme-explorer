require_relative '../spec_helper'

RSpec.describe 'Atomic signed-in like transitions' do
  let(:user_id) { create_test_user('atomic-like@example.test') }
  let(:url) { 'https://example.com/atomic-like.jpg' }

  def apply(desired)
    EngagementService.set_like(user_id: user_id, meme_url: url, desired: desired, db: DB)
  end

  it 'makes repeated desired states no-ops without duplicating counts or preference' do
    DB.execute('INSERT INTO meme_stats (url, subreddit, likes) VALUES (?, ?, 0)', [url, 'funny'])
    expect(apply(true)).to include(success: true, liked: true, likes: 1)
    expect(apply(true)).to include(success: true, liked: true, likes: 1, unchanged: true)
    expect(apply(false)).to include(success: true, liked: false, likes: 0)
    expect(apply(false)).to include(success: true, liked: false, likes: 0, unchanged: true)
    expect(DB.get_first_value('SELECT times_liked FROM user_subreddit_preferences WHERE user_id = ?', [user_id]).to_i).to eq(1)
  end

  it 'rolls back membership when engagement persistence fails' do
    allow(EngagementService).to receive(:track_like).and_return(success: false)
    expect(EngagementService).not_to receive(:invalidate_like_cache)
    expect(apply(true)).to include(success: false)
    expect(DB.get_first_value('SELECT COUNT(*) FROM user_liked_memes WHERE user_id = ?', [user_id]).to_i).to eq(0)
  end

  it 'preserves the shared count for concurrent likes and unlikes from different accounts' do
    users = [user_id, create_test_user('atomic-like-other@example.test')]
    media = url
    # Release both threads together; assertions allow either database arrival order.
    run = lambda do |desired|
      ready = Queue.new
      release = Queue.new
      threads = users.map do |uid|
        Thread.new do
          ready << true
          release.pop
          EngagementService.set_like(user_id: uid, meme_url: media, desired: desired, db: DB)
        end
      end
      2.times { ready.pop }
      2.times { release << true }
      threads.map(&:value)
    end
    likes = run.call(true)
    expect(likes).to all(include(success: true, liked: true))
    expect(likes.map { |result| result[:likes] }.sort).to eq([1, 2])
    expect(DB.get_first_value('SELECT COUNT(*) FROM user_liked_memes WHERE meme_url = ?', [media]).to_i).to eq(2)
    expect(DB.get_first_value('SELECT likes FROM meme_stats WHERE url = ?', [media]).to_i).to eq(2)
    unlikes = run.call(false)
    expect(unlikes).to all(include(success: true, liked: false))
    expect(unlikes.map { |result| result[:likes] }.sort).to eq([0, 1])
    expect(DB.get_first_value('SELECT COUNT(*) FROM user_liked_memes WHERE meme_url = ?', [media]).to_i).to eq(0)
    expect(DB.get_first_value('SELECT likes FROM meme_stats WHERE url = ?', [media]).to_i).to eq(0)
    expect(DB.get_first_value('SELECT COUNT(*) FROM user_meme_stats WHERE meme_url = ? AND liked = 1', [media]).to_i).to eq(0)
  end

  it 'preserves committed success when cache invalidation raises and retries cleanup on unchanged intent' do
    allow(RedisService).to receive(:delete).with("meme:likes:#{url}").and_raise(IOError, 'private cache details')
    expect(apply(true)).to include(success: true, liked: true, likes: 1)
    expect(DB.get_first_value('SELECT likes FROM meme_stats WHERE url = ?', [url]).to_i).to eq(1)
    expect(RedisService).to receive(:delete).with("meme:likes:#{url}").and_return(true)
    expect(apply(true)).to include(success: true, unchanged: true, likes: 1)
  end

  it 'logs only exception class when optional invalidation raises' do
    allow(RedisService).to receive(:delete).with("meme:likes:#{url}").and_raise(IOError, "private cache details #{url}")
    expect(AppLogger).to receive(:warn).with('Like cache invalidation unavailable', error: 'IOError').once
    expect(EngagementService.invalidate_like_cache(url)).to be false
  end

  it 'reports an unavailable cache without inventing an exception or failing the mutation' do
    allow(RedisService).to receive(:delete).with("meme:likes:#{url}").and_return(false)
    expect(AppLogger).to receive(:warn).with('Like cache invalidation unavailable').once
    expect(apply(true)).to include(success: true, liked: true, likes: 1)
  end

  it 'serializes concurrent same-state requests across pooled database connections' do
    uid = user_id
    media = url
    results = 4.times.map do
      Thread.new { EngagementService.set_like(user_id: uid, meme_url: media, desired: true, db: DB) }
    end.map(&:value)
    expect(results).to all(include(success: true, liked: true, likes: 1))
    expect(DB.get_first_value('SELECT COUNT(*) FROM user_liked_memes WHERE user_id = ?', [uid]).to_i).to eq(1)
    expect(DB.get_first_value('SELECT likes FROM meme_stats WHERE url = ?', [media]).to_i).to eq(1)
  end

  it 'rolls back prior writes when a rescued SQL error aborts the critical transaction' do
    uid = user_id
    DB.execute('INSERT INTO meme_stats (url, subreddit, likes) VALUES (?, ?, 0)', [url, 'funny'])
    allow(EngagementService).to receive(:update_user_meme_stats) do
      begin
        DB.execute('SELECT * FROM intentionally_missing_like_fixture_table')
      rescue PG::UndefinedTable
        # Reproduce a legacy best-effort helper swallowing its SQL error.
      end
    end
    expect(apply(true)).to include(success: false)
    expect(DB.get_first_value('SELECT COUNT(*) FROM user_liked_memes WHERE user_id = ?', [uid]).to_i).to eq(0)
    expect(DB.get_first_value('SELECT likes FROM meme_stats WHERE url = ?', [url]).to_i).to eq(0)
    expect(DB.get_first_value('SELECT COUNT(*) FROM user_subreddit_preferences WHERE user_id = ?', [uid]).to_i).to eq(0)
  end
end