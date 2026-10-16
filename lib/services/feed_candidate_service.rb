# frozen_string_literal: true
require 'set'
require_relative 'feed_issuance_service'

module MemeExplorer
  # Unused traversal of server-filtered candidates in caller-supplied ranking order.
  # Does not replace personalization/media filtering or authorize exhausted replay.
  class FeedCandidateService
    MAX_ATTEMPTS = 100
    MAX_INSPECTED = 1000
    def self.select(candidates, session_id, user_id: nil, offset: 0)
      return { status: :invalid } unless candidates.is_a?(Array) &&
        session_id.is_a?(String) && session_id.match?(/\A[a-f0-9]{64}\z/) &&
        offset.is_a?(Integer) && offset.between?(0, candidates.length)
      return { status: :invalid } unless FeedAcknowledgementStore.valid_issuance_context?(user_id: user_id)
      identities = Set.new
      reserved = false
      (offset...candidates.length).each do |index|
        return { status: :traversal_incomplete, next_offset: index, reserved: reserved } if index - offset >= MAX_INSPECTED
        meme = candidates[index]
        return { status: :invalid } unless meme.is_a?(Hash)
        content = meme['url'] || meme[:url] || meme['file'] || meme[:file]
        return { status: :invalid } unless content.is_a?(String) && content.valid_encoding? &&
          content.bytesize <= 4096 && !content.strip.empty?
        next unless identities.add?(content)
        return { status: :traversal_incomplete, next_offset: index, reserved: reserved } if identities.size > MAX_ATTEMPTS
        result = FeedIssuanceService.issue(session_id, content,
          title: meme['title'] || meme[:title], subreddit: meme['subreddit'] || meme[:subreddit], user_id: user_id)
        case result[:status]
        when :issued then return result.merge(meme: meme)
        when :already_acknowledged then next
        when :already_reserved then reserved = true
        else return result
        end
      end
      # A suffix cannot establish exhaustion or summarize conflicts in its prefix.
      return { status: :suffix_complete, reserved: reserved } if offset > 0
      return { status: :empty } if identities.empty?
      { status: reserved ? :temporarily_reserved : :exhausted }
    end
  end
end