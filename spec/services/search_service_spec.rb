require 'spec_helper'

describe SearchService do
  let(:popular_subreddits) { ['funny', 'memes', 'wholesome'] }

  describe '.search' do
    context 'with empty cache' do
      it 'returns empty array for nil query' do
        result = SearchService.search(nil, [], popular_subreddits)
        expect(result).to eq([])
      end

      it 'returns empty array for empty query' do
        result = SearchService.search('', [], popular_subreddits)
        expect(result).to eq([])
      end

      it 'returns empty array for whitespace query' do
        result = SearchService.search('   ', [], popular_subreddits)
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
        result = SearchService.search('funny', cache, popular_subreddits)
        expect(result.size).to be > 0
        expect(result.any? { |m| m["title"].downcase.include?("funny") }).to eq(true)
      end

      it 'finds results by subreddit' do
        result = SearchService.search('wholesome', cache, popular_subreddits)
        expect(result.any? { |m| m["subreddit"].downcase.include?("wholesome") }).to eq(true)
      end

      it 'ranks exact matches first' do
        result = SearchService.search('Funny Dog Meme', cache, popular_subreddits)
        expect(result.first["title"]).to include("Funny Dog Meme")
      end

      it 'ranks by engagement (likes * 2 + views)' do
        result = SearchService.search('meme', cache, popular_subreddits)
        # "Funny Dog Meme" (100*2 + 500 = 700) should rank higher than "Programming Meme" (50*2 + 200 = 300)
        expect(result.first["title"]).to include("Funny Dog Meme")
      end
    end

    context 'with database results' do
      before do
        # Insert memes into database
        DB.execute("INSERT INTO meme_stats (url, title, subreddit, likes, views) VALUES (?, ?, ?, ?, ?)",
          ['http://db.com/1.jpg', 'Popular Meme from DB', 'funny', 200, 1000])
        DB.execute("INSERT INTO meme_stats (url, title, subreddit, likes, views) VALUES (?, ?, ?, ?, ?)",
          ['http://db.com/2.jpg', 'Cool DB Meme', 'memes', 100, 500])
      end

      it 'searches database when cache is empty' do
        result = SearchService.search('Popular', [], popular_subreddits)
        expect(result.any? { |m| m["title"].include?("Popular Meme from DB") }).to eq(true)
      end

      it 'deduplicates cache and database results' do
        cache = [
          { "title" => "Popular Meme from DB", "url" => "http://db.com/1.jpg", "subreddit" => "funny", "likes" => 200, "views" => 1000 }
        ]
        result = SearchService.search('Popular', cache, popular_subreddits)
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
        result1 = SearchService.search('funny', cache, popular_subreddits)
        result2 = SearchService.search('FUNNY', cache, popular_subreddits)
        result3 = SearchService.search('Funny', cache, popular_subreddits)
        
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
        result = SearchService.search('Meme', large_cache, popular_subreddits)
        elapsed = Time.now - start_time

        expect(result.size).to be > 0
        expect(elapsed).to be < 1.0  # Should complete in under 1 second
      end
    end
  end
end
