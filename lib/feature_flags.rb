# Feature flag system for controlled rollouts and A/B testing
class FeatureFlags
  class << self
    def enabled?(feature_path)
      return false if feature_path.nil? || feature_path.empty?
      
      config = load_config
      keys = feature_path.to_s.split('.')
      
      result = keys.reduce(config['features']) do |hash, key|
        return false unless hash.is_a?(Hash)
        hash[key]
      end
      
      result == true
    end
    
    def get(feature_path, default = nil)
      config = load_config
      keys = feature_path.to_s.split('.')
      
      result = keys.reduce(config['features']) do |hash, key|
        return default unless hash.is_a?(Hash)
        hash[key]
      end
      
      result.nil? ? default : result
    end
    
    def load_config
      @config ||= begin
        require 'yaml'
        require 'erb'
        
        template = File.read('config/features.yml')
        rendered = ERB.new(template).result
        YAML.safe_load(rendered, aliases: true)
      rescue StandardError => err
        puts "⚠️  Error loading feature flags: #{err.message}"
        { 'features' => {} }
      end
    end
    
    def reload!
      @config = nil
      load_config
    end
  end
end
