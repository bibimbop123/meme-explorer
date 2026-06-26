# Database Transaction Wrapper
# P1 Fix: Ensure atomic multi-step operations

module TransactionWrapper
  # Execute block within a database transaction
  def with_transaction(&block)
    DB_POOL.with do |conn|
      begin
        conn.exec("BEGIN")
        result = block.call(conn)
        conn.exec("COMMIT")
        result
      rescue => e
        conn.exec("ROLLBACK")
        AppLogger.error("Transaction rolled back", error: e.message, backtrace: e.backtrace.first(5))
        raise
      end
    end
  end
  
  # Execute multiple SQL statements atomically
  def execute_in_transaction(statements)
    with_transaction do |conn|
      statements.each do |sql, params|
        if params
          conn.exec_params(sql, params)
        else
          conn.exec(sql)
        end
      end
    end
  end
  
  # Atomic like operation (P1 Fix for race conditions)
  def atomic_like_meme(meme_url, user_id, increment: true)
    with_transaction do |conn|
      # Insert or update meme_stats
      conn.exec_params(
        "INSERT INTO meme_stats (url, title, subreddit, views, likes) 
         VALUES ($1, 'Unknown', 'unknown', 0, #{increment ? 1 : 0}) 
         ON CONFLICT(url) DO UPDATE SET 
           likes = meme_stats.likes + #{increment ? 1 : -1},
           updated_at = CURRENT_TIMESTAMP",
        [meme_url]
      )
      
      # Update user_meme_stats
      conn.exec_params(
        "INSERT INTO user_meme_stats (user_id, meme_url, liked) 
         VALUES ($1, $2, $3) 
         ON CONFLICT(user_id, meme_url) DO UPDATE SET 
           liked = $3, 
           updated_at = CURRENT_TIMESTAMP",
        [user_id, meme_url, increment ? 1 : 0]
      )
    end
  end
  
  # Atomic save operation
  def atomic_save_meme(user_id, meme_url, meme_title, subreddit)
    with_transaction do |conn|
      # Insert into saved_memes
      result = conn.exec_params(
        "INSERT INTO saved_memes (user_id, meme_url, title, subreddit, saved_at) 
         VALUES ($1, $2, $3, $4, CURRENT_TIMESTAMP) 
         ON CONFLICT(user_id, meme_url) DO NOTHING 
         RETURNING id",
        [user_id, meme_url, meme_title, subreddit]
      )
      
      # Update meme_stats if insert was successful
      if result.ntuples > 0
        conn.exec_params(
          "INSERT INTO meme_stats (url, title, subreddit, views, likes) 
           VALUES ($1, $2, $3, 0, 0) 
           ON CONFLICT(url) DO UPDATE SET 
             title = COALESCE(NULLIF(meme_stats.title, 'Unknown'), $2),
             subreddit = COALESCE(NULLIF(meme_stats.subreddit, 'unknown'), $3)",
          [meme_url, meme_title, subreddit]
        )
      end
      
      result.ntuples > 0
    end
  end
end
