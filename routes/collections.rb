# frozen_string_literal: true

# ============================================
# PHASE 3: DISCOVERY ENGINE - Collection Routes
# ============================================
# Collection landing pages for curated meme collections
# Part of the 90 → 92/100 satisfaction improvement

get '/collections' do
  # List all available collections
  @collections = load_curated_collections['collections']
  erb :collections_index
end

get '/collections/:slug' do
  collections_data = load_curated_collections
  collection_slug = params[:slug]
  
  # Find the collection by slug
  @collection = collections_data['collections'].find do |c|
    c['slug'] == collection_slug
  end
  
  halt 404, 'Collection not found' unless @collection
  
  # Get subreddits for this collection
  subreddits = @collection['subreddits']
  
  # Fetch memes from these subreddits (cached)
  cache_key = "collection:#{collection_slug}:memes"
  @memes = CACHE_MANAGER.fetch(cache_key, expires_in: 300) do
    fetch_collection_memes(subreddits, limit: 50)
  end
  
  # Get trending within this collection
  @trending = get_trending_in_collection(subreddits, limit: 10)
  
  # Collection stats
  @stats = {
    total_memes: @memes.length,
    total_likes: @memes.sum { |m| m['likes'] || 0 },
    avg_score: @memes.any? ? (@memes.sum { |m| m['score'] || 0 } / @memes.length).round : 0
  }
  
  erb :collection_page
end

# Helper: Fetch memes from multiple subreddits
def fetch_collection_memes(subreddits, limit: 50)
  memes = []
  
  subreddits.each do |subreddit|
    # Query database for memes from this subreddit
    results = DB.execute(
      "SELECT * FROM meme_stats WHERE subreddit = ? ORDER BY (likes * 2 + views) DESC LIMIT ?",
      [subreddit, limit / subreddits.length]
    )
    
    results.each do |row|
      memes << {
        'url' => row['url'],
        'title' => row['title'],
        'subreddit' => row['subreddit'],
        'likes' => row['likes'] || 0,
        'views' => row['views'] || 0,
        'score' => (row['likes'] || 0) * 2 + (row['views'] || 0),
        'created_at' => row['created_at']
      }
    end
  end
  
  # Sort by engagement score
  memes.sort_by { |m| -m['score'] }.take(limit)
rescue => e
  logger.error "Error fetching collection memes: #{e.message}"
  []
end

# Helper: Get trending memes within a collection
def get_trending_in_collection(subreddits, limit: 10)
  # Get recent memes (last 7 days) with high engagement
  cutoff_date = (Time.now - (7 * 24 * 60 * 60)).strftime('%Y-%m-%d %H:%M:%S')
  
  memes = []
  subreddits.each do |subreddit|
    results = DB.execute(
      "SELECT * FROM meme_stats 
       WHERE subreddit = ? 
       AND created_at >= ? 
       ORDER BY (likes * 3 + views) DESC 
       LIMIT ?",
      [subreddit, cutoff_date, limit / subreddits.length]
    )
    
    results.each do |row|
      memes << {
        'url' => row['url'],
        'title' => row['title'],
        'subreddit' => row['subreddit'],
        'likes' => row['likes'] || 0,
        'views' => row['views'] || 0,
        'trending_score' => (row['likes'] || 0) * 3 + (row['views'] || 0)
      }
    end
  end
  
  memes.sort_by { |m| -m['trending_score'] }.take(limit)
rescue => e
  logger.error "Error getting trending in collection: #{e.message}"
  []
end

# API endpoint: Get recommendations based on user likes
get '/api/recommendations' do
  content_type :json
  
  require_auth!
user_id = current_user_id
  
  # Get user's liked memes
  liked_memes = session[:liked_memes] || []
  
  if liked_memes.empty?
    # No likes yet - return popular memes
    popular = DB.execute(
      "SELECT * FROM meme_stats 
       ORDER BY (likes * 2 + views) DESC 
       LIMIT 10"
    ).map do |row|
      {
        url: row['url'],
        title: row['title'],
        subreddit: row['subreddit'],
        likes: row['likes'] || 0,
        reason: 'Popular with everyone'
      }
    end
    
    return popular.to_json
  end
  
  # Get subreddits user has liked
  user_subreddits = DB.execute(
    "SELECT DISTINCT subreddit FROM meme_stats WHERE url IN (#{liked_memes.map { '?' }.join(',')})",
    liked_memes
  ).map { |row| row['subreddit'] }
  
  # Find similar memes from those subreddits
  recommendations = DB.execute(
    "SELECT * FROM meme_stats 
     WHERE subreddit IN (#{user_subreddits.map { '?' }.join(',')})
     AND url NOT IN (#{liked_memes.map { '?' }.join(',')})
     ORDER BY (likes * 2 + views) DESC 
     LIMIT 10",
    user_subreddits + liked_memes
  ).map do |row|
    collection_name = collection_name_for_subreddit(row['subreddit'])
    {
      url: row['url'],
      title: row['title'],
      subreddit: row['subreddit'],
      likes: row['likes'] || 0,
      reason: "Because you enjoyed #{collection_name}"
    }
  end
  
  recommendations.to_json
rescue => e
  logger.error "Error generating recommendations: #{e.message}"
  { error: 'Failed to generate recommendations' }.to_json
end
