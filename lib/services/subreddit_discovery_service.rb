# Subreddit Discovery Service - Phase 2
# Automatically discovers new high-quality subreddits
# Created: June 3, 2026

require 'httparty'
require 'yaml'

class SubredditDiscoveryService
  MIN_SUBSCRIBERS = 50_000
  MIN_ACTIVE_USERS = 100
  DISCOVERY_LIMIT = 50
  
  class << self
    # Discover related subreddits from seed list
    def discover_related(seed_subreddits, limit: DISCOVERY_LIMIT)
      puts "🔍 [Discovery] Starting discovery from #{seed_subreddits.size} seeds"
      
      discovered = []
      processed = 0
      
      seed_subreddits.each do |subreddit|
        break if discovered.size >= limit
        
        related = fetch_related_from_reddit(subreddit)
        qualified = filter_quality(related)
        
        discovered.concat(qualified)
        processed += 1
        
        puts "  📊 Processed #{processed}/#{seed_subreddits.size}: Found #{qualified.size} from r/#{subreddit}"
        
        sleep 2  # Rate limiting
      end
      
      # Remove duplicates and existing subreddits
      unique = dedup_and_filter_existing(discovered)
      
      puts "✅ [Discovery] Found #{unique.size} new qualified subreddits"
      unique.first(limit)
    rescue => e
      log_error("Discover related error", e)
      []
    end
    
    # Auto-discover and save to file
    def auto_discover_and_save!
      puts "🤖 [Discovery] Starting auto-discovery..."
      
      # Load current tier 1 subreddits as seeds
      current = YAML.load_file('data/subreddits.yml')
      seeds = current['tier_1'] || []
      
      # Discover new subreddits
      discovered = discover_related(seeds, limit: 50)
      
      return { discovered: 0, saved: false } if discovered.empty?
      
      # Save to candidates file for manual review
      candidates_file = 'data/discovered_subreddits.yml'
      existing_candidates = load_existing_candidates(candidates_file)
      
      # Merge with existing
      all_candidates = (existing_candidates + discovered).uniq { |s| s['name'] }
      
      # Save to file
      File.write(
        candidates_file,
        {
          'discovered_at' => Time.now.to_s,
          'total_candidates' => all_candidates.size,
          'candidates' => all_candidates
        }.to_yaml
      )
      
      puts "✅ [Discovery] Saved #{discovered.size} new candidates to #{candidates_file}"
      puts "   Total candidates: #{all_candidates.size}"
      
      { discovered: discovered.size, saved: true, total: all_candidates.size }
    rescue => e
      log_error("Auto discover and save error", e)
      { discovered: 0, saved: false, error: e.message }
    end
    
    # Approve candidates and add to main list
    def approve_candidates(subreddit_names, tier: 'tier_2')
      current = YAML.load_file('data/subreddits.yml')
      tier_list = current[tier] || []
      
      # Add approved subreddits
      tier_list.concat(subreddit_names)
      tier_list.uniq!
      
      current[tier] = tier_list
      
      # Update popular list if needed
      if current['popular']
        current['popular'].concat(subreddit_names)
        current['popular'].uniq!
      end
      
      # Save back to file
      File.write('data/subreddits.yml', current.to_yaml)
      
      puts "✅ [Discovery] Approved #{subreddit_names.size} subreddits to #{tier}"
      { approved: subreddit_names.size, tier: tier }
    rescue => e
      log_error("Approve candidates error", e)
      { approved: 0, error: e.message }
    end
    
    private
    
    # Fetch related subreddits from Reddit API
    def fetch_related_from_reddit(subreddit)
      url = "https://www.reddit.com/r/#{subreddit}/about.json"
      
      response = HTTParty.get(url,
        headers: {
          "User-Agent" => "MemeExplorer/2.0 Subreddit Discovery"
        },
        timeout: 10
      )
      
      return [] unless response.success?
      
      data = response.parsed_response
      related = []
      
      # Extract from description/sidebar
      description = data.dig('data', 'public_description') || ''
      sidebar = data.dig('data', 'description') || ''
      
      # Find subreddit mentions (r/subreddit)
      text = "#{description} #{sidebar}"
      mentions = text.scan(/r\/(\w+)/).flatten.uniq
      
      # Fetch details for each mention
      mentions.first(10).each do |mentioned_sub|
        details = fetch_subreddit_details(mentioned_sub)
        related << details if details
        sleep 1
      end
      
      related.compact
    rescue => e
      log_error("Fetch related error for r/#{subreddit}", e)
      []
    end
    
    # Fetch detailed info about a subreddit
    def fetch_subreddit_details(subreddit)
      url = "https://www.reddit.com/r/#{subreddit}/about.json"
      
      response = HTTParty.get(url,
        headers: {
          "User-Agent" => "MemeExplorer/2.0 Subreddit Discovery"
        },
        timeout: 10
      )
      
      return nil unless response.success?
      
      data = response.parsed_response['data']
      
      {
        'name' => subreddit.downcase,
        'display_name' => data['display_name'],
        'subscribers' => data['subscribers'].to_i,
        'active_users' => data['active_user_count'].to_i,
        'over18' => data['over18'] || false,
        'description' => data['public_description'] || '',
        'created_utc' => data['created_utc']
      }
    rescue => e
      log_error("Fetch details error for r/#{subreddit}", e)
      nil
    end
    
    # Filter subreddits by quality criteria
    def filter_quality(subreddits)
      subreddits.select do |sub|
        # Must meet minimum size requirements
        next false unless sub['subscribers'].to_i >= MIN_SUBSCRIBERS
        next false unless sub['active_users'].to_i >= MIN_ACTIVE_USERS
        
        # Must not be NSFW
        next false if sub['over18']
        
        # Must be meme-focused (heuristic)
        next false unless is_meme_focused?(sub)
        
        true
      end
    end
    
    # Check if subreddit is likely meme-focused
    def is_meme_focused?(sub)
      name = sub['name'].downcase
      desc = sub['description'].downcase
      
      # Positive indicators
      meme_keywords = ['meme', 'funny', 'humor', 'joke', 'comedy', 'laugh', 'gif', 'image']
      has_meme_keyword = meme_keywords.any? { |kw| name.include?(kw) || desc.include?(kw) }
      
      # Negative indicators (non-meme content)
      non_meme_keywords = ['news', 'discussion', 'question', 'ask', 'help', 'support']
      has_non_meme = non_meme_keywords.any? { |kw| name.include?(kw) }
      
      has_meme_keyword && !has_non_meme
    end
    
    # Remove duplicates and filter out existing subreddits
    def dedup_and_filter_existing(discovered)
      # Load existing subreddits
      current = YAML.load_file('data/subreddits.yml')
      existing_names = current.values.flatten.map(&:downcase).to_set
      
      # Filter out existing and deduplicate
      discovered
        .uniq { |s| s['name'] }
        .reject { |s| existing_names.include?(s['name'].downcase) }
    rescue => e
      log_error("Dedup and filter error", e)
      discovered.uniq { |s| s['name'] }
    end
    
    # Load existing candidates from file
    def load_existing_candidates(filename)
      return [] unless File.exist?(filename)
      
      data = YAML.load_file(filename)
      data['candidates'] || []
    rescue => e
      log_error("Load existing candidates error", e)
      []
    end
    
    # Centralized error logging
    def log_error(context, error)
      message = error.is_a?(String) ? error : error.message
      puts "⚠️  [SubredditDiscovery] #{context}: #{message}"
      
      if defined?(Sentry) && error.is_a?(Exception)
        Sentry.capture_exception(error, extra: { context: context })
      end
    end
  end
end
