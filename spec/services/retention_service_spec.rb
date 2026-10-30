# spec/services/retention_service_spec.rb
#
# Covers lib/services/retention_service.rb - the Phase 1 roadmap item
# ("Instrument retention (daily return rate, session length) alongside
# the existing latency benchmarks", ROADMAP.md). Real SQL against the
# real meme_activity_log table (already used for view/like tracking
# across the app), not a mock - the whole point of this metric is that
# it reflects real user behavior.

require_relative '../spec_helper'

RSpec.describe RetentionService do
  let(:db) { DB }

  def create_user(email)
    hashed = BCrypt::Password.create("testpass123")
    db.execute("INSERT INTO users (email, password_hash) VALUES (?, ?)", [email, hashed])
    db.last_insert_row_id
  end

  def log_activity(user_id, timestamp, url: "https://example.com/meme.jpg")
    db.execute(
      "INSERT INTO meme_activity_log (meme_url, activity_type, user_id, session_id, created_at) VALUES (?, 'view', ?, ?, ?)",
      [url, user_id, "sess-#{user_id}", timestamp]
    )
  end

  before do
    db.execute("DELETE FROM meme_activity_log") rescue nil
  end

  describe '.daily_return_rate' do
    it 'uses UTC dates regardless of the database connection timezone' do
      user_id = create_user('timezone@example.test')
      log_activity(user_id, Time.utc(2026, 10, 19, 23, 30))
      log_activity(user_id, Time.utc(2026, 10, 20, 0, 30))
      DB_POOL.with do |connection|
        original = connection.exec('SHOW TIME ZONE').first.values.first
        begin
          connection.exec("SET TIME ZONE 'America/Los_Angeles'")
          allow(DB_POOL).to receive(:with).and_yield(connection)
          result = described_class.daily_return_rate(window_days: 1, now: Time.utc(2026, 10, 21, 12))
          expect(result).to include(eligible_account_days: 1, returned_account_days: 1)
        ensure
          connection.exec_params("SELECT set_config('TimeZone', $1, false)", [original])
          allow(DB_POOL).to receive(:with).and_call_original
        end
      end
    end

    it 'distinguishes unavailable measurements from available empty activity' do
      expect(described_class.daily_return_rate).to include(available: true, eligible_account_days: 0)
      allow(DB_POOL).to receive(:with).and_raise(StandardError, 'test outage')
      expect(described_class.daily_return_rate).to include(available: false, overall_return_rate_pct: nil)
      allow(DB_POOL).to receive(:with).and_call_original
    end

    it 'excludes incomplete return days, future and unsupported events with fixed UTC boundaries' do
      now = Time.utc(2026, 10, 21, 12)
      user_id = create_user('utc-boundary@example.test')
      log_activity(user_id, Time.utc(2026, 10, 19, 23, 59))
      log_activity(user_id, Time.utc(2026, 10, 20))
      log_activity(user_id, Time.utc(2026, 10, 21))
      log_activity(user_id, Time.utc(2026, 10, 22))
      log_activity(user_id, Time.utc(2026, 10, 18))
      db.execute("UPDATE meme_activity_log SET activity_type = 'unsupported' WHERE created_at = ?", [Time.utc(2026, 10, 18)])
      result = described_class.daily_return_rate(window_days: 1, now: now)
      expect(result).to include(eligible_account_days: 1, returned_account_days: 1, overall_return_rate_pct: 100.0, timezone: 'UTC', available: true)
      expect(result[:days].map { |day| day[:date] }).to eq(['2026-10-19'])
    end

    it 'returns a safe empty shape when there is no activity' do
      result = RetentionService.daily_return_rate

      expect(result[:days]).to eq([])
      expect(result[:overall_return_rate_pct]).to be_nil
      expect(result[:window_days]).to eq(14)
    end

    it 'counts a user active on consecutive days as returned' do
      user_id = create_user("returning_user@example.com")
      log_activity(user_id, Time.now - 172800) # yesterday
      log_activity(user_id, Time.now - 86400) # completed return day

      result = RetentionService.daily_return_rate

      expect(result[:overall_return_rate_pct]).to eq(100.0)
      yesterday_row = result[:days].find { |d| d[:active_users] > 0 }
      expect(yesterday_row).not_to be_nil
      expect(yesterday_row[:returned_next_day]).to eq(1)
    end

    it 'does not count a user active on only one day as returned' do
      user_id = create_user("one_time_user@example.com")
      log_activity(user_id, Time.now - 172800) # yesterday only, no activity today

      result = RetentionService.daily_return_rate

      expect(result[:overall_return_rate_pct]).to eq(0.0)
    end

    it 'excludes anonymous activity (user_id IS NULL)' do
      db.execute(
        "INSERT INTO meme_activity_log (meme_url, activity_type, user_id, session_id, created_at) VALUES (?, 'view', NULL, ?, ?)",
        ["https://example.com/anon.jpg", "anon-session", Time.now - 172800]
      )

      result = RetentionService.daily_return_rate

      expect(result[:days]).to eq([])
    end

    it 'respects the window_days parameter' do
      user_id = create_user("windowed_user@example.com")
      log_activity(user_id, Time.now - 172800)
      log_activity(user_id, Time.now)

      result = RetentionService.daily_return_rate(window_days: 3)

      expect(result[:window_days]).to eq(3)
    end
  end

  describe '.avg_session_length_minutes' do
    it 'ignores future and unsupported activity when calculating recorded spans' do
      now = Time.utc(2026, 10, 21, 12)
      user_id = create_user('span-boundary@example.test')
      log_activity(user_id, now - 600)
      log_activity(user_id, now)
      log_activity(user_id, now + 3600)
      log_activity(user_id, now - 7200)
      db.execute("UPDATE meme_activity_log SET activity_type = 'unsupported' WHERE created_at = ?", [now - 7200])
      expect(described_class.avg_session_length_minutes(now: now)).to eq(10.0)
    end

    it 'returns nil when there is no multi-event activity' do
      expect(RetentionService.avg_session_length_minutes).to be_nil
    end

    it 'returns nil for a user with only a single event in a day' do
      user_id = create_user("single_event_user@example.com")
      log_activity(user_id, Time.now)

      expect(RetentionService.avg_session_length_minutes).to be_nil
    end

    it 'computes the gap between first and last same-day activity' do
      user_id = create_user("session_user@example.com")
      now = Time.utc(2026, 10, 21, 12)
      log_activity(user_id, now - 600)
      log_activity(user_id, now)

      result = RetentionService.avg_session_length_minutes(now: now)

      expect(result).to be_within(0.5).of(10.0)
    end
  end

  describe '.engagement_funnel' do
    it 'computes 7d view-to-like and view-to-save conversion rates and views per account day' do
      user_id = create_user('funnel@example.com')
      now = Time.utc(2026, 10, 21, 12)
      4.times { |i| log_activity(user_id, now - i * 60, url: "https://example.com/m#{i}.jpg") }
      db.execute("INSERT INTO meme_activity_log (meme_url, activity_type, user_id, created_at) VALUES ('https://example.com/m0.jpg', 'like', ?, ?)", [user_id, now])
      db.execute("INSERT INTO meme_activity_log (meme_url, activity_type, user_id, created_at) VALUES ('https://example.com/m1.jpg', 'save', ?, ?)", [user_id, now])

      funnel = RetentionService.engagement_funnel(window_days: 7, now: now)
      expect(funnel).to include(
        available: true,
        views: 4,
        likes: 1,
        saves: 1,
        like_conversion_pct: 25.0,
        save_conversion_pct: 25.0,
        avg_views_per_account_day: 4.0
      )
    end
  end
end
