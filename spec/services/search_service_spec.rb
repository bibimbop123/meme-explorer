require 'spec_helper'

# BUG FIX: every example in this file treated `SearchService.search`'s
# return value as a bare Array (`result.size`, `result.first`,
# `result.map`, `result == []`), but the real method
# (lib/services/search_service.rb) always returns a Hash
# (`{success:, results:, query:/error:, total:}`) - the exact same
# Hash-vs-Array mismatch bug found and fixed this session in
# routes/memes.rb's callers. Every example failed with either a real
# assertion mismatch or a TypeError (Hash#[] expects a key, not an
# Integer index). Extract `[:results]` from the returned Hash before
# asserting on it; the search behavior under test (matching, ranking,
# case-insensitivity, dedup, DB fallback) is otherwise unchanged.
describe SearchService do
  let(:popular_subreddits) { ['funny', 'memes', 'wholesome'] }

  def search_results(*args)
    SearchService.search(*args)[:results]
  end

  describe '.search' do
    context 'with empty cache' do
      it 'returns empty array for nil query' do
        result = search_results(nil, [], popular_subreddits)
        expect(result).to eq([])
      end

      it 'returns empty array for empty query' do
        result = search_results('', [], popular_subreddits)
        expect(result).to eq([])
      end

      it 'returns empty array for whitespace query' do
        result = search_results('   ', [], popular_subreddits)
        expect(result).to eq([])
      end
    end

    context 'with cache results' do
      let(:cache) do
        [
          { "title" => "Funny Dog Meme", "url" => "http://example.com/1.jpg", "subreddit" => "funny", "likes" => 100, "views" => 500 },
          { "title" => "Programming Meme", "url" => "http://example.com/2.jpg", "subreddit" => "memes", "likes" => 50, "views" => 200 },
          { "title" => "Wholesome Content", "url" => "http://example.com/3.jpg", "subreddit" => "wholesome", "likes" => 30, "views" => 100 }
        ]
      end

      it 'finds results by title' do
        result = search_results('funny', cache, popular_subreddits)
        expect(result.size).to be > 0
        expect(result.any? { |m| m["title"].downcase.include?("funny") }).to eq(true)
      end

      it 'finds results by subreddit' do
        result = search_results('wholesome', cache, popular_subreddits)
        expect(result.any? { |m| m["subreddit"].downcase.include?("wholesome") }).to eq(true)
      end

      it 'ranks exact matches first' do
        result = search_results('Funny Dog Meme', cache, popular_subreddits)
        expect(result.first["title"]).to include("Funny Dog Meme")
      end

      it 'ranks by engagement (likes * 2 + views)' do
        # BUG FIX: this assumed "Funny Dog Meme" (100*2+500=700 engagement)
        # would outrank "Programming Meme" (50*2+200=300) for query "meme"
        # purely on engagement - but SearchService.rank_results
        # (lib/services/search_service.rb) sorts on
        # [exact_match, title_match, subreddit_match, engagement], in that
        # priority order. Both titles match equally on exact/title_match,
        # but subreddit breaks the tie first: "Programming Meme"'s
        # subreddit is "memes" (contains "meme" - subreddit_match=2),
        # while "Funny Dog Meme"'s subreddit is "funny" (does not -
        # subreddit_match=3). Only among results tied on ALL of
        # exact/title/subreddit match does engagement decide the order -
        # this test's fixture wasn't actually engagement's tiebreak case.
        # Use two results with identical subreddits so engagement is
        # actually what's being compared.
        engagement_cache = [
          { "title" => "Low Engagement Meme", "url" => "http://example.com/low.jpg", "subreddit" => "test", "likes" => 5, "views" => 10 },
          { "title" => "High Engagement Meme", "url" => "http://example.com/high.jpg", "subreddit" => "test", "likes" => 100, "views" => 500 }
        ]
        result = search_results('meme', engagement_cache, popular_subreddits)
        expect(result.first["title"]).to eq("High Engagement Meme")
      end
    end

    context 'with database results' do
      it 'supplements sparse cache matches with database results without replacing cached media' do
        allow(MemeService).to receive(:fetch_reddit_memes).and_return([])
        allow(SearchService).to receive(:flatten_memes).and_return([])
        cache = [{ 'url' => 'https://example.com/cache-only.jpg', 'title' => 'Popular cached meme', 'subreddit' => 'local' }]
        result = search_results('popular', cache, popular_subreddits)
        expect(result.map { |m| m['url'] }).to contain_exactly('https://example.com/cache-only.jpg', 'http://db.com/1.jpg')
      end

      it 'keeps distinct local file matches when provider merging has no URL keys' do
        allow(MemeService).to receive(:fetch_reddit_memes).and_return([])
        allow(SearchService).to receive(:flatten_memes).and_return([])
        cache = %w[one two].map { |name| { 'file' => "/images/#{name}.jpg", 'title' => 'Unique sparse topic' } }
        result = search_results('unique sparse topic', cache, popular_subreddits)
        expect(result.map { |m| m['file'] }).to contain_exactly('/images/one.jpg', '/images/two.jpg')
      end

      it 'retains the existing fast path when three cached matches are available' do
        cache = 3.times.map { |i| { 'url' => "https://example.com/fast#{i}.jpg", 'title' => 'Fast topic' } }
        expect(MemeService).not_to receive(:fetch_reddit_memes)
        expect(SearchService).not_to receive(:flatten_memes)
        expect(DB).not_to receive(:execute)
        expect(search_results('fast topic', cache, popular_subreddits).size).to eq(3)
      end

      it 'finds community-only matches with cold cache and unavailable provider supply' do
        allow(MemeService).to receive(:fetch_reddit_memes).and_return([])
        allow(SearchService).to receive(:flatten_memes).and_return([])
        result = search_results('FuNnY', [], popular_subreddits)
        expect(result.map { |m| m['url'] }).to include('http://db.com/1.jpg')
        expect(result.map { |m| m['url'] }).not_to include('http://db.com/2.jpg')
      end

      it 'treats wildcard and escape characters literally in community names' do
        allow(MemeService).to receive(:fetch_reddit_memes).and_return([])
        allow(SearchService).to receive(:flatten_memes).and_return([])
        DB.execute('INSERT INTO meme_stats (url, title, subreddit) VALUES (?, ?, ?)', ['https://example.com/literal-community.jpg', 'Unrelated', 'topic_100%!'])
        DB.execute('INSERT INTO meme_stats (url, title, subreddit) VALUES (?, ?, ?)', ['https://example.com/other-community.jpg', 'Unrelated', 'topicX100more!'])
        result = search_results('topic_100%!', [], popular_subreddits)
        expect(result.map { |m| m['url'] }).to eq(['https://example.com/literal-community.jpg'])
      end

      it 'finds community-only local fallback entries without duplicating database media' do
        allow(MemeService).to receive(:fetch_reddit_memes).and_return([])
        allow(SearchService).to receive(:flatten_memes).and_return([
          { 'file' => '/images/funny1.jpeg', 'title' => 'Different title', 'subreddit' => 'funny' },
          { 'url' => 'http://db.com/1.jpg', 'title' => 'Popular Meme from DB', 'subreddit' => 'funny' }
        ])
        result = search_results('funny', [], popular_subreddits)
        expect(result.map { |m| m['url'] || m['file'] }).to contain_exactly('/images/funny1.jpeg', 'http://db.com/1.jpg')
      end

      before do
        # Insert memes into database
        DB.execute("INSERT INTO meme_stats (url, title, subreddit, likes, views) VALUES (?, ?, ?, ?, ?)",
          ['http://db.com/1.jpg', 'Popular Meme from DB', 'funny', 200, 1000])
        DB.execute("INSERT INTO meme_stats (url, title, subreddit, likes, views) VALUES (?, ?, ?, ?, ?)",
          ['http://db.com/2.jpg', 'Cool DB Meme', 'memes', 100, 500])
      end

      it 'searches database when cache is empty' do
        result = search_results('Popular', [], popular_subreddits)
        expect(result.any? { |m| m["title"].include?("Popular Meme from DB") }).to eq(true)
      end

      it 'deduplicates cache and database results' do
        cache = [
          { "title" => "Popular Meme from DB", "url" => "http://db.com/1.jpg", "subreddit" => "funny", "likes" => 200, "views" => 1000 }
        ]
        result = search_results('Popular', cache, popular_subreddits)
        # Should not have duplicates
        urls = result.map { |m| m["url"] }
        expect(urls.uniq.count).to eq(urls.count)
      end
    end

    context 'case insensitivity' do
      let(:cache) do
        [
          { "title" => "FUNNY MEME", "url" => "http://example.com/1.jpg", "subreddit" => "FUNNY", "likes" => 50, "views" => 100 }
        ]
      end

      it 'finds results regardless of case' do
        result1 = search_results('funny', cache, popular_subreddits)
        result2 = search_results('FUNNY', cache, popular_subreddits)
        result3 = search_results('Funny', cache, popular_subreddits)
        
        expect(result1.size).to eq(result2.size)
        expect(result2.size).to eq(result3.size)
      end
    end

    context 'performance' do
      it 'handles large result sets' do
        large_cache = 1000.times.map do |i|
          {
            "title" => "Meme #{i}",
            "url" => "http://example.com/#{i}.jpg",
            "subreddit" => ["funny", "memes", "wholesome"].sample,
            "likes" => rand(100),
            "views" => rand(1000)
          }
        end

        start_time = Time.now
        result = search_results('Meme', large_cache, popular_subreddits)
        elapsed = Time.now - start_time

        expect(result.size).to be > 0
        expect(elapsed).to be < 1.0  # Should complete in under 1 second
      end
    end
  end
end
