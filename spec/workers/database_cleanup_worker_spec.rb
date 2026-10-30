# frozen_string_literal: true
require_relative '../spec_helper'
require_relative '../../app/workers/database_cleanup_worker'

RSpec.describe DatabaseCleanupWorker do
  let(:worker) { described_class.new }

  describe '#perform' do
    it 'cleans expired visitors and suppression markers even when collection is disabled' do
      %w[add_browser_visitors.sql add_browser_visitor_revocation.sql].each do |file|
        DB_POOL.with { |connection| connection.exec(File.read(File.expand_path("../../db/migrations/#{file}", __dir__))) }
      end
      DB.execute('DELETE FROM browser_visitors')
      allow(ENV).to receive(:[]).and_call_original
      allow(ENV).to receive(:[]).with('ENABLE_VISITOR_METRICS').and_return('false')
      DB.execute("INSERT INTO browser_visitors (visitor_key, last_seen_at) VALUES (?, NOW() - INTERVAL '31 days'), (?, NOW())", ['a' * 64, 'b' * 64])
      DB.execute("INSERT INTO browser_visitors (visitor_key, last_seen_at, revoked_at) VALUES (?, NULL, NOW() - INTERVAL '31 days'), (?, NULL, NOW() - INTERVAL '1 day')", ['c' * 64, 'd' * 64])
      worker.perform
      expect(DB.execute('SELECT visitor_key FROM browser_visitors ORDER BY visitor_key').map { |row| row['visitor_key'] }).to eq(['b' * 64, 'd' * 64])
    ensure
      DB.execute('DELETE FROM browser_visitors')
    end

    it 'executes without raising' do
      expect { worker.perform }.not_to raise_error
    end

    it 'removes broken images older than 1 day with 5+ failures' do
      # BUG FIX: both INSERTs below were missing `?` placeholders for
      # `url`/`failure_count` entirely - the two adjacent string literals
      # concatenated into `VALUES (, , NOW() - ...)`, a plain SQL syntax
      # error, so this example never even got to test the worker's real
      # behavior. Added the missing placeholders.
      DB.execute(
        "INSERT INTO broken_images (url, failure_count, first_failed_at, last_failed_at)" \
        " VALUES (?, ?, NOW() - INTERVAL '2 days', NOW() - INTERVAL '1 day')",
        ['http://broken-old.example.com/meme.jpg', 5]
      )
      DB.execute(
        "INSERT INTO broken_images (url, failure_count, first_failed_at, last_failed_at)" \
        " VALUES (?, ?, NOW() - INTERVAL '1 hour', NOW())",
        ['http://broken-recent.example.com/meme.jpg', 5]
      )
      worker.perform
      remaining = DB.execute("SELECT url FROM broken_images").map { |r| r['url'] }
      expect(remaining).not_to include('http://broken-old.example.com/meme.jpg')
      expect(remaining).to include('http://broken-recent.example.com/meme.jpg')
    end

    it 'keeps meme stats with engagement even if old' do
      # Same missing-placeholder bug fix as above.
      DB.execute(
        "INSERT INTO meme_stats (url, title, subreddit, views, likes, updated_at)" \
        " VALUES (?, ?, ?, 100, 5, NOW() - INTERVAL '10 days')",
        ['http://engaged.example.com/meme.jpg', 'Popular Meme', 'test']
      )
      worker.perform
      remaining = DB.execute("SELECT url FROM meme_stats").map { |r| r['url'] }
      expect(remaining).to include('http://engaged.example.com/meme.jpg')
    end

    it 'handles db errors without re-raising (non-critical worker)' do
      allow(DB).to receive(:execute).and_raise(PG::Error, 'connection lost')
      expect { worker.perform }.not_to raise_error
    end

    it 'deletes only old unengaged stats after completing broken-image cleanup' do
      DB.execute("INSERT INTO meme_stats (url, views, likes, updated_at) VALUES (?, 0, 0, NOW() - INTERVAL '10 days')", ['https://example.com/stale.jpg'])
      DB.execute("INSERT INTO meme_stats (url, views, likes, updated_at) VALUES (?, 0, 0, NOW())", ['https://example.com/recent.jpg'])
      worker.perform
      urls = DB.execute('SELECT url FROM meme_stats').map { |row| row['url'] }
      expect(urls).not_to include('https://example.com/stale.jpg')
      expect(urls).to include('https://example.com/recent.jpg')
    end

    it 'retains recent impression dedupe records and removes records beyond seven days' do
      DB.execute("INSERT INTO meme_impressions (id, meme_url, session_key, created_at) VALUES ('old', '/old.jpg', 'session', NOW() - INTERVAL '8 days')")
      DB.execute("INSERT INTO meme_impressions (id, meme_url, session_key, created_at) VALUES ('recent', '/recent.jpg', 'session', NOW() - INTERVAL '1 day')")
      worker.perform
      expect(DB.execute('SELECT id FROM meme_impressions').map { |row| row['id'] }).to eq(['recent'])
    end

    it 'prunes meme_activity_log events older than 90 days while retaining 30d/14d window events' do
      DB.execute("INSERT INTO meme_activity_log (meme_url, activity_type, created_at) VALUES ('/ancient.jpg', 'view', NOW() - INTERVAL '95 days')")
      DB.execute("INSERT INTO meme_activity_log (meme_url, activity_type, created_at) VALUES ('/recent.jpg', 'view', NOW() - INTERVAL '10 days')")
      worker.perform
      urls = DB.execute('SELECT meme_url FROM meme_activity_log').map { |row| row['meme_url'] }
      expect(urls).to eq(['/recent.jpg'])
    end
  end

  describe 'Sidekiq configuration' do
    it 'uses the low priority queue' do
      expect(described_class.sidekiq_options_hash['queue'].to_s).to eq('low')
    end
  end
end
