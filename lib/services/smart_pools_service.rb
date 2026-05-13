# Smart Pools Management Service - iFunny-Style Content Pools
# Dynamically optimizes pool weights based on performance data
# Uses database tracking to learn which pools perform best

module MemeExplorer
  class SmartPoolsService
    class << self
      
      # Get optimized pool weights based on historical performance
      def get_optimized_pool_weights(user_id: nil, session_id: nil)
        # Default weights (baseline)
        default_weights = {
          trending: 30,
          fresh: 25,
          vintage: 15,
          random: 20,
          serendipity: 10
        }
        
        # Get performance data from last 7 days
        performance = get_pool_performance_data(days: 7)
        
        return default_weights if performance.empty?
        
        # Optimize weights based on engagement rates
        optimized = optimize_weights_by_engagement(performance, default_weights)
        
        # Personalize for user if available
        if user_id
          optimized = personalize_weights_for_user(user_id, optimized)
        end
        
        optimized
      end
      
      # Track pool selection and performance
      def track_pool_selection(pool_type, meme, session_id:, user_id: nil)
        return unless defined?(DB) && DB
        
        begin
          DB.execute(
            "INSERT INTO pool_performance (pool_type, date, selections)
             VALUES (?, CURRENT_DATE, 1)
             ON CONFLICT (pool_type, date)
             DO UPDATE SET selections = pool_performance.selections + 1",
            [pool_type.to_s]
          )
        rescue => e
          puts "⚠️ Pool tracking error: #{e.message}"
        end
      end
      
      # Track interaction with pool-selected meme
      def track_pool_interaction(pool_type, interaction_type)
        return unless defined?(DB) && DB
        
        begin
          case interaction_type
          when 'like'
            DB.execute(
              "UPDATE pool_performance 
               SET likes = likes + 1,
                   engagement_rate = (likes + 1)::FLOAT / NULLIF(selections, 0)
               WHERE pool_type = ? AND date = CURRENT_DATE",
              [pool_type.to_s]
            )
          when 'skip'
            DB.execute(
              "UPDATE pool_performance 
               SET skips = skips + 1
               WHERE pool_type = ? AND date = CURRENT_DATE",
              [pool_type.to_s]
            )
          end
        rescue => e
          puts "⚠️ Pool interaction tracking error: #{e.message}"
        end
      end
      
      # Get pool performance analytics
      def get_pool_analytics(days: 30)
        return {} unless defined?(DB) && DB
        
        begin
          results = DB.execute(
            "SELECT 
               pool_type,
               SUM(selections) as total_selections,
               SUM(likes) as total_likes,
               SUM(skips) as total_skips,
               AVG(engagement_rate) as avg_engagement_rate,
               AVG(avg_duration) as avg_duration
             FROM pool_performance
             WHERE date >= CURRENT_DATE - INTERVAL '? days'
             GROUP BY pool_type
             ORDER BY avg_engagement_rate DESC",
            [days]
          )
          
          analytics = {}
          results.each do |row|
            analytics[row['pool_type']] = {
              selections: row['total_selections'].to_i,
              likes: row['total_likes'].to_i,
              skips: row['total_skips'].to_i,
              engagement_rate: row['avg_engagement_rate'].to_f,
              avg_duration: row['avg_duration'].to_f,
              like_rate: calculate_like_rate(row['total_likes'].to_i, row['total_selections'].to_i)
            }
          end
          
          analytics
        rescue => e
          puts "⚠️ Pool analytics error: #{e.message}"
          {}
        end
      end
      
      # Determine best performing pools
      def get_top_performing_pools(limit: 3)
        analytics = get_pool_analytics(days: 7)
        
        # Sort by engagement rate
        analytics.sort_by { |_, data| -data[:engagement_rate] }
                .take(limit)
                .map(&:first)
                .map(&:to_sym)
      end
      
      # A/B test pool configurations
      def create_experiment(experiment_name, variants)
        return unless defined?(DB) && DB
        
        begin
          variants.each do |variant_name, pool_weights|
            DB.execute(
              "INSERT INTO algorithm_experiments 
               (experiment_name, variant, pool_weights, created_at)
               VALUES (?, ?, ?, CURRENT_TIMESTAMP)",
              [experiment_name, variant_name, pool_weights.to_json]
            )
          end
          
          puts "✅ Created experiment: #{experiment_name}"
          true
        rescue => e
          puts "❌ Experiment creation error: #{e.message}"
          false
        end
      end
      
      # Get experiment results
      def get_experiment_results(experiment_name)
        return {} unless defined?(DB) && DB
        
        begin
          results = DB.execute(
            "SELECT 
               variant,
               COUNT(*) as sessions,
               AVG(total_likes) as avg_likes,
               AVG(total_skips) as avg_skips,
               AVG(avg_session_duration) as avg_duration,
               AVG(retention_score) as avg_retention
             FROM algorithm_experiments
             WHERE experiment_name = ?
             GROUP BY variant
             ORDER BY avg_retention DESC",
            [experiment_name]
          )
          
          results.map do |row|
            {
              variant: row['variant'],
              sessions: row['sessions'].to_i,
              avg_likes: row['avg_likes'].to_f,
              avg_skips: row['avg_skips'].to_f,
              avg_duration: row['avg_duration'].to_f,
              avg_retention: row['avg_retention'].to_f
            }
          end
        rescue => e
          puts "⚠️ Experiment results error: #{e.message}"
          []
        end
      end
      
      private
      
      def get_pool_performance_data(days:)
        return [] unless defined?(DB) && DB
        
        begin
          DB.execute(
            "SELECT pool_type, engagement_rate, selections
             FROM pool_performance
             WHERE date >= CURRENT_DATE - INTERVAL '? days'
             AND selections >= 10",
            [days]
          )
        rescue => e
          puts "⚠️ Performance data error: #{e.message}"
          []
        end
      end
      
      def optimize_weights_by_engagement(performance, default_weights)
        # Calculate average engagement rate per pool
        pool_engagement = {}
        
        performance.each do |row|
          pool = row['pool_type'].to_sym
          rate = row['engagement_rate'].to_f
          
          pool_engagement[pool] ||= []
          pool_engagement[pool] << rate
        end
        
        # Average engagement rates
        avg_engagement = {}
        pool_engagement.each do |pool, rates|
          avg_engagement[pool] = rates.sum / rates.size
        end
        
        return default_weights if avg_engagement.empty?
        
        # Adjust weights based on performance
        optimized = {}
        total_engagement = avg_engagement.values.sum
        
        default_weights.each do |pool, base_weight|
          if avg_engagement[pool]
            # Boost high-performing pools
            performance_multiplier = (avg_engagement[pool] / (total_engagement / avg_engagement.size))
            optimized[pool] = (base_weight * performance_multiplier).round
          else
            optimized[pool] = base_weight
          end
        end
        
        # Normalize to 100
        normalize_weights(optimized)
      end
      
      def personalize_weights_for_user(user_id, base_weights)
        return base_weights unless defined?(DB) && DB
        
        begin
          # Get user's preferred pool types
          preferences = DB.execute(
            "SELECT pool_type, COUNT(*) as uses, 
                    AVG(CASE WHEN interaction_type = 'like' THEN 1.0 ELSE 0.0 END) as like_rate
             FROM user_interactions
             WHERE user_id = ?
             AND created_at > CURRENT_TIMESTAMP - INTERVAL '30 days'
             GROUP BY pool_type
             HAVING COUNT(*) >= 5
             ORDER BY like_rate DESC",
            [user_id]
          )
          
          return base_weights if preferences.empty?
          
          # Boost user's preferred pools
          personalized = base_weights.dup
          
          preferences.each do |row|
            pool = row['pool_type'].to_sym
            like_rate = row['like_rate'].to_f
            
            if personalized[pool] && like_rate > 0.5
              # Boost by up to 50%
              boost = 1.0 + ((like_rate - 0.5) * 1.0)
              personalized[pool] = (personalized[pool] * boost).round
            end
          end
          
          normalize_weights(personalized)
        rescue => e
          puts "⚠️ Personalization error: #{e.message}"
          base_weights
        end
      end
      
      def normalize_weights(weights)
        total = weights.values.sum.to_f
        return weights if total.zero?
        
        normalized = {}
        weights.each do |pool, weight|
          normalized[pool] = ((weight / total) * 100).round
        end
        
        # Ensure it adds to 100
        diff = 100 - normalized.values.sum
        if diff != 0 && !normalized.empty?
          # Add/subtract difference to largest pool
          largest = normalized.max_by { |_, w| w }[0]
          normalized[largest] += diff
        end
        
        normalized
      end
      
      def calculate_like_rate(likes, selections)
        return 0.0 if selections.zero?
        (likes.to_f / selections * 100).round(2)
      end
    end
  end
end
