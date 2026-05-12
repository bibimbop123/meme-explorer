# Image Health Service
# Tracks broken images and manages blacklist to prevent serving broken content
# Senior Engineer Pattern: Prevention over cure - stop broken content at source

require 'net/http'
require 'uri'
require 'timeout'

class ImageHealthService
  # Blacklist thresholds
  TEMP_BLACKLIST_FAILURES = 1    # 1 failure = temporary blacklist
  PERM_BLACKLIST_FAILURES = 3    # 3+ failures = permanent blacklist
  TEMP_BLACKLIST_DURATION = 3600 # 1 hour in seconds
  PERM_BLACKLIST_DURATION = 604800 # 7 days in seconds
  
  class << self
    # Check if URL is blacklisted
    # @param url [String] URL to check
    # @return [Boolean] true if blacklisted
    def blacklisted?(url)
      return false if url.nil? || url.empty?
      return false if url.start_with?('/') # Local files never blacklisted
      
      begin
        result = DB.execute(
          "SELECT is_blacklisted, blacklisted_until FROM broken_images WHERE url = ? LIMIT 1",
          [url]
        ).first
        
        return false unless result
        
        is_blacklisted = result[0] == 1 || result[0] == true
        blacklisted_until = result[1]
        
        # Not blacklisted
        return false unless is_blacklisted
        
        # Permanent blacklist (NULL expiration)
        return true if blacklisted_until.nil?
        
        # Temporary blacklist - check if expired
        expiration = Time.parse(blacklisted_until) rescue nil
        if expiration && Time.now < expiration
          true # Still blacklisted
        else
          # Blacklist expired - remove it
          unblacklist(url)
          false
        end
      rescue => e
        AppLogger.warn("Error checking blacklist for #{url}: #{e.message}")
        false # Assume not blacklisted on error
      end
    end
    
    # Record a validation failure
    # @param url [String] URL that failed
    # @param reason [String] Failure reason
    # @param status_code [Integer] HTTP status code (optional)
    # @param duration_ms [Integer] Validation duration in ms (optional)
    def record_failure(url, reason:, status_code: nil, duration_ms: nil)
      return if url.nil? || url.empty?
      return if url.start_with?('/') # Don't track local files
      
      begin
        # Check if URL exists
        existing = DB.execute(
          "SELECT failure_count FROM broken_images WHERE url = ? LIMIT 1",
          [url]
        ).first
        
        if existing
          # Update existing record
          new_count = existing[0] + 1
          
          DB.execute(
            "UPDATE broken_images 
             SET failure_count = ?,
                 last_failed_at = CURRENT_TIMESTAMP,
                 failure_reason = ?,
                 http_status_code = ?,
                 last_check_duration_ms = ?,
                 is_blacklisted = ?,
                 blacklisted_until = ?
             WHERE url = ?",
            [
              new_count,
              reason,
              status_code,
              duration_ms,
              should_blacklist?(new_count),
              blacklist_expiration(new_count),
              url
            ]
          )
          
          AppLogger.info("🚫 [IMAGE HEALTH] Updated failure: #{url} (count: #{new_count}, blacklisted: #{should_blacklist?(new_count)})")
        else
          # Insert new record
          DB.execute(
            "INSERT INTO broken_images 
             (url, failure_count, failure_reason, http_status_code, last_check_duration_ms, is_blacklisted, blacklisted_until)
             VALUES (?, 1, ?, ?, ?, ?, ?)",
            [
              url,
              reason,
              status_code,
              duration_ms,
              should_blacklist?(1),
              blacklist_expiration(1)
            ]
          )
          
          AppLogger.info("🚫 [IMAGE HEALTH] New failure: #{url} (blacklisted: #{should_blacklist?(1)})")
        end
      rescue => e
        AppLogger.error("Error recording failure for #{url}: #{e.message}")
      end
    end
    
    # Record a successful validation (clears blacklist)
    # @param url [String] URL that succeeded
    def record_success(url)
      return if url.nil? || url.empty?
      return if url.start_with?('/') # Don't track local files
      
      begin
        # Remove from broken_images if exists
        DB.execute("DELETE FROM broken_images WHERE url = ?", [url])
        AppLogger.debug("✅ [IMAGE HEALTH] Cleared failures for: #{url}")
      rescue => e
        AppLogger.warn("Error recording success for #{url}: #{e.message}")
      end
    end
    
    # Filter out blacklisted URLs from meme array
    # @param memes [Array<Hash>] Array of meme hashes
    # @return [Array<Hash>] Filtered array
    def filter_blacklisted(memes)
      return [] if memes.nil? || memes.empty?
      
      memes.reject do |meme|
        url = meme["url"] || meme["file"]
        blacklisted?(url)
      end
    end
    
    # Get health statistics
    # @return [Hash] Statistics about broken images
    def stats
      begin
        total = DB.execute("SELECT COUNT(*) FROM broken_images").first[0]
        blacklisted = DB.execute("SELECT COUNT(*) FROM broken_images WHERE is_blacklisted = 1").first[0]
        temp_blacklisted = DB.execute(
          "SELECT COUNT(*) FROM broken_images WHERE is_blacklisted = 1 AND blacklisted_until IS NOT NULL"
        ).first[0]
        perm_blacklisted = DB.execute(
          "SELECT COUNT(*) FROM broken_images WHERE is_blacklisted = 1 AND blacklisted_until IS NULL"
        ).first[0]
        
        {
          total_tracked: total,
          blacklisted: blacklisted,
          temp_blacklisted: temp_blacklisted,
          perm_blacklisted: perm_blacklisted,
          not_blacklisted: total - blacklisted
        }
      rescue => e
        AppLogger.error("Error getting health stats: #{e.message}")
        {}
      end
    end
    
    # Clean up old records (older than 30 days and not blacklisted)
    def cleanup_old_records
      begin
        deleted = DB.execute(
          "DELETE FROM broken_images 
           WHERE is_blacklisted = 0 
           AND last_failed_at < datetime('now', '-30 days')"
        )
        
        AppLogger.info("🧹 [IMAGE HEALTH] Cleaned up old records") if deleted
        deleted
      rescue => e
        AppLogger.error("Error cleaning up broken_images: #{e.message}")
        0
      end
    end
    
    private
    
    # Determine if URL should be blacklisted based on failure count
    def should_blacklist?(failure_count)
      failure_count >= TEMP_BLACKLIST_FAILURES
    end
    
    # Calculate blacklist expiration timestamp
    def blacklist_expiration(failure_count)
      if failure_count >= PERM_BLACKLIST_FAILURES
        nil # Permanent blacklist
      else
        (Time.now + TEMP_BLACKLIST_DURATION).iso8601 # Temporary blacklist
      end
    end
    
    # Remove blacklist from URL
    def unblacklist(url)
      begin
        DB.execute(
          "UPDATE broken_images SET is_blacklisted = 0, blacklisted_until = NULL WHERE url = ?",
          [url]
        )
        AppLogger.info("✅ [IMAGE HEALTH] Unblacklisted: #{url}")
      rescue => e
        AppLogger.warn("Error unblacklisting #{url}: #{e.message}")
      end
    end
  end
end

# Usage Examples:
#
# # Check if URL is blacklisted before using
# unless ImageHealthService.blacklisted?(url)
#   # Use the meme
# end
#
# # Record a validation failure
# ImageHealthService.record_failure(url, reason: "404 Not Found", status_code: 404, duration_ms: 150)
#
# # Record a successful validation (clears blacklist)
# ImageHealthService.record_success(url)
#
# # Filter blacklisted memes from array
# clean_memes = ImageHealthService.filter_blacklisted(all_memes)
#
# # Get statistics
# stats = ImageHealthService.stats
# # => { total_tracked: 45, blacklisted: 12, temp_blacklisted: 5, perm_blacklisted: 7, not_blacklisted: 33 }
#
# # Clean up old records (run in background job)
# ImageHealthService.cleanup_old_records
