# frozen_string_literal: true

# Configuration Schema & Validation
# Validates required ENV variables on application boot to prevent runtime errors
# in production due to missing configuration.

class ConfigSchema
  # Required environment variables per environment
  REQUIRED = {
    production: %w[
      DATABASE_URL
      REDIS_URL
      SESSION_SECRET
      REDDIT_CLIENT_ID
      REDDIT_CLIENT_SECRET
    ],
    development: %w[
      DATABASE_URL
    ],
    test: %w[
      DATABASE_URL
    ]
  }.freeze

  # Optional environment variables with their purposes
  # These enhance functionality but aren't critical for operation
  OPTIONAL = {
    # Error Tracking
    'SENTRY_DSN' => 'Error tracking and monitoring',
    'SENTRY_ENVIRONMENT' => 'Sentry environment name',
    'SENTRY_TRACES_SAMPLE_RATE' => 'Performance monitoring sample rate',
    
    # Authentication & Security
    'SIDEKIQ_USERNAME' => 'Sidekiq web UI basic auth username',
    'SIDEKIQ_PASSWORD' => 'Sidekiq web UI basic auth password',
    'GOOGLE_SITE_VERIFICATION' => 'Google Search Console verification',
    
    # Advertisement
    'GOOGLE_ADSENSE_CLIENT' => 'Google AdSense publisher ID',
    'GOOGLE_AD_SLOT_SQUARE' => 'Square ad unit ID',
    'GOOGLE_AD_SLOT_BANNER' => 'Banner ad unit ID',
    'GOOGLE_AD_SLOT_NATIVE' => 'Native ad unit ID',
    'AD_FREQUENCY' => 'Show ad every N memes (default: 12)',
    'DISABLE_ADS' => 'Disable all ads (testing/premium)',
    
    # Server Configuration
    'PORT' => 'Server port (default: 8080)',
    'LOG_LEVEL' => 'Logging level (debug, info, warn, error)',
    'PUMA_THREADS' => 'Puma thread count',
    'WEB_CONCURRENCY' => 'Puma worker count',
    'RAILS_MAX_THREADS' => 'Max threads per worker',
    
    # Feature Flags
    'PHASE_3_ENABLED' => 'Enable Phase 3 features',
    'ENABLE_SPACED_REPETITION' => 'Enable spaced repetition algorithm',
    'ENABLE_PERSONALIZATION' => 'Enable personalized recommendations',
    
    # Database (legacy)
    'DATABASE_TYPE' => 'Database type (sqlite3/postgres)',
    'DATABASE_PATH' => 'SQLite database file path',
    'DB_TYPE' => 'Alternative database type flag',
    
    # OAuth
    'REDDIT_REDIRECT_URI' => 'Reddit OAuth callback URL'
  }.freeze

  # Environment variables that should never be committed to git
  SENSITIVE = %w[
    SESSION_SECRET
    REDIS_URL
    DATABASE_URL
    REDDIT_CLIENT_SECRET
    SENTRY_DSN
    SIDEKIQ_PASSWORD
    GOOGLE_ADSENSE_CLIENT
  ].freeze

  class << self
    # Validate configuration on application boot
    # Raises ConfigurationError if required variables are missing
    def validate!
      env = current_environment
      required_vars = REQUIRED[env] || []
      
      missing = required_vars.select { |key| missing_or_empty?(key) }
      
      if missing.any?
        raise ConfigurationError, format_missing_vars_error(missing, env)
      end
      
      log_validation_success(required_vars.size, env)
      warn_about_optional_vars if env == :production
    end
    
    # Check if all required variables are present (for health checks)
    def valid?
      env = current_environment
      required_vars = REQUIRED[env] || []
      required_vars.none? { |key| missing_or_empty?(key) }
    end
    
    # Get current environment as symbol
    def current_environment
      (ENV['RACK_ENV'] || 'development').to_sym
    end
    
    # List all configuration variables with their values (masked for sensitive vars)
    def inspect_config
      all_vars = REQUIRED.values.flatten.uniq + OPTIONAL.keys
      
      all_vars.sort.map do |var|
        value = ENV[var]
        display_value = if value.nil?
          '[NOT SET]'
        elsif SENSITIVE.include?(var)
          '[REDACTED]'
        else
          value
        end
        
        "#{var}=#{display_value}"
      end
    end
    
    private
    
    def missing_or_empty?(key)
      value = ENV[key]
      value.nil? || value.empty?
    end
    
    def format_missing_vars_error(missing, env)
      error_msg = <<~ERROR
        ❌ Configuration Error: Missing required environment variables for #{env}
        
        Missing variables:
        #{missing.map { |var| "  - #{var}" }.join("\n")}
        
        To fix:
        1. Copy .env.example to .env
        2. Fill in the missing values
        3. Restart the application
        
        Example:
          export #{missing.first}=your-value-here
        
        See .env.example for documentation on each variable.
      ERROR
      
      error_msg.strip
    end
    
    def log_validation_success(count, env)
      puts "✅ Configuration validated for #{env} environment"
      puts "   #{count} required variables present"
    end
    
    def warn_about_optional_vars
      important_optional = %w[SENTRY_DSN GOOGLE_ADSENSE_CLIENT]
      missing_important = important_optional.select { |key| missing_or_empty?(key) }
      
      if missing_important.any?
        puts "\n⚠️  Optional but recommended variables not set:"
        missing_important.each do |var|
          puts "   - #{var}: #{OPTIONAL[var]}"
        end
        puts "   App will run but with reduced functionality.\n\n"
      end
    end
  end
end

# Custom error class for configuration errors
class ConfigurationError < StandardError; end
