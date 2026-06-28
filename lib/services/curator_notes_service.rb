# frozen_string_literal: true

require 'yaml'

# ============================================
# PHASE 4: CURATOR NOTES SERVICE
# ============================================
# Generates expert commentary for high-performing memes
# Adds social validation and cultural context

class CuratorNotesService
  def initialize
    @config = YAML.load_file('config/curator_notes.yml', aliases: true)['curator_notes']
    @curators = @config['curators']
    @templates = @config['templates']
    @social_proof = @config['social_proof']
    @why_matters = @config['why_matters']
  end

  # Main method: Get curator note for a meme
  def get_curator_note(meme_data)
    return nil unless eligible_for_note?(meme_data)

    {
      curator: select_curator(meme_data),
      note: generate_note(meme_data),
      social_proof: generate_social_proof(meme_data),
      why_matters: generate_why_matters(meme_data)
    }
  end

  # Check if meme is eligible for curator note
  def eligible_for_note?(meme_data)
    likes = meme_data[:likes] || meme_data['likes'] || 0
    views = meme_data[:views] || meme_data['views'] || 1
    
    # High engagement threshold
    return true if likes >= 50
    return true if views >= 200
    
    # Or high engagement ratio
    engagement_ratio = likes.to_f / views
    engagement_ratio >= 0.25
  end

  # Select appropriate curator based on subreddit/collection
  def select_curator(meme_data)
    subreddit = meme_data[:subreddit] || meme_data['subreddit']
    collection_slug = meme_data[:collection_slug] || meme_data['collection_slug']
    
    # Find curator whose specialty includes this subreddit
    curator = @curators.find do |c|
      c['specialty'].include?(subreddit)
    end
    
    # Default to meta curator if no specialty match
    curator ||= @curators.find { |c| c['id'] == 'meta_curator' }
    
    {
      name: curator['name'],
      avatar: curator['avatar'],
      tone: curator['tone']
    }
  end

  # Generate the curator's note
  def generate_note(meme_data)
    collection_slug = determine_collection(meme_data)
    templates = @templates[collection_slug] || @templates['default']
    
    # Select template based on meme characteristics
    template = select_template(templates, meme_data)
    
    # Add personal touch
    personalize_note(template, meme_data)
  end

  # Generate social proof statement
  def generate_social_proof(meme_data)
    likes = meme_data[:likes] || meme_data['likes'] || 0
    views = meme_data[:views] || meme_data['views'] || 1
    engagement = ((likes.to_f / views) * 100).round
    
    template = @social_proof.sample
    
    template
      .gsub('{count}', likes.to_s)
      .gsub('{engagement}', engagement.to_s)
      .gsub('{likes}', likes.to_s)
      .gsub('{collection}', determine_collection_name(meme_data))
      .gsub('{growth}', rand(10..50).to_s)
  end

  # Generate "Why This Matters" explanation
  def generate_why_matters(meme_data)
    likes = meme_data[:likes] || meme_data['likes'] || 0
    views = meme_data[:views] || meme_data['views'] || 1
    engagement = likes.to_f / views
    
    category = if engagement > 0.3
                 'high_engagement'
               elsif likes > 100
                 'cultural_moment'
               elsif views > 500
                 'technical_excellence'
               else
                 'emotional_impact'
               end
    
    @why_matters[category].sample
  end

  private

  def determine_collection(meme_data)
    subreddit = meme_data[:subreddit] || meme_data['subreddit'] || ''
    
    # Map subreddits to collection themes
    case subreddit.downcase
    when /surreal|deepfried|okbuddy/
      'absurdist'
    when /wholesome|mademesmile|eyebleach/
      'gentle'
    when /programmer|coding|programmerhorror/
      'programmer'
    when /philosophy|existential|nihilist/
      'philosophical'
    when /nostalgia|throwback|oldschool/
      'nostalgic'
    when /dank|meta|meme_/
      'meta'
    else
      'default'
    end
  end

  def determine_collection_name(meme_data)
    collection_slug = determine_collection(meme_data)
    
    {
      'absurdist' => 'The Absurdist\'s Corner',
      'gentle' => 'The Gentle Archives',
      'programmer' => 'The Programmer\'s Codex',
      'philosophical' => 'The Philosophical Salon',
      'nostalgic' => 'The Nostalgia Vault',
      'meta' => 'The Meta Collection',
      'default' => 'The Curated Collection'
    }[collection_slug] || 'This Collection'
  end

  def select_template(templates, meme_data)
    # Could add logic here to select based on meme characteristics
    # For now, random selection
    templates.sample
  end

  def personalize_note(template, meme_data)
    # Could add meme-specific personalization
    # For now, return template as-is
    template
  end
end
