# frozen_string_literal: true

# ============================================
# PHASE 5: PERSONALIZATION SERVICE
# ============================================
# Tracks user preferences and generates personalized experiences
# The final push to 95/100 satisfaction

class PersonalizationService
  def initialize(user_id)
    @user_id = user_id
  end

  # Get personalized daily digest for user
  def generate_daily_digest
    preferences = get_user_preferences
    
    {
      headline: generate_headline(preferences),
      top_picks: get_personalized_picks(5),
      new_in_favorites: get_new_in_favorite_collections(3),
      curator_spotlight: get_curator_spotlight,
      taste_insight: generate_taste_insight(preferences)
    }
  end

  # Track taste evolution over time
  def get_taste_evolution
    history = get_interaction_history(90) # Last 90 days
    
    return default_taste_profile if history.empty?
    
    {
      current_preferences: analyze_current_taste(history),
      evolution: track_preference_changes(history),
      trending_toward: predict_future_preferences(history),
      collections_discovered: count_collections_explored(history),
      taste_maturity: calculate_taste_maturity(history)
    }
  end

  # Auto-organize saved memes by collection
  def organize_saved_memes
    saved_memes = get_user_saved_memes
    
    organized = {
      by_collection: {},
      by_curator: {},
      by_rarity: {},
      uncategorized: []
    }
    
    saved_memes.each do |meme|
      # Organize by collection
      collection = determine_collection(meme)
      organized[:by_collection][collection] ||= []
      organized[:by_collection][collection] << meme
      
      # Organize by curator (if has note)
      if meme[:curator]
        curator = meme[:curator]
        organized[:by_curator][curator] ||= []
        organized[:by_curator][curator] << meme
      end
      
      # Organize by rarity
      rarity = meme[:rarity] || 'common'
      organized[:by_rarity][rarity] ||= []
      organized[:by_rarity][rarity] << meme
    end
    
    organized
  end

  # Get personalized recommendations based on behavior
  def get_personalized_picks(count = 10)
    preferences = get_user_preferences
    recent_activity = get_recent_activity(7) # Last 7 days
    
    # Weight factors
    favorite_collections = preferences[:favorite_collections] || []
    favorite_curators = preferences[:favorite_curators] || []
    engagement_patterns = analyze_engagement_patterns(recent_activity)
    
    picks = []
    
    # Get memes from favorite collections
    favorite_collections.each do |collection|
      collection_memes = fetch_collection_memes(collection, 3)
      picks.concat(collection_memes)
    end
    
    # Add diversity - explore adjacent collections
    adjacent = find_adjacent_collections(favorite_collections)
    adjacent.each do |collection|
      picks.concat(fetch_collection_memes(collection, 2))
    end
    
    # Filter by quality and uniqueness
    picks = picks.uniq { |m| m[:url] }
                 .select { |m| m[:likes] && m[:likes] > 20 }
                 .sort_by { |m| -(m[:likes] || 0) }
                 .take(count)
    
    picks
  end

  private

  def get_user_preferences
    # Query database for user's interaction patterns
    interactions = DB.execute(
      "SELECT * FROM meme_activity_log 
       WHERE user_id = ? 
       ORDER BY created_at DESC 
       LIMIT 100",
      [@user_id]
    )
    
    analyze_preferences_from_interactions(interactions)
  rescue
    default_preferences
  end

  def analyze_preferences_from_interactions(interactions)
    collections = Hash.new(0)
    curators = Hash.new(0)
    times_of_day = Hash.new(0)
    
    interactions.each do |interaction|
      next unless interaction['action'] == 'like' || interaction['action'] == 'save'
      
      # Count collection preferences
      collection = interaction['collection'] || 'unknown'
      collections[collection] += 1
      
      # Count curator preferences
      curator = interaction['curator']
      curators[curator] += 1 if curator
      
      # Analyze time patterns
      hour = Time.parse(interaction['created_at']).hour
      times_of_day[hour] += 1
    end
    
    {
      favorite_collections: collections.sort_by { |_, v| -v }.take(3).map(&:first),
      favorite_curators: curators.sort_by { |_, v| -v }.take(2).map(&:first),
      active_hours: times_of_day.sort_by { |_, v| -v }.take(3).map(&:first),
      engagement_level: calculate_engagement_level(interactions.length)
    }
  end

  def default_preferences
    {
      favorite_collections: ['absurdist', 'programmer', 'gentle'],
      favorite_curators: [],
      active_hours: [9, 12, 20],
      engagement_level: 'new'
    }
  end

  def generate_headline(preferences)
    collections = preferences[:favorite_collections] || []
    
    if collections.empty?
      "Your Daily Curation Awaits"
    else
      collection_name = humanize_collection(collections.first)
      "New in #{collection_name} & More"
    end
  end

  def get_new_in_favorite_collections(count)
    preferences = get_user_preferences
    collections = preferences[:favorite_collections] || []
    
    return [] if collections.empty?
    
    # Get recent memes from favorite collections
    cutoff_date = (Time.now - (24 * 60 * 60)).strftime('%Y-%m-%d %H:%M:%S')
    
    new_memes = []
    collections.each do |collection|
      memes = DB.execute(
        "SELECT * FROM meme_stats 
         WHERE collection = ? 
         AND created_at >= ? 
         ORDER BY (likes * 2 + views) DESC 
         LIMIT ?",
        [collection, cutoff_date, count]
      )
      new_memes.concat(memes)
    end
    
    new_memes.take(count)
  rescue
    []
  end

  def get_curator_spotlight
    preferences = get_user_preferences
    favorite_curators = preferences[:favorite_curators] || []
    
    if favorite_curators.any?
      {
        curator: favorite_curators.first,
        message: "Your favorite curator has new picks"
      }
    else
      {
        curator: "The Absurdist",
        message: "Discover curator picks tailored for you"
      }
    end
  end

  def generate_taste_insight(preferences)
    collections = preferences[:favorite_collections] || []
    engagement = preferences[:engagement_level] || 'new'
    
    insights = {
      'new' => "You're discovering your taste—explore freely!",
      'casual' => "Your preferences are taking shape",
      'engaged' => "You have refined taste across #{collections.length} collections",
      'expert' => "Your curation expertise spans the spectrum"
    }
    
    insights[engagement] || insights['new']
  end

  def get_interaction_history(days)
    cutoff_date = (Time.now - (days * 24 * 60 * 60)).strftime('%Y-%m-%d %H:%M:%S')
    
    DB.execute(
      "SELECT * FROM meme_activity_log 
       WHERE user_id = ? 
       AND created_at >= ? 
       ORDER BY created_at ASC",
      [@user_id, cutoff_date]
    )
  rescue
    []
  end

  def default_taste_profile
    {
      current_preferences: ['exploring'],
      evolution: 'discovering',
      trending_toward: 'refined',
      collections_discovered: 0,
      taste_maturity: 'emerging'
    }
  end

  def analyze_current_taste(history)
    recent = history.last(20)
    collections = recent.map { |h| h['collection'] }.compact.uniq
    collections.take(3)
  end

  def track_preference_changes(history)
    # Simple evolution tracking
    first_half = history.first(history.length / 2)
    second_half = history.last(history.length / 2)
    
    first_collections = first_half.map { |h| h['collection'] }.compact.tally
    second_collections = second_half.map { |h| h['collection'] }.compact.tally
    
    changes = {}
    second_collections.each do |collection, count|
      old_count = first_collections[collection] || 0
      if count > old_count
        changes[collection] = 'increasing'
      end
    end
    
    changes
  end

  def predict_future_preferences(history)
    recent_trend = track_preference_changes(history)
    trending = recent_trend.select { |_, v| v == 'increasing' }.keys
    
    trending.any? ? trending.first : 'eclectic'
  end

  def count_collections_explored(history)
    history.map { |h| h['collection'] }.compact.uniq.length
  end

  def calculate_taste_maturity(history)
    collections_count = count_collections_explored(history)
    interactions_count = history.length
    
    if interactions_count < 10
      'emerging'
    elsif interactions_count < 50
      'developing'
    elsif interactions_count < 200
      'refined'
    else
      'expert'
    end
  end

  def get_user_saved_memes
    DB.execute(
      "SELECT * FROM saved_memes WHERE user_id = ?",
      [@user_id]
    )
  rescue
    []
  end

  def determine_collection(meme)
    meme[:collection] || meme['collection'] || 'general'
  end

  def get_recent_activity(days)
    get_interaction_history(days)
  end

  def analyze_engagement_patterns(activity)
    {
      frequency: activity.length / 7.0, # avg per day
      preferred_time: activity.map { |a| Time.parse(a['created_at']).hour }.mode,
      favorite_action: activity.map { |a| a['action'] }.tally.max_by { |_, v| v }&.first
    }
  end

  def fetch_collection_memes(collection, limit)
    DB.execute(
      "SELECT * FROM meme_stats 
       WHERE collection = ? 
       ORDER BY (likes * 2 + views) DESC 
       LIMIT ?",
      [collection, limit]
    )
  rescue
    []
  end

  def find_adjacent_collections(favorites)
    # Simple adjacency based on common characteristics
    adjacency_map = {
      'absurdist' => ['meta', 'philosophical'],
      'programmer' => ['tech', 'meta'],
      'gentle' => ['wholesome', 'nostalgic'],
      'philosophical' => ['absurdist', 'meta'],
      'nostalgic' => ['gentle', 'wholesome']
    }
    
    adjacent = []
    favorites.each do |collection|
      adjacent.concat(adjacency_map[collection] || [])
    end
    
    (adjacent - favorites).uniq.take(2)
  end

  def calculate_engagement_level(interaction_count)
    if interaction_count < 10
      'new'
    elsif interaction_count < 50
      'casual'
    elsif interaction_count < 200
      'engaged'
    else
      'expert'
    end
  end

  def humanize_collection(slug)
    {
      'absurdist' => "The Absurdist's Corner",
      'wholesome' => 'Wholesome Memes',
      'dark_humor' => 'Dark Humor',
      'gaming' => 'Gaming Memes',
      'programming' => 'Programming Humor',
      'animals' => 'Animal Memes',
      'politics' => 'Political Humor',
      'movies' => 'Movie & TV Memes',
      'sports' => 'Sports Memes',
      'science' => 'Science Humor'
    }.fetch(slug.to_s, slug.to_s.gsub('_', ' ').capitalize)
  end
end
