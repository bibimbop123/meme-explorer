# frozen_string_literal: true
require_relative 'feed_candidate_service'

module MemeExplorer
  # Unused, process-local single-pass snapshot. Not a client cursor/session store.
  # Snapshot completion is not an inventory-wide replay authorization.
  class FeedTraversal
    MAX_CANDIDATES = 5000

    def initialize(candidates, session_id, user_id: nil)
      @offset = 0
      @reserved = false
      @terminal = false
      @valid = candidates.is_a?(Array) && candidates.size <= MAX_CANDIDATES &&
        session_id.is_a?(String) && session_id.match?(/\A[a-f0-9]{64}\z/) &&
        FeedAcknowledgementStore.valid_issuance_context?(user_id: user_id)
      return unless @valid
      @session_id = session_id.dup.freeze
      @user_id = user_id
      identities = Set.new
      @candidates = []
      candidates.each do |meme|
        unless meme.is_a?(Hash)
          @valid = false
          break
        end
        content = meme['url'] || meme[:url] || meme['file'] || meme[:file]
        title = meme['title'] || meme[:title]
        subreddit = meme['subreddit'] || meme[:subreddit]
        unless content.is_a?(String) && content.valid_encoding? && content.bytesize <= 4096 && !content.strip.empty? &&
          FeedAcknowledgementStore.valid_issuance_context?(title: title, subreddit: subreddit, user_id: user_id)
          @valid = false
          break
        end
        next unless identities.add?(content)
        @candidates << { 'url' => content.dup.freeze, 'title' => title&.dup&.freeze,
                         'subreddit' => subreddit&.dup&.freeze }.freeze
      end
      @candidates.freeze
      @mutex = Mutex.new
    end

    def advance
      return { status: :invalid } unless @valid
      @mutex.synchronize do
        return { status: :closed } if @terminal
        result = FeedCandidateService.select(@candidates, @session_id, user_id: @user_id, offset: @offset)
        if result[:status] == :traversal_incomplete
          @offset = result[:next_offset]
          @reserved ||= result[:reserved]
          return { status: :traversal_incomplete, reserved: @reserved }
        end
        @terminal = true
        if [:suffix_complete, :exhausted, :temporarily_reserved, :empty].include?(result[:status])
          @reserved ||= result[:reserved] || result[:status] == :temporarily_reserved
          return { status: :snapshot_complete, reserved: @reserved, empty: @candidates.empty? }
        end
        result
      end
    end
  end
end