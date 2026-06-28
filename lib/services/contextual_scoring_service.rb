# frozen_string_literal: true

# Contextual Scoring Service
# Adapts content recommendations based on time of day, day of week, and context
# 
# Usage:
#   boost = ContextualScoringService.calculate_contextual_boost(meme)
#   score *= boost
#
# Created: June 28, 2026
# Impact: Better content match for user's current context

module MemeExplorer
  class ContextualScoringService
    # Time-of-day content preferences (learned from user behavior patterns)
    TIME_PREFERENCES = {
      morning: {      # 6am-12pm: Start day positive
        'wholesome' => 2.0,
        'motivational' => 1.8,
        'cute' => 1.7,
        'relatable' => 1.5,
        'funny' => 1.3,
        'dark' => 0.5,
        'absurdist' => 0.7,
        'edgy' => 0.6
      },
      afternoon: {    # 12pm-6pm: Midday entertainment
        'funny' => 1.8,
        'relatable' => 1.6,
        'dank' => 1.4,
        'wholesome' => 1.2,
        'relationship' => 1.5,
        'work' => 1.6,
        'dark' => 1.0
      },
      evening: {      # 6pm-12am: Peak social/entertainment time
        'dank' => 2.0,
        'dark' => 1.8,
        'absurdist' => 1.7,
        'funny' => 1.6,
        'relationship' => 1.9,
        'edgy' => 1.7,
        'wholesome' => 1.0
      },
      night: {        # 12am-6am: Late night browsing
        'dark' => 2.0,
        'absurdist' => 1.9,
        'existential' => 1.8,
        'deep' => 1.7,
        'surreal' => 1.8,
        'wholesome' => 0.8,
        'motivational' => 0.5
      }
    }.freeze

    # Day-of-week emotional patterns
    DAY_PREFERENCES = {
      monday: {
        'motivational' => 1.5,
        'relatable' => 1.8,      # Monday struggles are relatable
        'work' => 1.6,
        'dark' => 1.3,
        'coffee' => 1.9
      },
      tuesday: {
        'work' => 1.4,
        'relatable' => 1.5,
        'funny' => 1.3
      },
      wednesday: {
        'relatable' => 1.6,
        'funny' => 1.4,
        'wholesome' => 1.3
      },
      thursday: {
        'funny' => 1.5,
        'relationship' => 1.4,
        'wholesome' => 1.3
      },
      friday: {
        'funny' => 1.8,
        'relationship' => 1.6,
        'wholesome' => 1.5,
        'party' => 1.9,
        'weekend' => 1.8
      },
      saturday: {
        'absurdist' => 1.6,
        'dank' => 1.7,
        'funny' => 1.6,
        'wholesome' => 1.5,
        'relationship' => 1.7
      },
      sunday: {
        'wholesome' => 1.8,
        'relatable' => 1.7,      # Sunday scaries
        'existential' => 1.5,
        'work' => 0.7            # Nobody wants work memes on Sunday
      }
    }.freeze

    class << self
      # Main method: Calculate contextual boost for a meme
      def calculate_contextual_boost(meme)
        return 1.0 unless meme

        categories = extract_categories(meme)
        return 1.0 if categories.empty?

        time_period = get_time_period
        day = get_day_of_week

        # Get time-based boost
        time_boost = calculate_time_boost(categories, time_period)

        # Get day-based boost
        day_boost = calculate_day_boost(categories, day)

        # Combine (weighted average: 60% time, 40% day)
        combined_boost = (time_boost * 0.6) + (day_boost * 0.4)

        # Log for debugging (can disable in production)
        log_boost(meme, time_period, day, combined_boost) if should_log?

        combined_boost
      rescue => e
        AppLogger.warn("[ContextualScoring] Error calculating boost: #{e.message}")
        1.0 # Fail gracefully
      end

      # Get current time period
      def get_time_period
        hour = Time.now.hour
        case hour
        when 6...12  then :morning
        when 12...18 then :afternoon
        when 18...24 then :evening
        else :night
        end
      end

      # Get current day of week
      def get_day_of_week
        Time.now.strftime('%A').downcase.to_sym
      end

      # Get weekend vs weekday
      def weekend?
        [:saturday, :sunday].include?(get_day_of_week)
      end

      # Calculate boost based on time of day
      def calculate_time_boost(categories, time_period)
        preferences = TIME_PREFERENCES[time_period] || {}
        
        # Get max boost across all categories
        boosts = categories.map { |cat| preferences[cat] || 1.0 }
        boosts.max || 1.0
      end

      # Calculate boost based on day of week
      def calculate_day_boost(categories, day)
        preferences = DAY_PREFERENCES[day] || {}
        
        # Get max boost across all categories
        boosts = categories.map { |cat| preferences[cat] || 1.0 }
        boosts.max || 1.0
      end

      # Extract categories from meme
      def extract_categories(meme)
        categories = meme['categories'] || meme[:categories] || []
        
        # Handle different formats
        case categories
        when String
          [categories.downcase]
        when Array
          categories.map { |c| c.to_s.downcase }
        else
          []
        end
      end

      # Get human-readable context description
      def current_context_description
        time_period = get_time_period
        day = get_day_of_week
        
        "#{day.to_s.capitalize} #{time_period}"
      end

      # Get recommended categories for current context
      def recommended_categories(limit: 5)
        time_period = get_time_period
        day = get_day_of_week
        
        time_prefs = TIME_PREFERENCES[time_period] || {}
        day_prefs = DAY_PREFERENCES[day] || {}
        
        # Combine and sort
        all_prefs = {}
        (time_prefs.keys + day_prefs.keys).uniq.each do |category|
          time_weight = time_prefs[category] || 1.0
          day_weight = day_prefs[category] || 1.0
          all_prefs[category] = (time_weight * 0.6) + (day_weight * 0.4)
        end
        
        all_prefs.sort_by { |_, v| -v }.take(limit).to_h
      end

      # Admin: Get statistics about contextual scoring
      def get_statistics
        {
          current_context: current_context_description,
          time_period: get_time_period,
          day_of_week: get_day_of_week,
          is_weekend: weekend?,
          top_categories: recommended_categories(limit: 10),
          total_time_periods: TIME_PREFERENCES.keys.size,
          total_day_rules: DAY_PREFERENCES.keys.size
        }
      end

      private

      # Should we log boost calculations?
      def should_log?
        # Only log in development or if explicitly enabled
        ENV['CONTEXTUAL_SCORING_DEBUG'] == 'true'
      end

      # Log boost calculation for debugging
      def log_boost(meme, time_period, day, boost)
        return unless defined?(AppLogger)

        categories = extract_categories(meme)
        title = meme['title'] || meme[:title] || 'Unknown'
        
        AppLogger.debug(
          "[ContextualScoring] " \
          "Meme: #{title[0..50]}... | " \
          "Categories: #{categories.join(', ')} | " \
          "Context: #{day} #{time_period} | " \
          "Boost: #{boost.round(2)}x"
        )
      end
    end # class << self
  end # class ContextualScoringService
end # module MemeExplorer
