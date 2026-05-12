# Humor Optimizer Service
# Phase 5: Make the experience funnier through intentional sequencing

module MemeExplorer
  class HumorOptimizerService
    class << self
      # Optimize humor sequence for maximum laughs
      def optimize_humor_sequence(memes, session_id)
        return memes unless session_id && memes.is_a?(Array) && memes.any?
        
        recent_types = get_recent_humor_types(session_id)
        return memes if recent_types.empty?
        
        # Comedy rule: Vary intensity
        if recent_types.last(3).all? { |t| t == 'wholesome' }
          # Switch to unexpected/absurd for contrast
          prioritize_humor_types(memes, ['unexpected', 'absurdist', 'dark'])
        elsif recent_types.last(2).all? { |t| ['dark', 'dank'].include?(t) }
          # Lighten mood with wholesome
          prioritize_humor_types(memes, ['wholesome', 'funny'])
        elsif recent_types.count('relatable') >= 3
          # Break pattern with surprise
          prioritize_humor_types(memes, ['unexpected', 'cringe'])
        else
          # Continue normal selection
          memes
        end
      end
      
      # Create comedy arc with setup → payoff
      def create_comedy_arc(memes, session_id, meme_count)
        return memes unless session_id && memes.is_a?(Array) && memes.any?
        
        # Every 5th meme should be a "payoff" to earlier setup
        if meme_count % 5 == 0
          # Look for callbacks/references to earlier themes
          recent_themes = extract_themes(session_id)
          
          if recent_themes.any?
            # Find memes that reference those themes
            callback_memes = memes.select do |m|
              meme_themes = extract_meme_themes(m)
              meme_themes.any? { |t| recent_themes.include?(t) }
            end
            
            return callback_memes if callback_memes.any?
          end
        end
        
        memes
      end
      
      # Track humor type for sequencing
      def track_humor_type(session_id, meme)
        return unless session_id && defined?(REDIS) && REDIS
        
        humor_type = detect_humor_type(meme)
        
        begin
          key = "session:#{session_id}:humor_types"
          REDIS.lpush(key, humor_type)
          REDIS.ltrim(key, 0, 49)  # Keep last 50
          REDIS.expire(key, 86400)  # 24 hours
        rescue => e
          puts "Humor tracking error: #{e.message}"
        end
      end
      
      # Track themes for comedy callbacks
      def track_theme(session_id, meme)
        return unless session_id && defined?(REDIS) && REDIS
        
        themes = extract_meme_themes(meme)
        
        begin
          key = "session:#{session_id}:themes"
          themes.each { |theme| REDIS.sadd(key, theme) }
          REDIS.expire(key, 3600)  # 1 hour
        rescue => e
          puts "Theme tracking error: #{e.message}"
        end
      end
      
      private
      
      def get_recent_humor_types(session_id)
        return [] unless defined?(REDIS) && REDIS
        
        begin
          key = "session:#{session_id}:humor_types"
          REDIS.lrange(key, 0, -1) || []
        rescue
          []
        end
      end
      
      def prioritize_humor_types(memes, preferred_types)
        # Separate memes by type
        preferred = []
        others = []
        
        memes.each do |meme|
          humor_type = detect_humor_type(meme)
          if preferred_types.include?(humor_type)
            preferred << meme
          else
            others << meme
          end
        end
        
        # Return preferred first, then others
        preferred.any? ? preferred + others : memes
      end
      
      def detect_humor_type(meme)
        title = meme['title'].to_s.downcase
        subreddit = meme['subreddit'].to_s.downcase
        
        # Detect based on keywords and subreddit
        case
        when title.match?(/wholesome|aww|cute|happy/) || subreddit.match?(/wholesome/)
          'wholesome'
        when title.match?(/dark|cursed|disturbing/) || subreddit.match?(/dark|cursed/)
          'dark'
        when title.match?(/dank|edgy/) || subreddit.match?(/dank/)
          'dank'
        when title.match?(/cringe|awkward/)
          'cringe'
        when title.match?(/relatable|me_irl/) || subreddit.match?(/meirl/)
          'relatable'
        when title.match?(/unexpected|surprise|plot/)
          'unexpected'
        when title.match?(/absurd|surreal|random/) || subreddit.match?(/surreal/)
          'absurdist'
        else
          'funny'
        end
      end
      
      def extract_themes(session_id)
        return [] unless defined?(REDIS) && REDIS
        
        begin
          key = "session:#{session_id}:themes"
          REDIS.smembers(key) || []
        rescue
          []
        end
      end
      
      def extract_meme_themes(meme)
        themes = []
        title = meme['title'].to_s.downcase
        
        # Extract common meme themes
        theme_keywords = {
          'programming' => ['code', 'programming', 'developer', 'bug'],
          'gaming' => ['game', 'gamer', 'play', 'console'],
          'work' => ['work', 'job', 'boss', 'office'],
          'relationships' => ['girlfriend', 'boyfriend', 'relationship', 'dating'],
          'school' => ['school', 'teacher', 'homework', 'exam'],
          'politics' => ['trump', 'biden', 'politics', 'election'],
          'movies' => ['movie', 'film', 'actor', 'cinema'],
          'animals' => ['dog', 'cat', 'animal', 'pet']
        }
        
        theme_keywords.each do |theme, keywords|
          themes << theme if keywords.any? { |kw| title.include?(kw) }
        end
        
        themes
      end
    end
  end
end
