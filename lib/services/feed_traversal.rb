# frozen_string_literal: true
require_relative 'feed_candidate_service'

module MemeExplorer
  # Unused, process-local single-pass snapshot. Not a client cursor/session store.
  # Snapshot completion is not an inventory-wide replay authorization.
  class FeedTraversal
    MAX_CANDIDATES = 5000
    MAX_METADATA_BYTES = 1_048_576 # Copied string bytes, not Ruby heap/RSS usage.
    MAX_PAYLOAD_BYTES = 1_048_576
    MAX_PAYLOAD_NODES = 20_000
    MEDIA_FIELDS = %w[file media_type width height is_gallery gallery_images permalink
                      reddit_post_urls is_crosspost original_subreddit].freeze

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
      metadata_bytes = 0
      payload_budget = { bytes: 0, nodes: 0 }
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
        metadata_bytes += content.bytesize + (title&.bytesize || 0) + (subreddit&.bytesize || 0)
        if metadata_bytes > MAX_METADATA_BYTES
          @valid = false
          @candidates.clear
          break
        end
        snapshot = { 'url' => content.dup.freeze, 'title' => title&.dup&.freeze,
                     'subreddit' => subreddit&.dup&.freeze }
        begin
          MEDIA_FIELDS.each do |field|
            value = meme.key?(field) ? meme[field] : meme[field.to_sym]
            snapshot[field] = copy_media(value, payload_budget) unless value.nil?
          end
        rescue ArgumentError
          @valid = false
          break
        end
        @candidates << snapshot.freeze
      end
      release_snapshot unless @valid
      @candidates.freeze
      @mutex = Mutex.new
    end

    def advance
      return { status: :invalid } unless @valid
      @mutex.synchronize do
        return { status: :closed } if @terminal
        begin
          result = FeedCandidateService.select(@candidates, @session_id, user_id: @user_id, offset: @offset)
        rescue StandardError
          # Side effects may already exist. Never replay this pass implicitly.
          @terminal = true
          release_snapshot
          return { status: :unavailable, stage: :traversal }
        end
        if result[:status] == :traversal_incomplete
          @offset = result[:next_offset]
          @reserved ||= result[:reserved]
          return { status: :traversal_incomplete, reserved: @reserved }
        end
        @terminal = true
        empty = @candidates.empty?
        release_snapshot
        if [:suffix_complete, :exhausted, :temporarily_reserved, :empty].include?(result[:status])
          @reserved ||= result[:reserved] || result[:status] == :temporarily_reserved
          return { status: :snapshot_complete, reserved: @reserved, empty: empty }
        end
        result
      end
    end

    # Process-local disposal only. Waits for an in-flight advance; does not undo
    # issued credentials or release Redis leases belonging to returned content.
    def cancel
      return { status: :invalid } unless @valid
      @mutex.synchronize do
        return { status: :closed } if @terminal
        @terminal = true
        release_snapshot
        { status: :cancelled }
      end
    end

    private

    def copy_media(value, budget, depth = 0)
      budget[:nodes] += 1
      raise ArgumentError if depth > 6 || budget[:nodes] > MAX_PAYLOAD_NODES
      case value
      when String
        budget[:bytes] += value.bytesize
        raise ArgumentError unless value.valid_encoding? && budget[:bytes] <= MAX_PAYLOAD_BYTES
        value.dup.freeze
      when Array
        raise ArgumentError if value.size > MAX_PAYLOAD_NODES - budget[:nodes]
        value.map { |item| copy_media(item, budget, depth + 1) }.freeze
      when Hash
        raise ArgumentError if value.size > MAX_PAYLOAD_NODES - budget[:nodes]
        value.each_with_object({}) do |(key, item), result|
          raise ArgumentError unless key.is_a?(String) || key.is_a?(Symbol)
          copied_key = copy_media(key.to_s, budget, depth + 1)
          raise ArgumentError if result.key?(copied_key)
          result[copied_key] = copy_media(item, budget, depth + 1)
        end.freeze
      when Integer, TrueClass, FalseClass, NilClass then value
      when Float
        raise ArgumentError unless value.finite?
        value
      else raise ArgumentError
      end
    end

    def release_snapshot
      @candidates = [].freeze
      @session_id = nil
      @user_id = nil
    end
  end
end