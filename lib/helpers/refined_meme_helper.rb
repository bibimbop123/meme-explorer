# frozen_string_literal: true

require_relative '../services/curation_signals_service'
require_relative '../services/taste_profile_service'
require_relative './curated_collections_helper'

##
# Refined Meme Helper
# Adds curation layer to meme display
# Transforms technical data into refined presentation

module RefinedMemeHelper
  
  ##
  # Generate curation signal for a meme
  # @param meme [Hash] Meme data
  # @param user [Hash] User data (optional)
  # @return [String, nil] Curation signal
  def refined_curation_signal(meme, user = nil)
    CurationSignalsService.generate(meme, user)
  end
  
  ##
  # Get multiple curation signals (for detailed view)
  # @param meme [Hash] Meme data
  # @param user [Hash] User data (optional)
  # @return [Array<String>] Curation signals
  def refined_curation_signals(meme, user = nil)
    CurationSignalsService.generate_multiple(meme, user)
  end
  
  ##
  # Get curated collection name for meme
  # @param meme [Hash] Meme data
  # @return [String] Collection name
  def refined_collection_name(meme)
    subreddit = meme[:subreddit] || meme['subreddit']
    CuratedCollectionsHelper.collection_name_for(subreddit)
  end
  
  ##
  # Get collection description
  # @param meme [Hash] Meme data
  # @return [String, nil] Description
  def refined_collection_description(meme)
    subreddit = meme[:subreddit] || meme['subreddit']
    CuratedCollectionsHelper.collection_description_for(subreddit)
  end
  
  ##
  # Get user's taste profile
  # @param user [Hash] User data
  # @return [Hash] Taste profile
  def refined_taste_profile(user)
    return nil unless user
    TasteProfileService.generate_profile(user)
  end
  
  ##
  # Get short taste description
  # @param user [Hash] User data
  # @return [String] Short description
  def refined_taste_description(user)
    return 'Building your taste profile...' unless user
    TasteProfileService.short_description(user)
  end
  
  ##
  # Check if meme should show refined aesthetic
  # @param options [Hash] Display options
  # @return [Boolean] Use refined aesthetic
  def use_refined_aesthetic?(options = {})
    # Can be toggled via user preferences or A/B testing
    options.fetch(:refined, true)
  end
  
  ##
  # Format meme age for display
  # @param meme [Hash] Meme data
  # @return [String, nil] Formatted age
  def refined_meme_age(meme)
    created_at = meme[:created_utc] || meme['created_utc']
    return nil unless created_at
    
    age_days = ((Time.now.to_i - created_at) / 86400.0).to_i
    year = Time.at(created_at).year
    
    if age_days > 3650  # 10+ years
      "Vintage: #{year}"
    elsif age_days > 1825  # 5+ years
      "Classic from #{year}"
    elsif age_days > 730  # 2+ years
      "#{year}"
    elsif age_days > 365
      "Over a year old"
    elsif age_days > 180
      "#{(age_days / 30).to_i} months ago"
    elsif age_days > 30
      "#{(age_days / 7).to_i} weeks ago"
    elsif age_days > 1
      "#{age_days} days ago"
    else
      "Fresh"
    end
  end
  
  ##
  # Get rarity badge for meme
  # @param meme [Hash] Meme data
  # @return [Hash, nil] Badge info
  def refined_rarity_badge(meme)
    score = meme[:score] || meme['score'] || 0
    views = meme[:views]
    created_at = meme[:created_utc] || meme['created_utc']
    
    # Vintage
    if created_at
      age_days = ((Time.now.to_i - created_at) / 86400.0).to_i
      if age_days > 3650
        return { type: 'vintage', label: "Vintage: #{Time.at(created_at).year}" }
      end
    end
    
    # Rare (low views)
    if views && views < 100
      return { type: 'rare', label: 'Hidden Gem' }
    end
    
    # Quality (high score)
    if score > 1000
      return { type: 'quality', label: 'Exceptional' }
    end
    
    nil
  end
end
