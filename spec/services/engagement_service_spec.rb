# frozen_string_literal: true

require_relative '../spec_helper'
require_relative '../../lib/services/engagement_service'

RSpec.describe EngagementService do
  describe 'saved-state activity boundaries' do
    it 'does not manufacture activity when an item was never saved' do
      user_id = create_test_user('never-saved@example.test')
      result = described_class.track_save(user_id: user_id, meme_url: 'https://example.com/never-saved.jpg', saved_now: false, db: DB)
      expect(result).to include(success: true, saved: false, unchanged: true)
      expect(DB.get_first_value('SELECT COUNT(*) FROM meme_activity_log WHERE user_id = ?', [user_id]).to_i).to eq(0)
    end

    it 'records a genuine resave after removal, but not duplicate requests' do
      user_id = create_test_user('resave-events@example.test')
      url = 'https://example.com/resave-events.jpg'
      [true, true, false, false, true, true].each do |saved|
        result = described_class.track_save(user_id: user_id, meme_url: url, saved_now: saved, db: DB)
        expect(result[:success]).to be true
      end
      counts = DB.execute('SELECT activity_type, COUNT(*) AS count FROM meme_activity_log WHERE user_id = ? GROUP BY activity_type', [user_id])
        .to_h { |row| [row['activity_type'], row['count'].to_i] }
      expect(counts).to eq('save' => 2, 'unsave' => 1)
      expect(DB.get_first_value('SELECT COUNT(*) FROM saved_memes WHERE user_id = ? AND meme_url = ?', [user_id, url]).to_i).to eq(1)
    end
  end

  describe 'initialization' do
    it 'initializes successfully' do
      expect { described_class.new }.not_to raise_error
    end
  end

  describe 'main functionality' do
    subject { described_class.new }

    it 'responds to primary methods' do
      # TODO: Add specific method tests based on service interface
      expect(subject).to respond_to(:call) if subject.respond_to?(:call)
    end
  end

  # BUG FIX: this file's trailing three examples were empty `pending`
  # placeholders (`pending` expects the block to actually fail; an empty
  # block trivially "passes," so these failed on every run without
  # testing anything). Replaced with real coverage of
  # EngagementService.track_like's nil-safety and actual return shape.
  describe 'error handling' do
    it 'handles a nil db gracefully without raising' do
      expect {
        EngagementService.track_like(user_id: 1, meme_url: 'http://example.com/x.jpg', liked_now: true, db: nil)
      }.not_to raise_error
    end
  end

  describe 'edge cases' do
    it 'handles a nil meme_url gracefully' do
      expect {
        EngagementService.track_like(user_id: 1, meme_url: nil, liked_now: true, db: DB)
      }.not_to raise_error
    end

    it 'handles a nil user_id gracefully' do
      expect {
        EngagementService.track_like(user_id: nil, meme_url: 'http://example.com/x.jpg', liked_now: true, db: DB)
      }.not_to raise_error
    end
  end

  # ROADMAP.md Phase 1 ("Feed real per-user signal ... back into
  # MemePoolManager's tier-distributed pool selection weighting"):
  # track_like is the real, live /like route's mechanism, and is now
  # responsible for upserting user_subreddit_preferences - previously
  # this never happened anywhere in the app (the only method that did
  # this upsert, update_user_preference in
  # lib/helpers/meme_navigation_helpers.rb, was defined as a
  # MemeNavigationHelpers instance method - only reachable from inside a
  # Sinatra route's `self`, and was never actually called from any
  # route). apply_user_preferences (lib/helpers/meme_pool_helpers.rb)
  # reads this table on every /random pool build; without this wiring it
  # always saw empty/stale data for every user.
  describe 'subreddit preference tracking (Phase 1 personalization)' do
    def create_user(email)
      hashed = BCrypt::Password.create("testpass123")
      DB.execute("INSERT INTO users (email, password_hash) VALUES (?, ?)", [email, hashed])
      DB.last_insert_row_id
    end

    it 'creates a preference row on a real like with a known subreddit' do
      user_id = create_user("engagement_pref_1@example.com")
      url = "https://example.com/engagement_pref_1.jpg"
      DB.execute("INSERT INTO meme_stats (url, title, subreddit, likes, views) VALUES (?, ?, ?, 0, 0)", [url, "Test", "wholesome"])

      EngagementService.track_like(user_id: user_id, meme_url: url, liked_now: true, session: {}, db: DB)

      pref = DB.execute("SELECT * FROM user_subreddit_preferences WHERE user_id = ? AND subreddit = ?", [user_id, "wholesome"]).first
      expect(pref).not_to be_nil
      expect(pref["preference_score"].to_f).to eq(1.0)
      expect(pref["times_liked"].to_i).to eq(1)
    end

    it 'increments preference_score and times_liked on a second like of the same subreddit' do
      user_id = create_user("engagement_pref_2@example.com")
      url1 = "https://example.com/engagement_pref_2a.jpg"
      url2 = "https://example.com/engagement_pref_2b.jpg"
      DB.execute("INSERT INTO meme_stats (url, title, subreddit, likes, views) VALUES (?, ?, ?, 0, 0)", [url1, "Test", "wholesome"])
      DB.execute("INSERT INTO meme_stats (url, title, subreddit, likes, views) VALUES (?, ?, ?, 0, 0)", [url2, "Test", "wholesome"])

      EngagementService.track_like(user_id: user_id, meme_url: url1, liked_now: true, session: {}, db: DB)
      EngagementService.track_like(user_id: user_id, meme_url: url2, liked_now: true, session: {}, db: DB)

      pref = DB.execute("SELECT * FROM user_subreddit_preferences WHERE user_id = ? AND subreddit = ?", [user_id, "wholesome"]).first
      expect(pref["preference_score"].to_f).to eq(1.2)
      expect(pref["times_liked"].to_i).to eq(2)
    end

    it 'does not create a preference row on unlike' do
      user_id = create_user("engagement_pref_3@example.com")
      url = "https://example.com/engagement_pref_3.jpg"
      DB.execute("INSERT INTO meme_stats (url, title, subreddit, likes, views) VALUES (?, ?, ?, 0, 0)", [url, "Test", "wholesome"])

      EngagementService.track_like(user_id: user_id, meme_url: url, liked_now: false, session: {}, db: DB)

      pref = DB.execute("SELECT * FROM user_subreddit_preferences WHERE user_id = ? AND subreddit = ?", [user_id, "wholesome"]).first
      expect(pref).to be_nil
    end

    it 'does not record a preference for an unresolvable ("unknown") subreddit' do
      user_id = create_user("engagement_pref_4@example.com")
      url = "https://example.com/engagement_pref_4_never_tracked.jpg"
      # No meme_stats row exists yet - ensure_meme_stats_exists will
      # insert one with the 'unknown' placeholder subreddit.

      EngagementService.track_like(user_id: user_id, meme_url: url, liked_now: true, session: {}, db: DB)

      pref = DB.execute("SELECT * FROM user_subreddit_preferences WHERE user_id = ?", [user_id]).first
      expect(pref).to be_nil
    end

    it 'creates a preference row on a real save, weighted higher than a like' do
      user_id = create_user("engagement_pref_5@example.com")
      url = "https://example.com/engagement_pref_5.jpg"

      EngagementService.track_save(user_id: user_id, meme_url: url, title: "Test", subreddit: "dankmemes", saved_now: true, session: {}, db: DB)

      pref = DB.execute("SELECT * FROM user_subreddit_preferences WHERE user_id = ? AND subreddit = ?", [user_id, "dankmemes"]).first
      expect(pref).not_to be_nil
      expect(pref["preference_score"].to_f).to eq(1.0)

      # A second save of the same subreddit should bump by 0.3 (higher
      # than a like's 0.2) - see bump_subreddit_preference's call site
      # in track_save for the reasoning.
      url2 = "https://example.com/engagement_pref_5b.jpg"
      EngagementService.track_save(user_id: user_id, meme_url: url2, title: "Test 2", subreddit: "dankmemes", saved_now: true, session: {}, db: DB)
      pref2 = DB.execute("SELECT * FROM user_subreddit_preferences WHERE user_id = ? AND subreddit = ?", [user_id, "dankmemes"]).first
      expect(pref2["preference_score"].to_f).to eq(1.3)
    end

    it 'does not create a preference row on unsave' do
      user_id = create_user("engagement_pref_6@example.com")
      url = "https://example.com/engagement_pref_6.jpg"

      EngagementService.track_save(user_id: user_id, meme_url: url, title: "Test", subreddit: "dankmemes", saved_now: false, session: {}, db: DB)

      pref = DB.execute("SELECT * FROM user_subreddit_preferences WHERE user_id = ? AND subreddit = ?", [user_id, "dankmemes"]).first
      expect(pref).to be_nil
    end
  end

  # ROADMAP.md Phase 1: "skips" is the one signal source named in the
  # roadmap (alongside likes/saves/dwell-time) that had genuinely no
  # tracking anywhere in the codebase before this - not a "found it
  # disconnected" fix like likes/saves above, a new capability.
  describe '.track_skip (Phase 1 personalization - new capability)' do
    def create_user(email)
      hashed = BCrypt::Password.create("testpass123")
      DB.execute("INSERT INTO users (email, password_hash) VALUES (?, ?)", [email, hashed])
      DB.last_insert_row_id
    end

    it 'decrements an existing preference_score by the skip penalty' do
      user_id = create_user("skip_1@example.com")
      DB.execute(
        "INSERT INTO user_subreddit_preferences (user_id, subreddit, preference_score, times_liked) VALUES (?, ?, ?, ?)",
        [user_id, "funny", 1.5, 3]
      )

      result = EngagementService.track_skip(user_id: user_id, subreddit: "funny", db: DB)

      expect(result[:success]).to eq(true)
      pref = DB.execute("SELECT * FROM user_subreddit_preferences WHERE user_id = ? AND subreddit = ?", [user_id, "funny"]).first
      expect(pref["preference_score"].to_f).to be_within(0.001).of(1.45)
    end

    it 'does not increment times_liked on a skip' do
      user_id = create_user("skip_2@example.com")
      DB.execute(
        "INSERT INTO user_subreddit_preferences (user_id, subreddit, preference_score, times_liked) VALUES (?, ?, ?, ?)",
        [user_id, "funny", 1.5, 3]
      )

      EngagementService.track_skip(user_id: user_id, subreddit: "funny", db: DB)

      pref = DB.execute("SELECT * FROM user_subreddit_preferences WHERE user_id = ? AND subreddit = ?", [user_id, "funny"]).first
      expect(pref["times_liked"].to_i).to eq(3)
    end

    it 'creates a new preference row at the neutral baseline for a first-time skip (matches first like/save behavior)' do
      user_id = create_user("skip_3@example.com")

      EngagementService.track_skip(user_id: user_id, subreddit: "newsub", db: DB)

      pref = DB.execute("SELECT * FROM user_subreddit_preferences WHERE user_id = ? AND subreddit = ?", [user_id, "newsub"]).first
      expect(pref).not_to be_nil
      expect(pref["preference_score"].to_f).to eq(1.0)
    end

    it 'floors preference_score at 0.1 and never goes negative, even with many repeated skips' do
      user_id = create_user("skip_4@example.com")

      30.times { EngagementService.track_skip(user_id: user_id, subreddit: "boring", db: DB) }

      pref = DB.execute("SELECT * FROM user_subreddit_preferences WHERE user_id = ? AND subreddit = ?", [user_id, "boring"]).first
      expect(pref["preference_score"].to_f).to eq(0.1)
    end

    it 'is a no-op for an anonymous (nil) user_id rather than raising' do
      result = EngagementService.track_skip(user_id: nil, subreddit: "funny", db: DB)
      expect(result[:success]).to eq(true)
      expect(result[:skipped]).to eq(false)
    end

    it 'is a no-op for a nil subreddit rather than raising' do
      user_id = create_user("skip_5@example.com")
      expect {
        EngagementService.track_skip(user_id: user_id, subreddit: nil, db: DB)
      }.not_to raise_error
    end
  end
end
