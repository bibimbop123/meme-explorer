# frozen_string_literal: true
require 'uri'

module PublicOrigin
  def self.resolve(configured:, production:, fallback:)
    value = configured.to_s
    return production ? nil : fallback if value.empty?
    return nil if value.match?(/[\x00-\x20\x7f\\]/)
    uri = URI.parse(value)
    return nil unless uri.is_a?(URI::HTTPS) && uri.host && !uri.userinfo &&
                      ['', '/'].include?(uri.path) && !uri.query && !uri.fragment
    value.sub(%r{/\z}, '')
  rescue URI::InvalidURIError
    nil
  end
end