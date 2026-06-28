# frozen_string_literal: true

require 'sidekiq'

# ============================================
# PHASE 5: DAILY DIGEST WORKER
# ============================================
# Sidekiq worker for automated daily digest emails
# Runs every morning to send personalized digests

class DailyDigestWorker
  include Sidekiq::Worker
  
  sidekiq_options queue: :mailers, retry: 3
  
  def perform
    puts "#{Time.now}: Starting daily digest send..."

    digest_service = DailyDigestService.new(DB)
    sent_count = digest_service.send_all_digests

    puts "#{Time.now}: Sent #{sent_count} digests"

    sent_count
  rescue => e
    puts "Error in DailyDigestWorker: #{e.message}"
    puts e.backtrace.join("\n")
    raise e
  end
end
