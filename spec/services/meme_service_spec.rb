# Comprehensive test suite for MemeService
# Week 2: Core Service Tests

require_relative '../spec_helper'

RSpec.describe MemeService do
  let(:cache) { {memes: [], last_refresh: nil} }
  let(:db) { DB }
  let(:redis) { double('Redis', get: nil, setex: nil) }
  let(:memes_yaml) { 
    {
      "funny" => [
        {"file" => "memes/test1.jpg", "title" => "Test Meme 1"},
        {"file" => "memes/test2.jpg", "title" => "Test Meme 2"}
      ]
    }
  }
  let(:service) { described_class.new(cache, db, redis, memes_yaml) }
  let(:popular_subreddits) { ['funny', 'memes', 'dankmemes'] }
  let(:fetch_method) { proc { |subreddits, limit| [] } }

  before do
    # Clean database
    db.execute("DELETE FROM meme_stats")
    db.execute("DELETE FROM broken_images") rescue nil
  end

  describe '#random_memes_pool' do
    context 'with fresh cache' do
      it 'returns cached memes when cache is fresh' do
        cached_memes = [{"url" => "https://example.com/cached.jpg"}]
        cache[:memes] = cached_memes
        cache[:last_refresh] = Time.now - 60 # 60 seconds ago

        result = service.random_memes_pool(popular_subreddits, fetch_method)
        expect(result).to eq(cached_memes)
      end

      it 'does not call fetch_method when cache is fresh' do
        cache[:memes] = [{"url" => "https://example.com/cached.jpg"}]
        cache[:last_refresh] = Time.now - 60
        
        expect(fetch_method).not_to receive(:call)
        service.random_memes_pool(popular_subreddits, fetch_method)
      end
    end

    context 'with stale cache' do
      it 'fetches new memes when cache is stale' do
        cache[:last_refresh] = Time.now - 200 # 200 seconds ago
        
        api_memes = [{"url" => "https://i.redd.it/test.jpg", "title" => "API Meme"}]
        fetch_proc = proc { |subreddits, limit| api_memes }
        
        result = service.random_memes_pool(popular_subreddits, fetch_proc)
        expect(result.length).to be > 0
      end

      it 'combines API memes with local memes' do
        api_memes = [{"url" => "https://i.redd.it/api.jpg"}]
        fetch_proc = proc { |subreddits, limit| api_memes }

        # BUG FIX: `memes_yaml`'s fixture ("memes/test1.jpg", from the
        # top-level `let(:memes_yaml)`) is validated against a real
        # `File.exist?(File.join("public", m["file"]))` check
        # (lib/services/meme_service.rb) - these fixture files were never
        # actually on disk, so local memes were always filtered out and
        # the "local memes included" assertion below could never pass.
        # Create a real, temporary file at exactly the path the fixture
        # claims BEFORE the one call to random_memes_pool (its result gets
        # cached on `service`, so a second call wouldn't re-validate
        # anyway), then clean it up.
        fixture_path = File.join("public", "memes", "test1.jpg")
        FileUtils.mkdir_p(File.dirname(fixture_path))
        File.write(fixture_path, "fixture") unless File.exist?(fixture_path)

        begin
          result = service.random_memes_pool(popular_subreddits, fetch_proc)

          # BUG FIX: this asserted the API meme gets filtered out, but
          # random_memes_pool's validation accepts any URL with a
          # recognized image/video extension OR a known media-hosting
          # domain - "https://i.redd.it/api.jpg" matches BOTH (`.jpg`
          # extension and the `i.redd.it` domain), so it's genuinely valid
          # media and is correctly kept, not filtered. The test's own
          # inline comment ("Will be filtered") didn't match the method's
          # real, intentional behavior.
          expect(result.any? { |m| m["url"]&.include?("api.jpg") }).to be true
          expect(result.any? { |m| m["file"] }).to be true # Local memes included
        ensure
          File.delete(fixture_path) if File.exist?(fixture_path)
        end
      end
    end

    context 'meme validation' do
      it 'filters out reddit post URLs' do
        api_memes = [
          {"url" => "https://www.reddit.com/r/funny/comments/abc123/title/"},
          {"url" => "https://i.redd.it/valid.jpg"}
        ]
        fetch_proc = proc { |subreddits, limit| api_memes }
        
        result = service.random_memes_pool(popular_subreddits, fetch_proc)
        reddit_posts = result.select { |m| m["url"]&.include?("/comments/") }
        expect(reddit_posts).to be_empty
      end

      it 'accepts memes with valid image extensions' do
        api_memes = [
          {"url" => "https://example.com/meme.jpg"},
          {"url" => "https://example.com/meme.png"},
          {"url" => "https://example.com/meme.gif"}
        ]
        fetch_proc = proc { |subreddits, limit| api_memes }
        
        result = service.random_memes_pool(popular_subreddits, fetch_proc)
        expect(result.length).to be > 0
      end

      it 'accepts memes from known media domains' do
        api_memes = [
          {"url" => "https://i.redd.it/abc123"},
          {"url" => "https://i.imgur.com/xyz789"}
        ]
        fetch_proc = proc { |subreddits, limit| api_memes }
        
        result = service.random_memes_pool(popular_subreddits, fetch_proc)
        expect(result.length).to be > 0
      end

      it 'removes duplicate memes by URL' do
        api_memes = [
          {"url" => "https://i.redd.it/test.jpg", "title" => "Test 1"},
          {"url" => "https://i.redd.it/test.jpg", "title" => "Test 2"}
        ]
        fetch_proc = proc { |subreddits, limit| api_memes }
        
        result = service.random_memes_pool(popular_subreddits, fetch_proc)
        urls = result.map { |m| m["url"] }.compact
        expect(urls.uniq.length).to eq(urls.length)
      end
    end

    context 'fallback behavior' do
      it 'returns local memes when API fails' do
        failing_fetch = proc { |subreddits, limit| raise "API Error" }
        
        result = service.random_memes_pool(popular_subreddits, failing_fetch)
        expect(result).not_to be_empty
        expect(result.all? { |m| m["file"] }).to be true
      end

      it 'uses local memes when validation filters everything' do
        # API memes that will be filtered out
        api_memes = [
          {"url" => "https://www.reddit.com/r/funny/comments/invalid/"}
        ]
        fetch_proc = proc { |subreddits, limit| api_memes }
        
        result = service.random_memes_pool(popular_subreddits, fetch_proc)
        expect(result).not_to be_empty
      end
    end

    context 'file path normalization' do
      it 'removes leading slashes from file paths' do
        yaml_with_slash = {
          "test" => [{"file" => "/memes/test.jpg"}]
        }
        service_with_slash = described_class.new(cache, db, redis, yaml_with_slash)
        
        result = service_with_slash.random_memes_pool(popular_subreddits, fetch_method)
        result.each do |meme|
          if meme["file"]
            expect(meme["file"]).not_to start_with("/")
          end
        end
      end
    end
  end

  # BUG FIX: this whole block was calling MemeService#toggle_like/#get_likes
  # as instance methods on `service`, but both are actually class methods
  # (`def self.toggle_like`, `def self.get_likes` - see lib/services/meme_service.rb)
  # - a NoMethodError on every example, none of it ever exercising real
  # code. It also inserted into a `last_seen` column that has never existed
  # on `meme_stats` (see db/postgres_schema.sql: the real columns are
  # `likes`, `views`, `updated_at`) - a PG::UndefinedColumn on every insert
  # that got that far. And `toggle_like`'s real signature is
  # `(url, liked_now, session, db)`, not `(url, liked_now)`. Rewritten
  # against the actual class-method API and actual schema; behavior under
  # test (increment/decrement/floor-at-zero/nil-safety) is unchanged.
  describe '.toggle_like' do
    let(:meme_url) { 'https://example.com/test.jpg' }
    let(:fake_session) { {} }

    context 'liking a meme' do
      it 'increments like count for new meme' do
        MemeService.toggle_like(meme_url, true, fake_session, db)

        count = db.get_first_value("SELECT likes FROM meme_stats WHERE url = ?", [meme_url]).to_i
        expect(count).to eq(1)
      end

      it 'increments existing like count' do
        db.execute("INSERT INTO meme_stats (url, likes, updated_at) VALUES (?, 1, CURRENT_TIMESTAMP)",
                   [meme_url])

        MemeService.toggle_like(meme_url, true, fake_session, db)
        count = db.get_first_value("SELECT likes FROM meme_stats WHERE url = ?", [meme_url]).to_i
        expect(count).to eq(2)
      end

      it 'updates updated_at timestamp' do
        before_time = Time.now - 1000
        db.execute("INSERT INTO meme_stats (url, likes, updated_at) VALUES (?, 1, ?)",
                   [meme_url, before_time])

        MemeService.toggle_like(meme_url, true, fake_session, db)
        updated_at = db.get_first_value("SELECT updated_at FROM meme_stats WHERE url = ?", [meme_url])
        expect(Time.parse(updated_at.to_s)).to be > before_time
      end
    end

    context 'unliking a meme' do
      it 'decrements like count' do
        db.execute("INSERT INTO meme_stats (url, likes, updated_at) VALUES (?, 5, CURRENT_TIMESTAMP)",
                   [meme_url])

        MemeService.toggle_like(meme_url, false, fake_session, db)
        count = db.get_first_value("SELECT likes FROM meme_stats WHERE url = ?", [meme_url]).to_i
        expect(count).to eq(4)
      end

      it 'does not go below zero' do
        db.execute("INSERT INTO meme_stats (url, likes, updated_at) VALUES (?, 0, CURRENT_TIMESTAMP)",
                   [meme_url])

        MemeService.toggle_like(meme_url, false, fake_session, db)
        count = db.get_first_value("SELECT likes FROM meme_stats WHERE url = ?", [meme_url]).to_i
        expect(count).to eq(0)
      end
    end

    context 'edge cases' do
      it 'handles nil URL gracefully' do
        expect { MemeService.toggle_like(nil, true, fake_session, db) }.not_to raise_error
      end

      it 'handles empty URL gracefully' do
        expect { MemeService.toggle_like('', true, fake_session, db) }.not_to raise_error
      end
    end
  end

  describe '.get_likes' do
    it 'returns 0 for meme with no stats' do
      likes = MemeService.get_likes('https://example.com/unknown.jpg', db)
      expect(likes).to eq(0)
    end

    it 'returns correct like count for existing meme' do
      url = 'https://example.com/liked.jpg'
      db.execute("INSERT INTO meme_stats (url, likes, updated_at) VALUES (?, 42, CURRENT_TIMESTAMP)",
                 [url])

      likes = MemeService.get_likes(url, db)
      expect(likes).to eq(42)
    end

    it 'handles nil URL' do
      likes = MemeService.get_likes(nil, db)
      expect(likes).to eq(0)
    end
  end

  # BUG FIX: every example here called `service.search_memes(query, pool)`
  # (2 args), but the real signature is
  # `search_memes(query, cache_memes, popular_subreddits, fetch_method, db)`
  # (5 args) - an ArgumentError on every single example, none of it ever
  # exercising real search behavior. Also, the real method always falls
  # through to Tier 2 (API) whenever Tier 1 cache results are fewer than 3
  # (see lib/services/meme_service.rb), and to Tier 3 (DB/YAML) whenever
  # results are still empty - so a fetch_method/db must be supplied and
  # behave sanely for these small 1-3-item pools, not just be nil. The
  # "empty"/"nil query" short-circuit and single/multi-term matching
  # behavior under test is unchanged; only the call is fixed to match the
  # real API.
  describe '#search_memes' do
    let(:search_pool) do
      [
        {"title" => "Funny Cat Meme", "url" => "https://example.com/cat.jpg"},
        {"title" => "Dog Running", "url" => "https://example.com/dog.jpg"},
        {"title" => "Funny Dog Video", "url" => "https://example.com/funny-dog.mp4"}
      ]
    end
    let(:empty_fetch) { proc { |subreddits, limit| [] } }

    before do
      cache[:memes] = search_pool
      cache[:last_refresh] = Time.now
    end

    it 'finds memes matching single query term' do
      results = service.search_memes('cat', search_pool, popular_subreddits, empty_fetch, db)
      expect(results.length).to eq(1)
      expect(results.first["title"]).to include("Cat")
    end

    it 'finds memes matching multiple terms' do
      results = service.search_memes('funny dog', search_pool, popular_subreddits, empty_fetch, db)
      expect(results.length).to be >= 1
      expect(results.any? { |m| m["title"].include?("Funny Dog") }).to be true
    end

    it 'returns empty array when no matches' do
      results = service.search_memes('elephant', search_pool, popular_subreddits, empty_fetch, db)
      expect(results).to eq([])
    end

    it 'is case insensitive' do
      results = service.search_memes('FUNNY', search_pool, popular_subreddits, empty_fetch, db)
      expect(results.length).to be >= 1
    end

    it 'searches in subreddit field' do
      pool_with_subreddit = [
        {"title" => "Test", "subreddit" => "funny"}
      ]
      results = service.search_memes('funny', pool_with_subreddit, popular_subreddits, empty_fetch, db)
      expect(results.length).to eq(1)
    end

    it 'handles empty query' do
      results = service.search_memes('', search_pool, popular_subreddits, empty_fetch, db)
      expect(results).to eq([])
    end

    it 'handles nil query' do
      results = service.search_memes(nil, search_pool, popular_subreddits, empty_fetch, db)
      expect(results).to eq([])
    end
  end

  describe '#calculate_humor_score' do
    it 'returns base score for meme with no stats' do
      score = service.calculate_humor_score({"url" => "https://example.com/new.jpg"})
      expect(score).to be_a(Float)
      expect(score).to be > 0
    end

    it 'increases score for memes with likes' do
      url = 'https://example.com/popular.jpg'
      # BUG FIX: this test inserted `likes` into the meme_stats DB table
      # expecting that to raise the score, but calculate_humor_score
      # (lib/services/meme_service.rb) never queries the DB - it reads
      # `meme["likes"]` directly off the hash it's passed. A DB insert here
      # was both invalid (`last_seen` isn't a real column - see the fix
      # above) and, even with valid columns, would never have been read by
      # the method under test. Pass `likes` directly on the meme hash,
      # matching how calculate_humor_score actually consumes it.
      score = service.calculate_humor_score({"url" => url, "likes" => 100})
      base_score = service.calculate_humor_score({"url" => "https://example.com/new.jpg"})
      
      expect(score).to be > base_score
    end

    it 'handles memes without URL' do
      score = service.calculate_humor_score({"file" => "memes/local.jpg"})
      expect(score).to be_a(Float)
      expect(score).to be > 0
    end
  end

  describe 'integration tests' do
    it 'full workflow: fetch, cache, search, like' do
      # 1. Fetch memes
      api_memes = [
        {"url" => "https://i.redd.it/cat.jpg", "title" => "Funny Cat"}
      ]
      fetch_proc = proc { |subreddits, limit| api_memes }
      pool = service.random_memes_pool(popular_subreddits, fetch_proc)
      expect(pool).not_to be_empty
      
      # 2. Search memes
      if pool.any? { |m| m["title"]&.include?("Cat") }
        results = service.search_memes('cat', pool, popular_subreddits, fetch_proc, db)
        expect(results.length).to be > 0
      end
      
      # 3. Like a meme (toggle_like/get_likes are class methods, not
      # instance methods - see BUG FIX note on the '.toggle_like' block above)
      if pool.first && pool.first["url"]
        MemeService.toggle_like(pool.first["url"], true, {}, db)
        likes = MemeService.get_likes(pool.first["url"], db)
        expect(likes).to eq(1)
      end
    end
  end
end
