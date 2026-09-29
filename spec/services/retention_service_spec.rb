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
    it 'returns a safe empty shape when there is no activity' do
      result = RetentionService.daily_return_rate

      expect(result[:days]).to eq([])
      expect(result[:overall_return_rate_pct]).to be_nil
      expect(result[:window_days]).to eq(14)
    end

    it 'counts a user active on consecutive days as returned' do
      user_id = create_user("returning_user@example.com")
      log_activity(user_id, Time.now - 86400) # yesterday
      log_activity(user_id, Time.now)         # today

      result = RetentionService.daily_return_rate

      expect(result[:overall_return_rate_pct]).to eq(100.0)
      yesterday_row = result[:days].find { |d| d[:active_users] > 0 }
      expect(yesterday_row).not_to be_nil
      expect(yesterday_row[:returned_next_day]).to eq(1)
    end

    it 'does not count a user active on only one day as returned' do
      user_id = create_user("one_time_user@example.com")
      log_activity(user_id, Time.now - 86400) # yesterday only, no activity today

      result = RetentionService.daily_return_rate

      expect(result[:overall_return_rate_pct]).to eq(0.0)
    end

    it 'excludes anonymous activity (user_id IS NULL)' do
      db.execute(
        "INSERT INTO meme_activity_log (meme_url, activity_type, user_id, session_id, created_at) VALUES (?, 'view', NULL, ?, ?)",
        ["https://example.com/anon.jpg", "anon-session", Time.now - 86400]
      )

      result = RetentionService.daily_return_rate

      expect(result[:days]).to eq([])
    end

    it 'respects the window_days parameter' do
      user_id = create_user("windowed_user@example.com")
      log_activity(user_id, Time.now - 86400)
      log_activity(user_id, Time.now)

      result = RetentionService.daily_return_rate(window_days: 3)

      expect(result[:window_days]).to eq(3)
    end
  end

  describe '.avg_session_length_minutes' do
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
      log_activity(user_id, Time.now - 600) # 10 minutes ago
      log_activity(user_id, Time.now)

      result = RetentionService.avg_session_length_minutes

      expect(result).to be_within(0.5).of(10.0)
    end
  end
end
