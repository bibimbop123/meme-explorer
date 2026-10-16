# frozen_string_literal: true
require_relative '../spec_helper'
require_relative '../../app/workers/database_cleanup_worker'

RSpec.describe DatabaseCleanupWorker do
  let(:worker) { described_class.new }

  describe '#perform' do
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
  end

  describe 'Sidekiq configuration' do
    it 'uses the low priority queue' do
      expect(described_class.sidekiq_options_hash['queue'].to_s).to eq('low')
    end
  end
end
