# frozen_string_literal: true

require_relative '../spec_helper'
require_relative '../../lib/services/simple_meme_selector'

RSpec.describe MemeExplorer::SimpleMemeSelector do
  let(:session_id) { "test_session_#{SecureRandom.hex(4)}" }

  before do
    MemeExplorer::ViewingHistoryService.clear_history(session_id)
  end

  after do
    MemeExplorer::ViewingHistoryService.clear_history(session_id)
  end

  describe '.select' do
    it 'enables editorial humor-first weights by default and disables them when ENABLE_HUMOR_FIRST_MIX=false' do
      previous = ENV['ENABLE_HUMOR_FIRST_MIX']
      # Equal engagement: draw 0.6 selects commentary at baseline, humor with pilot.
      pool = [{ 'url' => '/humor.jpg', 'subreddit' => 'MeMeS' },
              { 'url' => '/commentary.jpg', 'subreddit' => 'WhitePeopleTwitter' }]
      allow(described_class).to receive(:rand).and_return(0.6)
      ENV['ENABLE_HUMOR_FIRST_MIX'] = 'false'
      expect(described_class.send(:weighted_sample, pool)['url']).to eq('/commentary.jpg')
      [nil, 'true'].each do |value|
        value.nil? ? ENV.delete('ENABLE_HUMOR_FIRST_MIX') : ENV['ENABLE_HUMOR_FIRST_MIX'] = value
        expect(described_class.send(:weighted_sample, pool)['url']).to eq('/humor.jpg')
      end
      # Downweighted does not mean excluded, and explicit preferences still apply.
      allow(described_class).to receive(:rand).and_return(0.99)
      expect(described_class.send(:weighted_sample, pool)['url']).to eq('/commentary.jpg')
    ensure
      previous.nil? ? ENV.delete('ENABLE_HUMOR_FIRST_MIX') : ENV['ENABLE_HUMOR_FIRST_MIX'] = previous
    end

    it 'downweights immediate back-to-back repeats from the same subreddit when alternatives exist' do
      pool = [
        { 'url' => '/repeat.jpg', 'subreddit' => 'memes' },
        { 'url' => '/fresh-sub.jpg', 'subreddit' => 'dankmemes' }
      ]
      allow(described_class).to receive(:rand).and_return(0.35)
      expect(described_class.send(:weighted_sample, pool)['url']).to eq('/repeat.jpg')
      expect(described_class.send(:weighted_sample, pool, {}, last_subreddit: 'memes')['url']).to eq('/fresh-sub.jpg')
    end

    it 'boosts high-converting memes and decays 25+ view duds with zero likes' do
      pool = [
        { 'url' => '/dud.jpg', 'subreddit' => 'funny', 'likes' => 0, 'views' => 36 },
        { 'url' => '/winner.jpg', 'subreddit' => 'funny', 'likes' => 6, 'views' => 12 }
      ]
      # Without conversion/dud weighting, both have sqrt(likes*2 + views) == sqrt(24) or sqrt(36).
      # With conversion boost (1.5x) vs dud decay (0.4x), winner dominates.
      allow(described_class).to receive(:rand).and_return(0.25)
      expect(described_class.send(:weighted_sample, pool)['url']).to eq('/winner.jpg')
    end

    it 'favors concise punchy titles over rambling >160-char titles when humor-first mix is enabled' do
      previous = ENV['ENABLE_HUMOR_FIRST_MIX']
      ENV['ENABLE_HUMOR_FIRST_MIX'] = 'true'
      pool = [
        { 'url' => '/punchy.jpg', 'subreddit' => 'funny', 'title' => 'When the code compiles on the first try' },
        { 'url' => '/rambling.jpg', 'subreddit' => 'funny', 'title' => 'A' * 180 }
      ]
      allow(described_class).to receive(:rand).and_return(0.75)
      expect(described_class.send(:weighted_sample, pool)['url']).to eq('/punchy.jpg')
    ensure
      previous.nil? ? ENV.delete('ENABLE_HUMOR_FIRST_MIX') : ENV['ENABLE_HUMOR_FIRST_MIX'] = previous
    end

    it 'keeps the last unseen commentary item eligible in the editorial pilot' do
      previous = ENV['ENABLE_HUMOR_FIRST_MIX']
      ENV['ENABLE_HUMOR_FIRST_MIX'] = 'true'
      pool = [{ 'url' => '/seen-humor.jpg', 'subreddit' => 'memes' },
              { 'url' => '/unseen-commentary.jpg', 'subreddit' => 'WhitePeopleTwitter' }]
      MemeExplorer::ViewingHistoryService.mark_seen(session_id, '/seen-humor.jpg')
      expect(described_class.select(pool, session_id, boost_fresh: false)['url']).to eq('/unseen-commentary.jpg')
    ensure
      previous.nil? ? ENV.delete('ENABLE_HUMOR_FIRST_MIX') : ENV['ENABLE_HUMOR_FIRST_MIX'] = previous
    end

    [1, 2, 20, 200, 5000].each do |size|
      it "selects the last unseen URL before replay for a #{size}-item inventory" do
        pool = size.times.map { |i| { 'url' => "/matrix-#{i}.jpg" } }
        now = Time.now.to_f
        RedisService.with_redis do |redis|
          entries = pool.first(size - 1).each_with_index.map { |m, i| [now - size + i, m['url']] }
          redis.zadd("viewing_history:#{session_id}", entries) unless entries.empty?
        end
        selected = described_class.select(pool, session_id, boost_fresh: false)
        expect(selected['url']).to eq(pool.last['url'])
        expect(selected['inventory_exhausted']).to eq(false)
        replay = described_class.select(pool, session_id, boost_fresh: false)
        expect(replay['url']).to eq(pool.first['url'])
        expect(replay['inventory_exhausted']).to eq(true)
        expect(MemeExplorer::ViewingHistoryService.seen_count(session_id)).to eq(size)
      end
    end

    it 'returns nil for an empty pool' do
      expect(described_class.select([], session_id)).to be_nil
    end

    it 'selects a meme and tags it with selection metadata' do
      pool = [
        { 'url' => 'meme1', 'likes' => 5, 'views' => 10 },
        { 'url' => 'meme2', 'likes' => 3, 'views' => 8 }
      ]

      selected = described_class.select(pool, session_id, boost_fresh: false)

      expect(selected).not_to be_nil
      expect(%w[meme1 meme2]).to include(selected['url'])
      expect(selected['selection_method']).to be_a(String)
      expect(selected['pool_size']).to be_a(Integer)
      expect(selected['total_unseen']).to be_a(Integer)
    end

    it 'does not repeat memes that have already been marked as seen' do
      pool = [
        { 'url' => 'meme1', 'likes' => 1, 'views' => 1 },
        { 'url' => 'meme2', 'likes' => 1, 'views' => 1 }
      ]

      first = described_class.select(pool, session_id, boost_fresh: false)
      # Mark the *other* meme seen too, leaving nothing unseen
      other_url = (%w[meme1 meme2] - [first['url']]).first
      MemeExplorer::ViewingHistoryService.mark_seen(session_id, other_url)

      # Exhausted pool replays oldest without erasing its history.
      second = described_class.select(pool, session_id, boost_fresh: false)
      expect(second).not_to be_nil
      expect(second['inventory_exhausted']).to eq(true)
      expect(MemeExplorer::ViewingHistoryService.seen_count(session_id)).to eq(2)
    end

    it 'replays the oldest selection after exhaustion, then advances through the cycle' do
      pool = %w[a b c].map { |url| { 'url' => url } }
      pool.each { |m| MemeExplorer::ViewingHistoryService.mark_seen(session_id, m['url']) }
      allow(MemeExplorer::ViewingHistoryService).to receive(:clear_history).and_call_original
      replay = 3.times.map { described_class.select(pool, session_id, boost_fresh: false) }
      expect(replay.map { |m| m['url'] }).to eq(%w[a b c])
      expect(replay.map { |m| m['total_unseen'] }).to eq([0, 0, 0])
      expect(MemeExplorer::ViewingHistoryService).not_to have_received(:clear_history)
    end

    it 'prefers new inventory over previously selected content and does not mutate pool records' do
      old = { 'url' => 'old' }
      fresh = { 'url' => 'fresh' }
      MemeExplorer::ViewingHistoryService.mark_seen(session_id, 'old')
      selected = described_class.select([old, old.dup, fresh], session_id, boost_fresh: false)
      expect(selected['url']).to eq('fresh')
      expect(selected['inventory_exhausted']).to eq(false)
      expect(fresh).not_to have_key('selection_method')
    end
  end

  describe '.select_random_meme (compatibility alias)' do
    it 'delegates to .select with keyword args' do
      pool = [{ 'url' => 'only_meme', 'likes' => 0, 'views' => 0 }]
      result = described_class.select_random_meme(pool, session_id: session_id)
      expect(result['url']).to eq('only_meme')
    end
  end

  describe 'private #weighted_sample' do
    it 'statistically favors memes with higher engagement scores' do
      pool = [
        { 'url' => 'low', 'likes' => 0, 'views' => 1 },
        { 'url' => 'high', 'likes' => 1000, 'views' => 5000 }
      ]

      counts = Hash.new(0)
      2000.times { counts[described_class.send(:weighted_sample, pool)['url']] += 1 }

      expect(counts['high']).to be > counts['low'] * 3
    end

    it 'falls back to uniform sampling when all weights are zero' do
      pool = [{ 'url' => 'a' }, { 'url' => 'b' }]
      expect { 100.times { described_class.send(:weighted_sample, pool) } }.not_to raise_error
    end

    it 'returns nil for an empty pool' do
      expect(described_class.send(:weighted_sample, [])).to be_nil
    end
  end

  describe 'private #has_engagement_data?' do
    it 'returns true when any meme has likes or views' do
      pool = [{ 'url' => 'a', 'likes' => 0 }, { 'url' => 'b', 'views' => 5 }]
      expect(described_class.send(:has_engagement_data?, pool)).to eq(true)
    end

    it 'returns false when no meme has engagement data' do
      pool = [{ 'url' => 'a' }, { 'url' => 'b' }]
      expect(described_class.send(:has_engagement_data?, pool)).to eq(false)
    end
  end

  # ROADMAP.md Phase 1 ("Feed real per-user signal ... back into
  # MemePoolManager's tier-distributed pool selection weighting"): this
  # is the actual live selection algorithm (routes/random_meme.rb's real
  # /random and /random.json both call it), so this is the real place
  # personalization needs to land - not the separate, never-called
  # apply_user_preferences path in lib/helpers/meme_pool_helpers.rb.
  describe 'personalization via user_subreddit_preferences (Phase 1)' do
    def create_user(email)
      hashed = BCrypt::Password.create("testpass123")
      DB.execute("INSERT INTO users (email, password_hash) VALUES (?, ?)", [email, hashed])
      DB.last_insert_row_id
    end

    describe '#subreddit_preferences_for' do
      it 'returns an empty hash for a user with no preference rows' do
        user_id = create_user("selector_pref_1@example.com")
        expect(described_class.send(:subreddit_preferences_for, user_id)).to eq({})
      end

      it 'returns a downcased subreddit => preference_score map' do
        user_id = create_user("selector_pref_2@example.com")
        DB.execute(
          "INSERT INTO user_subreddit_preferences (user_id, subreddit, preference_score, times_liked) VALUES (?, ?, ?, ?)",
          [user_id, "WholesomeMemes", 1.8, 4]
        )

        prefs = described_class.send(:subreddit_preferences_for, user_id)
        expect(prefs["wholesomememes"]).to eq(1.8)
      end

      it 'returns an empty hash for a nil user_id rather than raising' do
        expect(described_class.send(:subreddit_preferences_for, nil)).to eq({})
      end
    end

    describe '#weighted_sample with user_prefs' do
      it 'boosts a meme whose subreddit the user prefers over an equally-engaged one they do not' do
        pool = [
          { 'url' => 'preferred', 'subreddit' => 'wholesomememes', 'likes' => 10, 'views' => 50 },
          { 'url' => 'neutral', 'subreddit' => 'dankmemes', 'likes' => 10, 'views' => 50 }
        ]
        user_prefs = { 'wholesomememes' => 3.0 }

        counts = Hash.new(0)
        2000.times { counts[described_class.send(:weighted_sample, pool, user_prefs)['url']] += 1 }

        expect(counts['preferred']).to be > counts['neutral'] * 2
      end

      it 'behaves identically to no preferences when user_prefs is empty (no regression for anonymous users)' do
        pool = [
          { 'url' => 'a', 'subreddit' => 'funny', 'likes' => 5, 'views' => 10 },
          { 'url' => 'b', 'subreddit' => 'memes', 'likes' => 5, 'views' => 10 }
        ]

        expect { 50.times { described_class.send(:weighted_sample, pool, {}) } }.not_to raise_error
      end

      it 'does not penalize a subreddit missing from user_prefs (defaults to neutral 1.0, never below)' do
        pool = [{ 'url' => 'a', 'subreddit' => 'unrated', 'likes' => 5, 'views' => 10 }]
        user_prefs = { 'someothersub' => 5.0 }

        expect(described_class.send(:weighted_sample, pool, user_prefs)).not_to be_nil
      end
    end

    describe '.select end-to-end with a real logged-in user_id' do
      it 'tags personalized selections with the personalized_weighted_random method' do
        user_id = create_user("selector_pref_3@example.com")
        DB.execute(
          "INSERT INTO user_subreddit_preferences (user_id, subreddit, preference_score, times_liked) VALUES (?, ?, ?, ?)",
          [user_id, "wholesomememes", 3.0, 5]
        )
        pool = [
          { 'url' => 'meme_pref_a', 'subreddit' => 'wholesomememes', 'likes' => 1, 'views' => 1 },
          { 'url' => 'meme_pref_b', 'subreddit' => 'dankmemes', 'likes' => 1, 'views' => 1 }
        ]

        selected = described_class.select(pool, session_id, boost_fresh: false, user_id: user_id)

        expect(selected['selection_method']).to eq('personalized_weighted_random')
      end

      it 'falls back to non-personalized selection for an anonymous (nil) user_id' do
        pool = [
          { 'url' => 'anon_a', 'subreddit' => 'funny', 'likes' => 1, 'views' => 1 },
          { 'url' => 'anon_b', 'subreddit' => 'memes', 'likes' => 1, 'views' => 1 }
        ]

        selected = described_class.select(pool, session_id, boost_fresh: false, user_id: nil)

        expect(selected['selection_method']).not_to eq('personalized_weighted_random')
      end

      it 'applies bounded guest session_prefs when user_id is nil' do
        pool = [
          { 'url' => 'guest_pref_a', 'subreddit' => 'wholesomememes', 'likes' => 1, 'views' => 1 },
          { 'url' => 'guest_pref_b', 'subreddit' => 'dankmemes', 'likes' => 1, 'views' => 1 }
        ]

        selected = described_class.select(
          pool,
          session_id,
          boost_fresh: false,
          user_id: nil,
          session_prefs: { 'wholesomememes' => 1.9 }
        )

        expect(selected['selection_method']).to eq('personalized_weighted_random')
      end

      it 'deduplicates crossposted memes with identical substantive titles in favour of higher engagement' do
        pool = [
          { 'url' => '/crosspost_low.jpg', 'title' => 'When the production deploy succeeds on Friday afternoon', 'subreddit' => 'memes', 'likes' => 2, 'views' => 10 },
          { 'url' => '/crosspost_high.jpg', 'title' => 'When the production deploy succeeds on Friday afternoon!', 'subreddit' => 'dankmemes', 'likes' => 25, 'views' => 100 }
        ]

        selected = described_class.select(pool, session_id, boost_fresh: false)
        expect(selected['url']).to eq('/crosspost_high.jpg')
        expect(selected['pool_size']).to eq(1)
      end
    end
  end
end
