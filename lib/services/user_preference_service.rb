# User Preference Service
# Store and retrieve user preferences (time window, sort, theme, etc.)
# Phase 3: Advanced Features - Part 2

class UserPreferenceService
  # Default preferences
  DEFAULT_PREFERENCES = {
    favorite_time_window: '24h',
    favorite_sort: 'trending',
    favorite_categories: [],
    theme_preference: 'auto',
    nsfw_filter: false,
    last_viewed_page: 0
  }.freeze

  class << self
    # Get preferences for user or session
    # @param user_id_or_session [String/Integer] User ID or session ID
    # @return [Hash] User preferences
    def get_preferences(user_id_or_session)
      prefs = fetch_from_storage(user_id_or_session)
      DEFAULT_PREFERENCES.merge(prefs || {})
    end

    # Save preferences
    # @param user_id_or_session [String/Integer] User ID or session ID
    # @param preferences [Hash] Preferences to save
    # @return [Hash] Saved preferences
    def save_preferences(user_id_or_session, preferences)
      # Validate preferences
      validated = validate_preferences(preferences)
      
      # Store in database or cache
      store_preferences(user_id_or_session, validated)
      
      validated
    end

    # Update single preference
    # @param user_id_or_session [String/Integer] User ID or session ID
    # @param key [String/Symbol] Preference key
    # @param value Preference value
    # @return [Hash] Updated preferences
    def update_preference(user_id_or_session, key, value)
      current = get_preferences(user_id_or_session)
      current[key.to_sym] = value
      save_preferences(user_id_or_session, current)
    end

    # Clear preferences (reset to defaults)
    # @param user_id_or_session [String/Integer] User ID or session ID
    def clear_preferences(user_id_or_session)
      delete_from_storage(user_id_or_session)
    end

    private

    def fetch_from_storage(user_id_or_session)
      # Try database first (for authenticated users)
      if user_id_or_session.is_a?(Integer)
        fetch_from_db(user_id_or_session)
      else
        # Try cache for session IDs
        fetch_from_cache(user_id_or_session)
      end
    end

    def fetch_from_db(user_id)
      # Placeholder: would query UserPreference model
      # return UserPreference.find_by(user_id:)&.preferences
      nil
    end

    def fetch_from_cache(session_id)
      # Placeholder: would query Redis
      # cache_key = "user_prefs:#{session_id}"
      # JSON.parse(Redis.current.get(cache_key) || '{}')
      nil
    end

    def store_preferences(user_id_or_session, preferences)
      if user_id_or_session.is_a?(Integer)
        store_in_db(user_id_or_session, preferences)
      else
        store_in_cache(user_id_or_session, preferences)
      end
    end

    def store_in_db(user_id, preferences)
      # Placeholder: would save to UserPreference model
      # UserPreference.create_or_update(user_id:, preferences:)
    end

    def store_in_cache(session_id, preferences)
      # Placeholder: would store in Redis
      # cache_key = "user_prefs:#{session_id}"
      # Redis.current.setex(cache_key, 1.year.to_i, preferences.to_json)
    end

    def delete_from_storage(user_id_or_session)
      if user_id_or_session.is_a?(Integer)
        delete_from_db(user_id_or_session)
      else
        delete_from_cache(user_id_or_session)
      end
    end

    def delete_from_db(user_id)
      # UserPreference.find_by(user_id:)&.destroy
    end

    def delete_from_cache(session_id)
      # Redis.current.del("user_prefs:#{session_id}")
    end

    def validate_preferences(preferences)
      validated = {}

      # Validate time window
      valid_windows = ['1h', '24h', '7d', 'all-time']
      validated[:favorite_time_window] = preferences[:favorite_time_window].to_s if valid_windows.include?(preferences[:favorite_time_window].to_s)
      validated[:favorite_time_window] ||= DEFAULT_PREFERENCES[:favorite_time_window]

      # Validate sort
      valid_sorts = ['trending', 'latest', 'most_liked', 'rising']
      validated[:favorite_sort] = preferences[:favorite_sort].to_s if valid_sorts.include?(preferences[:favorite_sort].to_s)
      validated[:favorite_sort] ||= DEFAULT_PREFERENCES[:favorite_sort]

      # Validate theme
      valid_themes = ['light', 'dark', 'auto']
      validated[:theme_preference] = preferences[:theme_preference].to_s if valid_themes.include?(preferences[:theme_preference].to_s)
      validated[:theme_preference] ||= DEFAULT_PREFERENCES[:theme_preference]

      # Validate categories (array of strings)
      validated[:favorite_categories] = Array(preferences[:favorite_categories]).map(&:to_s) if preferences[:favorite_categories]
      validated[:favorite_categories] ||= DEFAULT_PREFERENCES[:favorite_categories]

      # Validate boolean
      validated[:nsfw_filter] = !!preferences[:nsfw_filter]

      # Validate page number
      validated[:last_viewed_page] = preferences[:last_viewed_page].to_i.abs
      validated[:last_viewed_page] ||= DEFAULT_PREFERENCES[:last_viewed_page]

      validated
    end
  end
end

# Usage:
#
# # Get user preferences
# prefs = UserPreferenceService.get_preferences(user_id)
# # => { favorite_time_window: '24h', favorite_sort: 'trending', ... }
#
# # Save preferences
# UserPreferenceService.save_preferences(user_id, {
#   favorite_time_window: '7d',
#   favorite_sort: 'latest'
# })
#
# # Update single preference
# UserPreferenceService.update_preference(user_id, :theme_preference, 'dark')
#
# # Clear all preferences
# UserPreferenceService.clear_preferences(user_id)
