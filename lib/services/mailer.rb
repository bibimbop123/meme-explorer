# frozen_string_literal: true

require 'httparty'

# Mailer - minimal provider-agnostic transactional email delivery.
#
# Backends:
# - Log backend (default outside production, or when no adapter is set):
#   records deliveries to Mailer.deliveries (inspectable in tests) and logs
#   the message. This IS real delivery for development/staging purposes.
# - Resend adapter (MAILER_ADAPTER=resend + RESEND_API_KEY + MAIL_FROM):
#   delivers via the Resend HTTPS API using the already-bundled HTTParty -
#   no new gem required. Other providers plug in the same way later.
#
# Security: never log recipient addresses or message bodies in production -
# a password-reset URL is a credential.
class Mailer
  class DeliveryError < StandardError; end

  @deliveries = []

  class << self
    attr_reader :deliveries

    def reset_deliveries!
      @deliveries = []
    end

    # A "Forgot password?" link may only be shown when reset mail can really
    # be delivered - the log backend counts as deliverable outside production
    # (development/staging); production requires an explicit adapter.
    def configured?
      adapter = ENV['MAILER_ADAPTER'].to_s.strip
      return !from_address.empty? && !ENV['RESEND_API_KEY'].to_s.empty? if adapter == 'resend'
      return false if adapter && !adapter.empty?

      ENV['RACK_ENV'] != 'production'
    end

    def deliver(to:, subject:, text:)
      adapter = ENV['MAILER_ADAPTER'].to_s.strip
      case adapter
      when 'resend'
        deliver_resend(to: to, subject: subject, text: text)
      when ''
        deliver_log(to: to, subject: subject, text: text)
      else
        raise DeliveryError, "Unknown MAILER_ADAPTER: #{adapter}"
      end
    end

    private

    def from_address
      ENV['MAIL_FROM'].to_s.strip
    end

    def deliver_log(to:, subject:, text:)
      @deliveries << { to: to, subject: subject, text: text, backend: :log, at: Time.now.utc }
      if ENV['RACK_ENV'] == 'production'
        # Never log bodies/recipients in production - reset URLs are secrets.
        AppLogger.warn('[MAILER] log backend active in production - transactional mail NOT delivered') if defined?(AppLogger)
      else
        AppLogger.info("[MAILER] log delivery to=#{mask(to)} subject=#{subject} body:\n#{text}") if defined?(AppLogger)
      end
      { success: true, backend: :log }
    end

    def deliver_resend(to:, subject:, text:)
      raise DeliveryError, 'MAIL_FROM not configured' if from_address.empty?
      api_key = ENV['RESEND_API_KEY'].to_s
      raise DeliveryError, 'RESEND_API_KEY not configured' if api_key.empty?

      response = HTTParty.post(
        'https://api.resend.com/emails',
        headers: { 'Authorization' => "Bearer #{api_key}", 'Content-Type' => 'application/json' },
        body: { from: from_address, to: [to], subject: subject, text: text }.to_json,
        timeout: 10
      )
      unless response.code.to_i.between?(200, 299)
        AppLogger.warn("[MAILER] Resend delivery failed (HTTP #{response.code})") if defined?(AppLogger)
        raise DeliveryError, "Resend API error (HTTP #{response.code})"
      end
      { success: true, backend: :resend }
    rescue Net::OpenTimeout, Net::ReadTimeout, SocketError, SystemCallError => e
      AppLogger.warn("[MAILER] Resend delivery network failure: #{e.class}") if defined?(AppLogger)
      raise DeliveryError, 'mail provider unreachable'
    end

    def mask(email)
      local, _, domain = email.to_s.partition('@')
      "#{local.to_s[0]}***@#{domain}"
    end
  end
end
