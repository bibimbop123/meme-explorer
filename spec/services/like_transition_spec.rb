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
    expect(apply(true)).to include(success: false)
    expect(DB.get_first_value('SELECT COUNT(*) FROM user_liked_memes WHERE user_id = ?', [user_id]).to_i).to eq(0)
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