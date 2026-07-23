# frozen_string_literal: true

# Secure Session Configuration
# Created: July 22, 2026

module SessionConfig
  class << self
    def options
      {
        key: ENV['SESSION_KEY'] || 'meme_explorer_session',
        secret: ENV['SESSION_SECRET'] || generate_secret,
        expire_after: 7.days,
        secure: production?,
        httponly: true,
        same_site: :strict,
        path: '/',
        domain: ENV['SESSION_DOMAIN']
      }
    end

    private

    def generate_secret
      require 'securerandom'
      SecureRandom.hex(64)
    end

    def production?
      ENV['RACK_ENV'] == 'production'
    end

    def days
      24 * 60 * 60  # seconds in a day
    end
  end
end
