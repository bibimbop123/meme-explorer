# frozen_string_literal: true

##
# Curation Signals Service
# Generates thoughtful, context-rich signals explaining WHY a meme was selected
# Makes the algorithm feel like a tastemaker, not a machine
#
# Philosophy: Every meme should feel intentionally curated

class CurationSignalsService
  # Signal categories
  QUALITY_SIGNALS = [
    'Exceptionally well-received',
    'Highly curated selection',
    'Premium quality',
    'Top-tier content'
  ].freeze

  RARITY_SIGNALS = [
    'Hidden gem',
    'Rarely seen',
    'Obscure find',
    'Under-appreciated classic'
  ].freeze

  VINTAGE_SIGNALS = [
    'Vintage',
    'Classic',
    'From the archives',
    'Timeless'
  ].freeze

  TASTE_SIGNALS = [
    'Matches your refined taste',
    'Complements your aesthetic',
    'Aligned with your sensibility',
    'For your discerning eye'
  ].freeze

  CULTURAL_SIGNALS = [
    'Cultural touchstone',
    'Historically significant',
    'Genre-defining',
    'Influential work'
  ].freeze

  ##
  # Generate a curation signal for a meme
  # @param meme [Hash] The meme object
  # @param user [Hash] The user object (optional)
  # @return [String, nil] The curation signal or nil
  def self.generate(meme, user = nil)
    signals = []

    # Quality-based signals
    signals.concat(quality_signals(meme))

    # Rarity signals
    signals.concat(rarity_signals(meme))

    # Vintage signals
    signals.concat(vintage_signals(meme))

    # User taste signals (if user provided)
    signals.concat(taste_signals(meme, user)) if user

    # Cultural significance
    signals.concat(cultural_signals(meme))

    # Return one random signal or nil if no signals
    signals.sample
  end

  ##
  # Generate multiple signals (for detailed view)
  # @param meme [Hash] The meme object
  # @param user [Hash] The user object (optional)
  # @return [Array<String>] Array of signals
  def self.generate_multiple(meme, user = nil)
    signals = []

    signals.concat(quality_signals(meme))
    signals.concat(rarity_signals(meme))
    signals.concat(vintage_signals(meme))
    signals.concat(taste_signals(meme, user)) if user
    signals.concat(cultural_signals(meme))

    signals
  end

  private

  ##
  # Quality-based signals
  def self.quality_signals(meme)
    signals = []
    score = meme[:score] || meme['score'] || 0

    # High score threshold
    if score > 1000
      signals << QUALITY_SIGNALS.sample
    elsif score > 500
      signals << 'Well-regarded selection'
    end

    # Additional quality indicators could go here
    # - engagement rate
    # - curator ratings
    # - comment quality

    signals
  end

  ##
  # Rarity signals
  def self.rarity_signals(meme)
    signals = []
    
    # Low view count (if tracking views)
    if meme[:views] && meme[:views] < 100
      signals << "#{RARITY_SIGNALS.sample} — #{meme[:views]} views"
    elsif meme[:views] && meme[:views] < 500
      signals << 'Lesser-known gem'
    end

    # Obscure subreddit
    if meme[:subreddit] && obscure_subreddit?(meme[:subreddit])
      signals << 'From an obscure corner of the internet'
    end

    signals
  end

  ##
  # Vintage/age-based signals
  def self.vintage_signals(meme)
    signals = []
    
    created_at = meme[:created_utc] || meme['created_utc']
    return signals unless created_at

    age_days = ((Time.now.to_i - created_at) / 86400.0).to_i
    year = Time.at(created_at).year

    if age_days > 3650  # 10+ years
      signals << "#{VINTAGE_SIGNALS.sample}: #{year}"
    elsif age_days > 1825  # 5+ years
      signals << "Classic from #{year}"
    elsif age_days > 730  # 2+ years
      signals << "Vintage selection"
    end

    signals
  end

  ##
  # Taste-matching signals (personalized)
  def self.taste_signals(meme, user)
    signals = []
    return signals unless user && meme

    # Check if similar to user's favorites
    if similar_to_favorites?(meme, user)
      signals << TASTE_SIGNALS.sample
    end

    # Check if matches user's preferred subreddits
    if matches_user_preferences?(meme, user)
      signals << 'Curated for your sensibility'
    end

    # Check if complements recent behavior
    if complements_recent_activity?(meme, user)
      signals << 'Complements your recent discoveries'
    end

    signals
  end

  ##
  # Cultural significance signals
  def self.cultural_signals(meme)
    signals = []
    
    # High engagement across multiple platforms
    if meme[:score] && meme[:score] > 5000
      signals << CULTURAL_SIGNALS.sample
    end

    # Known meme format (could be enhanced with a meme format database)
    if famous_format?(meme)
      signals << 'Notable meme format'
    end

    signals
  end

  ##
  # Helper: Check if subreddit is obscure
  def self.obscure_subreddit?(subreddit)
    # Could be enhanced with actual subreddit popularity data
    obscure_subs = ['bonehurtingjuice', 'speedoflobsters', 'antimeme', 
                    'surrealmemes', 'ooer', 'fifthworldproblems']
    obscure_subs.include?(subreddit.downcase)
  end

  ##
  # Helper: Check if similar to user's favorites
  def self.similar_to_favorites?(meme, user)
    return false unless user[:favorite_subreddits]
    
    meme_sub = meme[:subreddit] || meme['subreddit']
    user[:favorite_subreddits].include?(meme_sub)
  end

  ##
  # Helper: Check if matches user preferences
  def self.matches_user_preferences?(meme, user)
    return false unless user[:preferred_categories]
    
    # Map meme to category and check against user preferences
    # This would integrate with your existing preference tracking
    true # Placeholder
  end

  ##
  # Helper: Check if complements recent activity
  def self.complements_recent_activity?(meme, user)
    return false unless user[:recent_likes]
    
    # Analyze recent likes and see if this meme fits the pattern
    # More sophisticated logic could go here
    false # Placeholder
  end

  ##
  # Helper: Check if famous meme format
  def self.famous_format?(meme)
    # Could be enhanced with a database of famous formats
    # For now, use title keywords
    title = (meme[:title] || meme['title'] || '').downcase
    
    famous_formats = [
      'distracted boyfriend', 'drake', 'expanding brain', 'galaxy brain',
      'woman yelling at cat', 'surprised pikachu', 'is this a pigeon',
      'they don\'t know', 'doomer', 'wojak', 'pepe'
    ]
    
    famous_formats.any? { |format| title.include?(format) }
  end
end
