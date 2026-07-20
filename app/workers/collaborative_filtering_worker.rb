# Collaborative Filtering Worker - Background Calculations
# Runs periodically to calculate user similarities and refresh recommendations

require 'sidekiq'

class CollaborativeFilteringWorker
  include Sidekiq::Worker
  
  sidekiq_options queue: :low_priority, retry: 3
  
  def perform
    start_time = Time.now
    AppLogger.info("🔄 Starting collaborative filtering calculations...")
    
    # Calculate user similarities
    updated_similarities = calculate_user_similarities
    
    # Refresh collaborative recommendations materialized view
    refresh_recommendations_view
    
    # Clean up expired recommendations
    cleanup_expired_recommendations
    
    duration = (Time.now - start_time).round(2)
    AppLogger.info("✅ Collaborative filtering complete in #{duration}s")
    AppLogger.info("   - Updated #{updated_similarities} user similarities")
  end
  
  private
  
  def calculate_user_similarities
    return 0 unless defined?(DB) && DB
    
    updated = 0
    
    begin
      # Get all users with recent activity
      active_users = DB.execute(
        "SELECT DISTINCT user_id 
         FROM user_interactions 
         WHERE user_id IS NOT NULL
         AND created_at > datetime('now', '-30 days')
         ORDER BY user_id
         LIMIT 500"
      ).map { |r| r['user_id'] }
    AppLogger.info("   Processing #{active_users.size} active users...")
      
      # Calculate pairwise similarities (limit to avoid explosion)
      active_users.each_with_index do |user_a, i|
        # Only calculate with next 10 users (avoid O(n²) explosion)
        active_users[(i+1)...(i+11)].to_a.each do |user_b|
          similarity = calculate_jaccard_similarity(user_a, user_b)
          
          next if similarity < 0.1 # Only store meaningful similarities
          
          # Get common likes count
          common_likes = get_common_likes_count(user_a, user_b)
          
          # Store similarity
          update_similarity(user_a, user_b, similarity, common_likes)
          
          updated += 1
        end
        
        # Limit processing time
        break if updated >= 1000
      end
      
      updated
    rescue => e
    AppLogger.info("❌ User similarity calculation error: #{e.message}")
      0
    end
  end
  
  def update_similarity(user_a, user_b, similarity, common_likes)
    DB.execute(
      "INSERT INTO user_similarity (user_id_a, user_id_b, similarity_score, common_likes, last_calculated)
       VALUES (?, ?, ?, ?, datetime('now'))
       ON CONFLICT (user_id_a, user_id_b)
       DO UPDATE SET
         similarity_score = ?,
         common_likes = ?,
         last_calculated = datetime('now')",
      [user_a, user_b, similarity, common_likes, similarity, common_likes]
    )
  rescue StandardError => e
    AppLogger.warn("update_similarity failed: #{e.message}") if defined?(AppLogger)
  end
  
  def calculate_jaccard_similarity(user_a, user_b)
    # Get liked memes for both users
    likes_a = DB.execute(
      "SELECT DISTINCT meme_id FROM user_interactions 
       WHERE user_id = ? AND interaction_type = 'like'",
      [user_a]
    ).map { |r| r['meme_id'] }
    
    likes_b = DB.execute(
      "SELECT DISTINCT meme_id FROM user_interactions 
       WHERE user_id = ? AND interaction_type = 'like'",
      [user_b]
    ).map { |r| r['meme_id'] }
    
    return 0.0 if likes_a.empty? || likes_b.empty?
    
    # Jaccard similarity: intersection / union
    intersection = (likes_a & likes_b).size
    union = (likes_a | likes_b).size
    
    return 0.0 if union.zero?
    
    (intersection.to_f / union).round(4)
  end
  
  def get_common_likes_count(user_a, user_b)
    # SQLite doesn't support INTERSECT in subqueries the same way
    likes_a = DB.execute(
      "SELECT DISTINCT meme_id FROM user_interactions 
       WHERE user_id = ? AND interaction_type = 'like'",
      [user_a]
    ).map { |r| r['meme_id'] }
    
    likes_b = DB.execute(
      "SELECT DISTINCT meme_id FROM user_interactions 
       WHERE user_id = ? AND interaction_type = 'like'",
      [user_b]
    ).map { |r| r['meme_id'] }
    
    (likes_a & likes_b).size
  rescue
    0
  end
  
  def refresh_recommendations_view
    # PostgreSQL only - skip for SQLite
    AppLogger.info("   ⚠️ Materialized view refresh skipped (SQLite)")
  end
  
  def cleanup_expired_recommendations
    return unless defined?(DB) && DB
    
    begin
      DB.execute(
        "DELETE FROM meme_recommendations WHERE expires_at < datetime('now')"
      )
    AppLogger.info("   ✓ Cleaned up expired recommendations")
    rescue => e
    AppLogger.info("   ⚠️ Cleanup skipped: #{e.message}")
    end
  end
end
