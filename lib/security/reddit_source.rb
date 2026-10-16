# frozen_string_literal: true
require 'uri'

module RedditSource
  def self.path(value)
    return nil unless value.is_a?(String) && !value.match?(/[\x00-\x20<>"'\\]/)
    uri = URI.parse(value)
    if uri.absolute?
      return nil unless %w[http https].include?(uri.scheme) && %w[reddit.com www.reddit.com old.reddit.com].include?(uri.host) && !uri.userinfo && [80, 443].include?(uri.port)
    else
      return nil if uri.host || !value.start_with?('/') || value.start_with?('//')
    end
    uri.path if uri.path.match?(%r{\A/r/[A-Za-z0-9_]+/comments/[A-Za-z0-9]+(?:/[^<>"'\\]*)?\z})
  rescue URI::InvalidURIError
    nil
  end
end