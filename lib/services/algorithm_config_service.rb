# Algorithm Configuration Service
# Loads and manages algorithm parameters from YAML config
# Phase 2: Enables data-driven optimization without code deploys

class AlgorithmConfigService
    @config = nil
    @config_mtime = nil
    
    class << self
      # Load config with hot-reloading support
      def config
        config_path = File.join(File.dirname(__FILE__), '../../config/algorithm_config.yml')
        current_mtime = File.mtime(config_path)
        
        # Reload if file changed (hot-reload in development)
        if @config.nil? || (ENV['RACK_ENV'] == 'development' && current_mtime != @config_mtime)
          @config = YAML.load_file(config_path)
          @config_mtime = current_mtime
          puts "✅ Algorithm config loaded (env: #{ENV['RACK_ENV'] || 'development'})"
        end
        
        @config[ENV['RACK_ENV'] || 'development'] || @config['development']
      end
      
      # Get streak bonus for consecutive likes
      def streak_bonus(consecutive_likes)
        bonuses = config['streak_bonuses']
        case consecutive_likes
        when 0..1 then bonuses['none']
        when 2 then bonuses['warming_up']
        when 3..4 then bonuses['hot_streak']
        when 5..9 then bonuses['on_fire']
        else bonuses['legendary']
        end
      end
      
      # Get freshness multiplier based on age in hours
      def freshness_multiplier(age_hours)
        f = config['freshness']
        case age_hours
        when 0..f['brand_new_hours'] then f['brand_new_boost']
        when (f['brand_new_hours']+1)..f['ultra_fresh_hours'] then f['ultra_fresh_boost']
        when (f['ultra_fresh_hours']+1)..f['very_fresh_hours'] then f['very_fresh_boost']
        when (f['very_fresh_hours']+1)..f['today_hours'] then f['today_boost']
        when (f['today_hours']+1)..f['yesterday_hours'] then f['yesterday_boost']
        when (f['yesterday_hours']+1)..f['this_week_hours'] then f['this_week_boost']
        when (f['this_week_hours']+1)..f['this_month_hours'] then f['this_month_boost']
        else f['old_content_penalty']
        end
      end
      
      # Get viral boost based on likes and comments
      def viral_multiplier(likes, comments, upvote_ratio)
        v = config['viral']
        
        if likes >= v['mega_threshold'] && upvote_ratio >= v['mega_ratio']
          v['mega_boost']
        elsif likes >= v['super_threshold'] && upvote_ratio >= v['super_ratio']
          v['super_boost']
        elsif likes >= v['viral_threshold'] && comments >= v['viral_comments']
          v['viral_boost']
        elsif likes >= v['popular_threshold'] && comments >= v['popular_comments']
          v['popular_boost']
        elsif likes >= v['good_threshold']
          v['good_boost']
        elsif likes >= v['decent_threshold']
          v['decent_boost']
        else
          1.0
        end
      end
      
      # Get variety bonus based on recent humor types
      def variety_bonus(same_type_count_in_last_5)
        v = config['variety']
        case same_type_count_in_last_5
        when 0 then v['new_type_bonus']
        when 1 then v['normal']
        when 2 then v['starting_repeat']
        when 3 then v['too_much']
        else v['way_too_much']
        end
      end
      
      # Get time of day multiplier for humor type
      def time_of_day_multiplier(humor_type, hour = Time.now.hour)
        tod = config['time_of_day']
        
        # Handle midnight wrap (23-2 -> 23, 0, 1, 2)
        adjusted_hour = hour >= 23 ? hour : (hour < 3 ? hour + 24 : hour)
        
        period = case adjusted_hour
        when 6..10 then tod['morning']
        when 11..14 then tod['lunch']
        when 15..17 then tod['afternoon']
        when 18..22 then tod['evening']
        when 23..26 then tod['late_night']  # 23-2 (26 = 2am next day)
        else tod['early_morning']  # 3-5
        end
        
        key = "#{humor_type}_boost"
        penalty_key = "#{humor_type}_penalty"
        
        period[key] || period[penalty_key] || 1.0
      end
      
      # Get surprise chance configuration
      def surprise_config
        config['surprise']
      end
      
      # Get personalization configuration
      def personalization_config
        config['personalization']
      end
      
      # Get quality thresholds
      def quality_config
        config['quality']
      end
      
      # Get preference decay settings
      def preference_decay_config
        config['preference_decay']
      end
      
      # Get cold start configuration
      def cold_start_config
        config['cold_start']
      end
      
      # Calculate decayed weight for preference (exponential decay)
      def calculate_preference_decay(weight, created_at)
        decay_config = preference_decay_config
        return weight unless decay_config['enabled']
        
        days_old = (Time.now - created_at) / 86400.0
        half_life = decay_config['half_life_days']
        min_weight = decay_config['min_weight']
        
        decayed = weight * (0.5 ** (days_old / half_life))
        [decayed, min_weight].max
      end
      
      # Check if user is in cold start phase
      def is_cold_start_user?(view_count)
        view_count < cold_start_config['detection_threshold']
      end
      
      # Get all config as hash (for debugging/admin panel)
      def all_config
        config
      end
      
      # Reload config (useful for testing)
      def reload!
        @config = nil
        @config_mtime = nil
        config
      end
    end
end
