require_relative '../spec_helper'

RSpec.describe 'Save retry idempotency' do
  it 'does not repeat preference or reward side effects for an existing favorite' do
    user_id = create_test_user('save-retry@example.com')
    url = 'https://i.redd.it/retry.jpg'
    first = EngagementService.track_save(user_id: user_id, meme_url: url, title: 'Favorite', subreddit: 'cats', db: DB)
    expect(first[:success]).to eq(true)
    expect(EngagementService).not_to receive(:bump_subreddit_preference)
    expect(EngagementService).not_to receive(:award_xp)
    expect(EngagementService).not_to receive(:log_activity)
    second = EngagementService.track_save(user_id: user_id, meme_url: url, title: 'Changed', subreddit: 'cats', db: DB)
    expect(second).to include(success: true, unchanged: true, xp_awarded: 0)
    rows = DB.execute('SELECT meme_title FROM saved_memes WHERE user_id = ? AND meme_url = ?', [user_id, url])
    expect(rows.map { |row| row['meme_title'] }).to eq(['Favorite'])
  end

  it 'treats an insertion race as an unchanged save without rewarding it' do
    db = double('racing database')
    allow(db).to receive(:execute).with(include('SELECT id FROM saved_memes'), anything).and_return([])
    expect(db).to receive(:execute).with(include('ON CONFLICT(user_id, meme_url) DO NOTHING RETURNING id'), anything).and_return([])
    expect(EngagementService).not_to receive(:award_xp)
    result = EngagementService.track_save(user_id: 1, meme_url: '/retry.jpg', db: db)
    expect(result).to include(success: true, unchanged: true)
  end
end