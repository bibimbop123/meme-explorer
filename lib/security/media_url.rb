# frozen_string_literal: true
require 'uri'

# Browser rendering policy, not an SSRF policy for server-side downloads.
module MediaUrl
  # Metadata candidates only; extensions do not prove availability or MIME type.
  def self.social_image(value, origin:)
    candidate = safe(value)
    return nil unless candidate
    uri = URI.parse(candidate)
    return nil unless uri.path.match?(/\.(jpe?g|png|webp|gif)\z/i)
    candidate.start_with?('/') ? "#{origin}#{candidate}" : candidate
  rescue URI::InvalidURIError
    nil
  end

  def self.safe(value)
    return nil unless value.is_a?(String) && !value.empty?
    return nil if value.match?(/[\x00-\x20\x7f<>"'\\]/)
    return value if value.start_with?('/') && !value.start_with?('//')

    uri = URI.parse(value)
    return value if %w[http https].include?(uri.scheme) && uri.host && !uri.userinfo
    nil
  rescue URI::InvalidURIError
    nil
  end
end