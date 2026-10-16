# frozen_string_literal: true
require 'json'

module MemeExplorer
  # Unused protocol dispatch prerequisite. Shape validation is not authorization;
  # the selected handler must still verify session ownership/expiry and DB binding.
  class FeedAcknowledgementEnvelope
    MAX_BODY_BYTES = 1024

    # Reads from the current stream position; caller owns rewind/content-type checks.
    # Never trust Content-Length as the sole size bound.
    def self.read(body)
      raw = body.read(MAX_BODY_BYTES + 1)
      return { status: :invalid } unless raw.is_a?(String) && raw.bytesize <= MAX_BODY_BYTES
      parse(JSON.parse(raw, max_nesting: 4))
    rescue JSON::ParserError, EncodingError, IOError
      { status: :invalid }
    end

    def self.parse(data)
      return { status: :invalid } unless data.is_a?(Hash) && data.keys.all? { |key| key.is_a?(String) }
      return { status: :invalid } unless valid_id?(data['impression_id'])
      if data.key?('impression_protocol') || data.key?('ack_token')
        return { status: :invalid } unless data['impression_protocol'].is_a?(Integer) &&
          data['impression_protocol'] == 2 && valid_id?(data['ack_token'])
        { status: :versioned, impression_id: data['impression_id'].dup.freeze,
          token: data['ack_token'].dup.freeze }.freeze
      else
        { status: :legacy, impression_id: data['impression_id'].dup.freeze }.freeze
      end
    end

    def self.valid_id?(value)
      value.is_a?(String) && value.valid_encoding? && value.match?(/\A[a-f0-9]{64}\z/)
    end
    private_class_method :valid_id?
  end
end