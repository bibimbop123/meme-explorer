# frozen_string_literal: true

require 'rotp'
require 'rqrcode'

# Two-Factor Authentication Service
# Provides TOTP-based 2FA for admin accounts
class TwoFactorAuthService
  class << self
    # Generate a new 2FA secret for a user
    def generate_secret(username)
      ROTP::Base32.random_base32
    end

    # Generate QR code for 2FA setup
    def generate_qr_code(username, secret)
      totp = ROTP::TOTP.new(secret, issuer: 'Meme Explorer')
      provisioning_uri = totp.provisioning_uri(username)
      
      qrcode = RQRCode::QRCode.new(provisioning_uri)
      qrcode.as_png(size: 300).to_s
    end

    # Verify a 2FA token
    def verify_token(secret, token, drift: 30)
      totp = ROTP::TOTP.new(secret)
      totp.verify(token, drift_behind: drift, drift_ahead: drift)
    end

    # Enable 2FA for a user
    def enable_2fa(user_id, secret)
      db = get_db
      db.execute(
        'UPDATE users SET two_factor_secret = ?, two_factor_enabled = 1, 
         two_factor_enabled_at = ? WHERE id = ?',
        [secret, Time.now, user_id]
      )
      
      log_security_event(user_id, '2fa_enabled')
    end

    # Disable 2FA for a user
    def disable_2fa(user_id)
      db = get_db
      db.execute(
        'UPDATE users SET two_factor_secret = NULL, two_factor_enabled = 0, 
         two_factor_enabled_at = NULL WHERE id = ?',
        [user_id]
      )
      
      log_security_event(user_id, '2fa_disabled')
    end

    # Check if user has 2FA enabled
    def enabled?(user_id)
      db = get_db
      result = db.execute(
        'SELECT two_factor_enabled FROM users WHERE id = ?',
        [user_id]
      ).first
      
      result && result['two_factor_enabled'].to_s =~ /\A(t|true|1)\z/i ? true : false
    end

    # Generate backup codes
    def generate_backup_codes(user_id, count: 10)
      codes = Array.new(count) { SecureRandom.hex(4).upcase }
      
      db = get_db
      db.execute(
        'UPDATE users SET backup_codes = ? WHERE id = ?',
        [codes.join(','), user_id]
      )
      
      log_security_event(user_id, 'backup_codes_generated')
      codes
    end

    # Verify backup code
    def verify_backup_code(user_id, code)
      db = get_db
      result = db.execute(
        'SELECT backup_codes FROM users WHERE id = ?',
        [user_id]
      ).first
      
      return false unless result && result['backup_codes']
      
      codes = result['backup_codes'].split(',')
      if codes.include?(code.upcase)
        # Remove used backup code
        codes.delete(code.upcase)
        db.execute(
          'UPDATE users SET backup_codes = ? WHERE id = ?',
          [codes.join(','), user_id]
        )
        
        log_security_event(user_id, 'backup_code_used')
        true
      else
        false
      end
    end

    private

    def get_db
      DB
    end

    def log_security_event(user_id, event_type)
      db = get_db
      db.execute(
        'INSERT INTO security_audit_log (user_id, event_type, ip_address, user_agent, created_at) 
         VALUES (?, ?, ?, ?, ?)',
        [user_id, event_type, nil, nil, Time.now]
      )
    rescue => e
      # Log but don't fail on audit log errors
      warn "Failed to log security event: #{e.message}"
    end
  end
end
