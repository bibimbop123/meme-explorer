# frozen_string_literal: true

##
# Taste Profile Service
# Generates refined, literary descriptions of user taste
# Replaces gamified "Meme DNA" with sophisticated profile language
#
# Philosophy: Make users feel cultured, not scored

class TasteProfileService
  
  # Aesthetic descriptors (primary trait)
  AESTHETICS = {
    absurdist: {
      primary: 'Absurdist',
      variants: ['Post-modern', 'Surrealist', 'Dadaist'],
      description: 'Finding meaning in meaninglessness'
    },
    wholesome: {
      primary: 'Wholesome',
      variants: ['Tender', 'Earnest', 'Gentle'],
      description: 'Seeking comfort and connection'
    },
    dark: {
      primary: 'Dark',
      variants: ['Sardonic', 'Macabre', 'Noir'],
      description: 'Embracing shadows with humor'
    },
    intellectual: {
      primary: 'Intellectual',
      variants: ['Erudite', 'Cerebral', 'Philosophical'],
      description: 'Appreciating layers of meaning'
    },
    nostalgic: {
      primary: 'Nostalgic',
      variants: ['Retrospective', 'Vintage', 'Classical'],
      description: 'Cherishing digital artifacts'
    },
    chaotic: {
      primary: 'Chaotic',
      variants: ['Anarchic', 'Frenetic', 'Unhinged'],
      description: 'Embracing beautiful disorder'
    }
  }.freeze

  # Secondary characteristics (accents)
  ACCENTS = [
    'notes of melancholy',
    'tinged with optimism',
    'undercurrents of cynicism',
    'hints of whimsy',
    'streaks of rebellion',
    'touches of sincerity',
    'elements of irony',
    'flashes of brilliance'
  ].freeze

  # Appreciation styles
  APPRECIATION_STYLES = {
    subtle: 'Subtle humor over obvious punchlines',
    layered: 'Layered meanings and callbacks',
    visual: 'Visual wit and timing',
    contextual: 'Cultural references and context',
    timing: 'Perfect comedic timing',
    subversive: 'Subversion of expectations'
  }.freeze

  # Sensibilities
  SENSIBILITIES = {
    earnest_aware: 'Earnest without naivety',
    cynical_hopeful: 'Cynical but hopeful',
    intellectual_playful: 'Intellectual playfulness',
    sincere_ironic: 'Post-ironic sincerity',
    dark_optimistic: 'Dark comedy, bright outlook',
    sophisticated_accessible: 'Sophisticated yet accessible'
  }.freeze

  ##
  # Generate complete taste profile for user
  # @param user [Hash] User object with history
  # @return [Hash] Complete taste profile
  def self.generate_profile(user)
    preferences = analyze_preferences(user)
    
    {
      aesthetic: aesthetic_description(preferences),
      appreciation: appreciation_style(preferences),
      sensibility: sensibility_type(preferences),
      summary: generate_summary(preferences)
    }
  end

  ##
  # Generate short taste summary (one-liner)
  # @param user [Hash] User object
  # @return [String] Brief taste description
  def self.short_description(user)
    prefs = analyze_preferences(user)
    primary = primary_aesthetic(prefs)
    accent = ACCENTS.sample
    
    "#{primary} with #{accent}"
  end

  private

  ##
  # Analyze user preferences from history
  # @param user [Hash] User object
  # @return [Hash] Analyzed preferences
  def self.analyze_preferences(user)
    # This would integrate with existing user tracking
    # For now, return structure showing expected data
    
    liked_subs = user[:liked_subreddits] || []
    interaction_patterns = user[:interaction_patterns] || {}
    
    {
      primary_category: determine_primary_category(liked_subs),
      secondary_categories: determine_secondary_categories(liked_subs),
      humor_preferences: analyze_humor_style(interaction_patterns),
      sophistication_level: calculate_sophistication(user),
      diversity_score: calculate_diversity(liked_subs)
    }
  end

  ##
  # Generate aesthetic description
  # @param prefs [Hash] Analyzed preferences
  # @return [String] Aesthetic description
  def self.aesthetic_description(prefs)
    primary = prefs[:primary_category]
    secondary = prefs[:secondary_categories]&.first
    
    aesthetic = AESTHETICS[primary] || AESTHETICS[:intellectual]
    primary_label = aesthetic[:primary]
    
    if secondary && AESTHETICS[secondary]
      accent = ACCENTS.sample
      "#{primary_label} #{accent}"
    else
      variant = aesthetic[:variants].sample
      "#{variant} sensibility"
    end
  end

  ##
  # Determine appreciation style
  # @param prefs [Hash] Analyzed preferences
  # @return [String] Appreciation description
  def self.appreciation_style(prefs)
    styles = []
    
    # Select 2-3 appreciation styles based on user behavior
    if prefs[:sophistication_level] && prefs[:sophistication_level] > 7
      styles << APPRECIATION_STYLES[:layered]
      styles << APPRECIATION_STYLES[:contextual]
    else
      styles << APPRECIATION_STYLES[:timing]
      styles << APPRECIATION_STYLES[:visual]
    end
    
    # Add one more random style for variety
    remaining = APPRECIATION_STYLES.values - styles
    styles << remaining.sample if remaining.any?
    
    styles.first(2).join(' and ')
  end

  ##
  # Determine sensibility type
  # @param prefs [Hash] Analyzed preferences
  # @return [String] Sensibility description
  def self.sensibility_type(prefs)
    # Match sensibility to primary category
    case prefs[:primary_category]
    when :dark
      SENSIBILITIES[:dark_optimistic]
    when :absurdist
      SENSIBILITIES[:intellectual_playful]
    when :wholesome
      SENSIBILITIES[:earnest_aware]
    when :chaotic
      SENSIBILITIES[:sincere_ironic]
    else
      SENSIBILITIES[:sophisticated_accessible]
    end
  end

  ##
  # Generate complete summary
  # @param prefs [Hash] Analyzed preferences
  # @return [String] Complete profile summary
  def self.generate_summary(prefs)
    aesthetic = aesthetic_description(prefs)
    appreciation = appreciation_style(prefs)
    sensibility = sensibility_type(prefs)
    
    "Your aesthetic leans #{aesthetic}. " \
    "You appreciate #{appreciation}. " \
    "Your sensibility: #{sensibility}."
  end

  ##
  # Determine primary aesthetic category
  # @param liked_subs [Array] List of liked subreddits
  # @return [Symbol] Primary category
  def self.determine_primary_category(liked_subs)
    # Map subreddits to categories
    category_counts = Hash.new(0)
    
    liked_subs.each do |sub|
      category = categorize_subreddit(sub)
      category_counts[category] += 1
    end
    
    category_counts.max_by { |_k, v| v }&.first || :intellectual
  end

  ##
  # Determine secondary categories
  # @param liked_subs [Array] List of liked subreddits
  # @return [Array<Symbol>] Secondary categories
  def self.determine_secondary_categories(liked_subs)
    return [] if liked_subs.nil? || liked_subs.empty?
    
    category_counts = Hash.new(0)
    
    liked_subs.each do |sub|
      category = categorize_subreddit(sub)
      category_counts[category] += 1
    end
    
    # Return top 2-3, excluding primary
    sorted = category_counts.sort_by { |_k, v| -v }[1..2]
    return [] if sorted.nil?
    sorted.map(&:first).compact
  end

  ##
  # Categorize a subreddit
  # @param subreddit [String] Subreddit name
  # @return [Symbol] Category
  def self.categorize_subreddit(subreddit)
    sub = subreddit.downcase
    
    case sub
    when /wholesome|aww|mademesmile|eyebleach/
      :wholesome
    when /surreal|absurd|hmmm|bonehurting/
      :absurdist
    when /dark|cursed|hell|abyss/
      :dark
    when /history|philosophy|cultural|art/
      :intellectual
    when /vintage|classic|advice|rage/
      :nostalgic
    when /chaos|abrupt|perfect.*scream/
      :chaotic
    else
      :intellectual
    end
  end

  ##
  # Analyze humor style from interaction patterns
  # @param patterns [Hash] Interaction patterns
  # @return [Hash] Humor preferences
  def self.analyze_humor_style(patterns)
    # Placeholder - would analyze actual patterns
    {
      prefers_subtle: true,
      enjoys_callbacks: true,
      appreciates_timing: true
    }
  end

  ##
  # Calculate sophistication level (1-10)
  # @param user [Hash] User object
  # @return [Integer] Sophistication score
  def self.calculate_sophistication(user)
    # Factors: variety of subs, engagement with niche content, etc.
    # Placeholder
    7
  end

  ##
  # Calculate diversity score
  # @param liked_subs [Array] Liked subreddits
  # @return [Float] Diversity score
  def self.calculate_diversity(liked_subs)
    # Calculate variety across categories
    return 0.0 if liked_subs.empty?
    
    categories = liked_subs.map { |sub| categorize_subreddit(sub) }.uniq
    categories.length / AESTHETICS.length.to_f
  end

  ##
  # Get primary aesthetic label
  # @param prefs [Hash] Preferences
  # @return [String] Primary aesthetic
  def self.primary_aesthetic(prefs)
    category = prefs[:primary_category]
    aesthetic = AESTHETICS[category] || AESTHETICS[:intellectual]
    aesthetic[:primary]
  end
end
