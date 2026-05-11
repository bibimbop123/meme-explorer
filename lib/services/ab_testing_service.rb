# A/B Testing Service
# Provides consistent variant assignment and conversion tracking
# Uses consistent hashing to ensure users always see the same variant

require 'digest'

class ABTestingService
  class << self
    # Get variant for a user in an experiment
    # Uses consistent hashing so same user always gets same variant
    def get_variant(experiment_name, user_identifier)
      return nil if experiment_name.nil? || user_identifier.nil?
      
      begin
        # Get experiment
        experiment = get_experiment(experiment_name)
        return nil unless experiment && experiment['active']
        
        # Check if user already assigned
        existing = DB.execute(
          "SELECT variant FROM experiment_assignments 
           WHERE experiment_id = ? AND user_identifier = ?",
          [experiment['id'], user_identifier]
        ).first
        
        return existing['variant'] if existing
        
        # Assign new variant using consistent hashing
        variant = assign_variant(experiment, user_identifier)
        
        # Store assignment
        DB.execute(
          "INSERT INTO experiment_assignments (experiment_id, user_identifier, variant)
           VALUES (?, ?, ?)
           ON CONFLICT (experiment_id, user_identifier) DO NOTHING",
          [experiment['id'], user_identifier, variant]
        )
        
        variant
      rescue => e
        puts "⚠️ [A/B Testing] Error getting variant: #{e.message}"
        Sentry.capture_exception(e) if defined?(Sentry)
        nil
      end
    end
    
    # Track a conversion event
    def track_conversion(experiment_name, user_identifier, conversion_type, metadata = {})
      return false if experiment_name.nil? || user_identifier.nil?
      
      begin
        experiment = get_experiment(experiment_name)
        return false unless experiment
        
        # Get user's variant
        assignment = DB.execute(
          "SELECT variant FROM experiment_assignments 
           WHERE experiment_id = ? AND user_identifier = ?",
          [experiment['id'], user_identifier]
        ).first
        
        return false unless assignment
        
        # Record conversion
        DB.execute(
          "INSERT INTO experiment_conversions 
           (experiment_id, user_identifier, variant, conversion_type, metadata)
           VALUES (?, ?, ?, ?, ?)",
          [
            experiment['id'],
            user_identifier,
            assignment['variant'],
            conversion_type,
            metadata.to_json
          ]
        )
        
        true
      rescue => e
        puts "⚠️ [A/B Testing] Error tracking conversion: #{e.message}"
        Sentry.capture_exception(e) if defined?(Sentry)
        false
      end
    end
    
    # Get experiment statistics
    def get_stats(experiment_name)
      begin
        experiment = get_experiment(experiment_name)
        return nil unless experiment
        
        # Get variant assignments
        assignments = DB.execute(
          "SELECT variant, COUNT(*) as count
           FROM experiment_assignments
           WHERE experiment_id = ?
           GROUP BY variant",
          [experiment['id']]
        )
        
        # Get conversions by variant
        conversions = DB.execute(
          "SELECT variant, conversion_type, COUNT(*) as count
           FROM experiment_conversions
           WHERE experiment_id = ?
           GROUP BY variant, conversion_type",
          [experiment['id']]
        )
        
        # Calculate conversion rates
        results = {}
        assignments.each do |row|
          variant = row['variant']
          total_users = row['count']
          
          variant_conversions = conversions.select { |c| c['variant'] == variant }
          total_conversions = variant_conversions.sum { |c| c['count'] }
          
          conversion_rate = total_users > 0 ? (total_conversions.to_f / total_users * 100).round(2) : 0
          
          results[variant] = {
            users: total_users,
            conversions: total_conversions,
            conversion_rate: conversion_rate,
            conversions_by_type: variant_conversions.map { |c| 
              { type: c['conversion_type'], count: c['count'] }
            }
          }
        end
        
        {
          experiment: experiment,
          results: results
        }
      rescue => e
        puts "⚠️ [A/B Testing] Error getting stats: #{e.message}"
        Sentry.capture_exception(e) if defined?(Sentry)
        nil
      end
    end
    
    # Create a new experiment
    def create_experiment(name, description, variants, active = false)
      begin
        # Validate variants hash sums to 1.0
        total = variants.values.sum
        unless (total - 1.0).abs < 0.01
          raise "Variant weights must sum to 1.0 (got #{total})"
        end
        
        DB.execute(
          "INSERT INTO experiments (name, description, variants, active)
           VALUES (?, ?, ?, ?)
           ON CONFLICT (name) DO UPDATE 
           SET description = EXCLUDED.description,
               variants = EXCLUDED.variants,
               active = EXCLUDED.active,
               updated_at = CURRENT_TIMESTAMP",
          [name, description, variants.to_json, active]
        )
        
        true
      rescue => e
        puts "❌ [A/B Testing] Error creating experiment: #{e.message}"
        Sentry.capture_exception(e) if defined?(Sentry)
        false
      end
    end
    
    # Toggle experiment active status
    def toggle_experiment(experiment_name, active)
      begin
        DB.execute(
          "UPDATE experiments SET active = ?, updated_at = CURRENT_TIMESTAMP 
           WHERE name = ?",
          [active, experiment_name]
        )
        true
      rescue => e
        puts "❌ [A/B Testing] Error toggling experiment: #{e.message}"
        false
      end
    end
    
    # List all experiments
    def list_experiments
      begin
        DB.execute("SELECT * FROM experiments ORDER BY created_at DESC")
      rescue => e
        puts "❌ [A/B Testing] Error listing experiments: #{e.message}"
        []
      end
    end
    
    private
    
    # Get experiment by name
    def get_experiment(name)
      DB.execute(
        "SELECT * FROM experiments WHERE name = ? LIMIT 1",
        [name]
      ).first
    rescue => e
      puts "⚠️ [A/B Testing] Error fetching experiment: #{e.message}"
      nil
    end
    
    # Assign variant using consistent hashing
    def assign_variant(experiment, user_identifier)
      # Parse variants
      variants = JSON.parse(experiment['variants'])
      
      # Create hash of user identifier
      hash = Digest::MD5.hexdigest("#{experiment['name']}_#{user_identifier}").to_i(16)
      
      # Normalize to 0-1 range
      normalized = (hash % 1_000_000) / 1_000_000.0
      
      # Assign variant based on cumulative weights
      cumulative = 0.0
      variants.each do |variant_name, weight|
        cumulative += weight
        return variant_name if normalized < cumulative
      end
      
      # Fallback to first variant (shouldn't happen if weights sum to 1.0)
      variants.keys.first
    end
  end
end
