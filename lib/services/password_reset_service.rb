# frozen_string_literal: true

require 'securerandom'
require 'digest'
require 'bcrypt'

# PasswordResetService - secure, provider-agnostic password recovery.
#
# Design (per docs/REMAINING_WORK_EXECUTION_ROADMAP.md Stage 5):
# - Only SHA-256 digests of tokens are stored; the raw token appears only
#   in the emailed URL and is never logged.
# - Tokens expire after TOKEN_TTL and are single-use; consumption is atomic
#   (UPDATE ... WHERE used_at IS NULL RETURNING) so concurrent redemptions
#   cannot both succeed.
# - Requesting a new token invalidates that user's previous unused tokens.
# - Request rate is bounded per account (MAX_TOKENS_PER_HOUR); responses
#   are always non-enumerating (identical for known and unknown emails).
#
# Known limitation: existing sessions on OTHER devices are not revoked
# after a reset (rack-session has no per-user session index). The user is
# asked to log in again on the current device. Documented in ROADMAP.
class PasswordResetService
  TOKEN_TTL = 1800 # 30 minutes
  MAX_TOKENS_PER_HOUR = 3

  class << self
    def ensure_schema!
      return if @schema_ready
      DB_POOL.with do |conn|
        conn.exec(<<~SQL)
          CREATE TABLE IF NOT EXISTS password_reset_tokens (
            id SERIAL PRIMARY KEY,
            user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
            token_digest VARCHAR(64) UNIQUE NOT NULL,
            expires_at TIMESTAMPTZ NOT NULL,
            used_at TIMESTAMPTZ,
            created_ip VARCHAR(64),
            created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
          );
          CREATE INDEX IF NOT EXISTS password_reset_tokens_user_created
            ON password_reset_tokens(user_id, created_at);
        SQL
      end
      @schema_ready = true
    rescue PG::Error => e
      AppLogger.error("[PASSWORD RESET] schema ensure failed: #{e.message}") if defined?(AppLogger)
      raise
    end

    # Always returns { success: true } to callers - account existence must
    # never leak. Other keys are internal only (specs/logging), never
    # serialized into the public response.
    def request_reset(email:, ip: nil)
      ensure_schema!
      user = UserService.find_by_email(email)
      unless user && user['id']
        AppLogger.info('[PASSWORD RESET] request for unknown account') if defined?(AppLogger)
        return { success: true, sent: false }
      end

      user_id = user['id'].to_i
      recent = DB.get_first_value(
        "SELECT COUNT(*) FROM password_reset_tokens WHERE user_id = ? AND created_at > CURRENT_TIMESTAMP - INTERVAL '1 hour'",
        [user_id]
      ).to_i
      if recent >= MAX_TOKENS_PER_HOUR
        AppLogger.warn('[PASSWORD RESET] hourly request cap reached', user_id: user_id) if defined?(AppLogger)
        return { success: true, sent: false, rate_limited: true }
      end

      token = SecureRandom.urlsafe_base64(32)
      DB.execute(
        "UPDATE password_reset_tokens SET used_at = CURRENT_TIMESTAMP WHERE user_id = ? AND used_at IS NULL",
        [user_id]
      )
      DB.execute(
        "INSERT INTO password_reset_tokens (user_id, token_digest, expires_at, created_ip) VALUES (?, ?, CURRENT_TIMESTAMP + INTERVAL '30 minutes', ?)",
        [user_id, digest(token), ip.to_s[0, 64]]
      )

      Mailer.deliver(
        to: email,
        subject: 'Reset your Meme Explorer password',
        text: reset_email_text(token)
      )
      { success: true, sent: true }
    rescue Mailer::DeliveryError => e
      AppLogger.warn("[PASSWORD RESET] delivery failed: #{e.message}") if defined?(AppLogger)
      { success: true, sent: false, delivery_failed: true }
    end

    # :unknown | :used | :expired | :valid | :malformed | :unavailable
    def token_state(token)
      return :malformed unless token.is_a?(String) && token.length.between?(20, 128)
      row = DB.execute(
        'SELECT id, used_at, expires_at FROM password_reset_tokens WHERE token_digest = ?',
        [digest(token)]
      ).first
      return :unknown unless row
      return :used if row['used_at']
      return :expired if Time.parse(row['expires_at'].to_s) < Time.now
      :valid
    rescue PG::Error
      :unavailable
    end

    # Atomically consume the token and set the new password. Concurrent
    # redemptions cannot both succeed (UPDATE ... WHERE used_at IS NULL).
    def consume(token:, new_password:, db: nil)
      ensure_schema!
      db ||= defined?(DB) ? ::DB : nil
      return { success: false, reason: :unavailable } unless db

      hashed = BCrypt::Password.create(new_password)
      consumed = db.execute(
        'UPDATE password_reset_tokens SET used_at = CURRENT_TIMESTAMP WHERE token_digest = ? AND used_at IS NULL AND expires_at > CURRENT_TIMESTAMP RETURNING user_id',
        [digest(token)]
      ).first
      return { success: false, reason: :invalid_token } unless consumed

      db.execute('UPDATE users SET password_hash = ?, updated_at = CURRENT_TIMESTAMP WHERE id = ?', [hashed, consumed['user_id'].to_i])
      { success: true, user_id: consumed['user_id'].to_i }
    rescue PG::Error => e
      AppLogger.error("[PASSWORD RESET] consume failed: #{e.message}") if defined?(AppLogger)
      { success: false, reason: :unavailable }
    end

    def digest(token)
      Digest::SHA256.hexdigest(token.to_s)
    end

    private

    def reset_email_text(token)
      base = ENV['PUBLIC_ORIGIN'].to_s.strip
      base = 'http://localhost:8080' if base.empty?
      url = "#{base}/password/reset/#{token}"
      <<~TEXT
        Someone requested a password reset for this Meme Explorer account.

        Reset your password (link expires in 30 minutes, one use only):
        #{url}

        If you did not request this, ignore this email - your password stays unchanged.
      TEXT
    end
  end
end

