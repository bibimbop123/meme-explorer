# frozen_string_literal: true

require 'yaml'

##
# Curated Collections Helper
# Loads and provides access to curated collection definitions
# Maps subreddits to refined, literary collection names

module CuratedCollectionsHelper
  
  ##
  # Load collections from YAML config
  def self.load_collections
    config_path = File.join(__dir__, '../../config/curated_collections.yml')
    @collections ||= YAML.load_file(config_path)
  end
  
  ##
  # Get all collections
  def self.all_collections
    load_collections['collections']
  end
  
  ##
  # Get collection by key
  def self.get_collection(key)
    all_collections[key.to_s]
  end
  
  ##
  # Find collection for a subreddit
  def self.collection_for_subreddit(subreddit)
    return nil unless subreddit
    
    sub = subreddit.downcase
    all_collections.find do |_key, collection|
      collection['subreddits']&.any? { |s| s.downcase == sub }
    end
  end
  
  ##
  # Get collection name for subreddit
  def self.collection_name_for(subreddit)
    collection = collection_for_subreddit(subreddit)
    collection&.last&.dig('name') || 'Curated Selection'
  end
  
  ##
  # Get collection description for subreddit
  def self.collection_description_for(subreddit)
    collection = collection_for_subreddit(subreddit)
    collection&.last&.dig('description')
  end
  
  ##
  # Get collection tagline for subreddit
  def self.collection_tagline_for(subreddit)
    collection = collection_for_subreddit(subreddit)
    collection&.last&.dig('tagline')
  end
  
  ##
  # Get collection groups for navigation
  def self.collection_groups
    load_collections['collection_groups']
  end
  
  ##
  # Get collections for a group
  def self.collections_in_group(group_key)
    groups = collection_groups
    group = groups[group_key.to_s]
    return [] unless group
    
    collection_keys = group['collections'] || []
    collection_keys.map { |key| [key, get_collection(key)] }.to_h
  end
end
