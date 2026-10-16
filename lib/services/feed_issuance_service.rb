# frozen_string_literal: true
require_relative 'feed_reservation_service'
require_relative 'feed_acknowledgement_store'

module MemeExplorer
  # Unused orchestration prerequisite, NOT atomic selection/credential issuance.
  # A crash or ambiguous Redis response is bounded by the original key TTLs.
  class FeedIssuanceService
    def self.issue(session_id, content, title: nil, subreddit: nil, user_id: nil)
      unless FeedAcknowledgementStore.valid_issuance_context?(title: title, subreddit: subreddit, user_id: user_id)
        return { status: :invalid, stage: :credential }
      end
      lease = FeedReservationService.acquire_unseen(session_id, content)
      return lease.merge(stage: :reservation) unless lease[:status] == :reserved

      begin
        impression_id = SecureRandom.hex(32)
        credential = FeedAcknowledgementStore.issue(session_id, content,
          impression_id: impression_id, title: title, subreddit: subreddit,
          user_id: user_id, reservation_token: lease[:token])
        if credential[:status] == :issued
          return { status: :issued, token: credential[:token], impression_id: impression_id }
        end
        credential.merge(stage: :credential)
      rescue StandardError
        { status: :unavailable, stage: :credential }
      ensure
        # Compare-and-delete cannot remove a successor, even after lease expiry.
        # Failed cleanup is bounded by lease TTL, not an unowned retry release.
        unless credential && credential[:status] == :issued
          FeedReservationService.release(session_id, content, lease[:token])
        end
      end
    end
  end
end