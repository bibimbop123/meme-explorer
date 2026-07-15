# frozen_string_literal: true

require 'sidekiq'

# Worker for asynchronous meme statistics writes
# Prevents slow DB writes from blocking HTTP requests
class MemeStatsWriter
  include Sidekiq::Worker
  sidekiq_options queue: :default, retry: 3
  
  def perform(meme_identifier, title, subreddit, user_id = nil)
    return unless defined?(MemeExplorer::App::DB)
    
    # Update meme stats
    MemeExplorer::App::DB.execute(
      "INSERT INTO meme_stats (url, title, subreddit, views, likes) 
       VALUES (?, ?, ?, 1, 0) 
       ON CONFLICT(url) DO UPDATE SET 
       views = meme_stats.views + 1, 
       updated_at = CURRENT_TIMESTAMP",
      [meme_identifier, title, subreddit]
    )
    
    # Update user exposure if user_id provided
    if user_id
      MemeExplorer::App::DB.execute(
        "INSERT INTO user_meme_exposure (user_id, meme_url, shown_count) 
         VALUES (?, ?, 1) 
         ON CONFLICT(user_id, meme_url) DO UPDATE SET 
         shown_count = shown_count + 1, 
         last_shown = CURRENT_TIMESTAMP",
        [user_id, meme_identifier]
      )
    end
  rescue => e
    AppLogger.error("MemeStatsWriter error", error: e.message, meme: meme_identifier)
    raise # Let Sidekiq handle retry
  end
end
