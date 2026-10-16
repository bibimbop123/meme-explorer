# frozen_string_literal: true
require_relative 'feed_acknowledgement_store'

module MemeExplorer
  # Unused migration prerequisite. Metadata/user identity must come from trusted
  # server state, never the ACK request body. Call outside an existing transaction:
  # Redis reconciliation must happen only after PostgreSQL has committed.
  class FeedAcknowledgementService
    class InvalidBinding < StandardError; end

    def self.acknowledge(session_id, token, impression_id:, reservation_token: nil,
                         current_user_id: nil)
      valid_id = ->(value) { value.is_a?(String) && value.match?(/\A[a-f0-9]{64}\z/) }
      return { status: :invalid } unless valid_id.call(impression_id) &&
        (reservation_token.nil? || valid_id.call(reservation_token))
      return { status: :invalid } unless FeedAcknowledgementStore.valid_issuance_context?(user_id: current_user_id)
      return { status: :unavailable, stage: :database } if Thread.current[:db_connection]

      binding = FeedAcknowledgementStore.lookup(session_id, token, impression_id: impression_id)
      return { status: binding[:status] } unless binding[:status] == :valid
      return { status: :invalid } if reservation_token && reservation_token != binding[:reservation_token]
      content = binding[:content]
      context = binding[:context]
      title, subreddit = context.values_at('title', 'subreddit')
      user_id = context['user_id'] if context['user_id'] == current_user_id
      recorded = false
      timestamp = nil
      begin
        DB.transaction do
          inserted = DB.execute(
            'INSERT INTO meme_impressions (id, meme_url, session_key) VALUES (?, ?, ?) ON CONFLICT DO NOTHING RETURNING id',
            [impression_id, content, session_id]
          )
          row = DB.execute(
            'SELECT meme_url, session_key, EXTRACT(EPOCH FROM created_at) AS recorded_at, EXTRACT(EPOCH FROM clock_timestamp()) AS database_now FROM meme_impressions WHERE id = ?',
            [impression_id]
          ).first
          raise InvalidBinding unless row && row['meme_url'] == content && row['session_key'] == session_id
          timestamp = Float(row['recorded_at'])
          database_now = Float(row['database_now'])
          unless timestamp.finite? && database_now.finite? && timestamp > 0 &&
            timestamp <= database_now && timestamp > database_now - ViewingHistoryService::HISTORY_TTL
            raise RangeError, 'Unusable persisted impression timestamp'
          end
          unless inserted.empty?
            DB.execute(
              'INSERT INTO meme_stats (url, title, subreddit, views, likes) VALUES (?, ?, ?, 1, 0) ON CONFLICT(url) DO UPDATE SET views = meme_stats.views + 1, updated_at = CURRENT_TIMESTAMP',
              [content, title || 'Unknown', subreddit || 'unknown']
            )
            if user_id
              DB.execute(
                'INSERT INTO user_meme_exposure (user_id, meme_url, shown_count) VALUES (?, ?, 1) ON CONFLICT(user_id, meme_url) DO UPDATE SET shown_count = user_meme_exposure.shown_count + 1, last_shown = CURRENT_TIMESTAMP',
                [user_id, content]
              )
            end
            DB.execute(
              "INSERT INTO meme_activity_log (meme_url, activity_type, user_id, session_id) VALUES (?, 'view', ?, ?)",
              [content, user_id, session_id]
            )
            recorded = true
          end
        end
      rescue InvalidBinding
        return { status: :invalid }
      rescue StandardError
        return { status: :unavailable, stage: :database }
      end

      result = FeedAcknowledgementStore.reconcile(session_id, token, impression_id: impression_id,
        acknowledged_at: timestamp, reservation_token: reservation_token)
      return { status: :acknowledged, recorded: recorded } if result[:status] == :reconciled
      # DB is committed even if the token expired or Redis failed between stages.
      { status: result[:status], stage: :history, recorded: recorded }
    end
  end
end