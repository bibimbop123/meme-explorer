# frozen_string_literal: true

# ============================================
# PHASE 4: USER COLLECTIONS SERVICE
# ============================================
# Enables users to create and share personal meme collections
# Part of Social Validation (90 → 92/100 satisfaction)

class UserCollectionsService
  def initialize(db_connection)
    @db = db_connection
  end

  # Create a new collection
  def create_collection(user_id, name, description = '', is_public = true)
    slug = generate_slug(name, user_id)
    
    @db.execute(
      "INSERT INTO user_collections (user_id, name, description, slug, is_public) 
       VALUES (?, ?, ?, ?, ?)",
      [user_id, name, description, slug, is_public ? 1 : 0]
    )
    
    collection_id = @db.last_insert_row_id
    get_collection(collection_id)
  end

  # Get collection by ID or slug
  def get_collection(id_or_slug)
    if id_or_slug.to_s =~ /^\d+$/
      query = "SELECT * FROM user_collections WHERE id = ?"
    else
      query = "SELECT * FROM user_collections WHERE slug = ?"
    end
    
    collection = @db.execute(query, [id_or_slug]).first
    return nil unless collection
    
    # Add metadata
    collection['meme_count'] = get_collection_meme_count(collection['id'])
    collection['follower_count'] = get_collection_follower_count(collection['id'])
    collection['like_count'] = get_collection_like_count(collection['id'])
    collection['owner'] = get_user_info(collection['user_id'])
    
    collection
  end

  # Get collections for a user
  def get_user_collections(user_id, include_private = false)
    query = if include_private
              "SELECT * FROM user_collections WHERE user_id = ? ORDER BY updated_at DESC"
            else
              "SELECT * FROM user_collections WHERE user_id = ? AND is_public = 1 ORDER BY updated_at DESC"
            end
    
    collections = @db.execute(query, [user_id])
    
    collections.map do |collection|
      collection['meme_count'] = get_collection_meme_count(collection['id'])
      collection['follower_count'] = get_collection_follower_count(collection['id'])
      collection['like_count'] = get_collection_like_count(collection['id'])
      collection
    end
  end

  # Get public collections (trending, popular, etc.)
  def get_public_collections(limit = 20, sort_by = 'popular')
    query = case sort_by
            when 'popular'
              "SELECT uc.*, COUNT(cl.id) as like_count 
               FROM user_collections uc 
               LEFT JOIN collection_likes cl ON uc.id = cl.collection_id 
               WHERE uc.is_public = 1 
               GROUP BY uc.id 
               ORDER BY like_count DESC, uc.updated_at DESC 
               LIMIT ?"
            when 'trending'
              "SELECT uc.*, COUNT(cf.id) as follower_count 
               FROM user_collections uc 
               LEFT JOIN collection_followers cf ON uc.id = cf.collection_id 
               WHERE uc.is_public = 1 
               GROUP BY uc.id 
               ORDER BY follower_count DESC, uc.updated_at DESC 
               LIMIT ?"
            when 'newest'
              "SELECT * FROM user_collections 
               WHERE is_public = 1 
               ORDER BY created_at DESC 
               LIMIT ?"
            else
              "SELECT * FROM user_collections 
               WHERE is_public = 1 
               ORDER BY updated_at DESC 
               LIMIT ?"
            end
    
    collections = @db.execute(query, [limit])
    
    collections.map do |collection|
      collection['meme_count'] = get_collection_meme_count(collection['id'])
      collection['follower_count'] = get_collection_follower_count(collection['id'])
      collection['like_count'] = get_collection_like_count(collection['id'])
      collection['owner'] = get_user_info(collection['user_id'])
      collection
    end
  end

  # Add meme to collection
  def add_meme_to_collection(collection_id, meme_url, note = nil)
    # Get current max position
    max_position = @db.execute(
      "SELECT MAX(position) as max_pos FROM collection_items WHERE collection_id = ?",
      [collection_id]
    ).first['max_pos'] || 0
    
    # Insert meme
    @db.execute(
      "INSERT INTO collection_items (collection_id, meme_url, position, note) 
       VALUES (?, ?, ?, ?)",
      [collection_id, meme_url, max_position + 1, note]
    )
    
    # Update collection meme count and timestamp
    update_collection_metadata(collection_id)
    
    true
  end

  # Remove meme from collection
  def remove_meme_from_collection(collection_id, meme_url)
    @db.execute(
      "DELETE FROM collection_items WHERE collection_id = ? AND meme_url = ?",
      [collection_id, meme_url]
    )
    
    update_collection_metadata(collection_id)
    
    true
  end

  # Get memes in a collection
  def get_collection_memes(collection_id, limit = 50)
    @db.execute(
      "SELECT ci.*, ms.* 
       FROM collection_items ci 
       LEFT JOIN meme_stats ms ON ci.meme_url = ms.url 
       WHERE ci.collection_id = ? 
       ORDER BY ci.position ASC 
       LIMIT ?",
      [collection_id, limit]
    )
  end

  # Follow/unfollow collection
  def toggle_follow(collection_id, user_id)
    existing = @db.execute(
      "SELECT id FROM collection_followers WHERE collection_id = ? AND user_id = ?",
      [collection_id, user_id]
    ).first
    
    if existing
      @db.execute(
        "DELETE FROM collection_followers WHERE collection_id = ? AND user_id = ?",
        [collection_id, user_id]
      )
      false # unfollowed
    else
      @db.execute(
        "INSERT INTO collection_followers (collection_id, user_id) VALUES (?, ?)",
        [collection_id, user_id]
      )
      true # followed
    end
  end

  # Like/unlike collection
  def toggle_like(collection_id, user_id)
    existing = @db.execute(
      "SELECT id FROM collection_likes WHERE collection_id = ? AND user_id = ?",
      [collection_id, user_id]
    ).first
    
    if existing
      @db.execute(
        "DELETE FROM collection_likes WHERE collection_id = ? AND user_id = ?",
        [collection_id, user_id]
      )
      false # unliked
    else
      @db.execute(
        "INSERT INTO collection_likes (collection_id, user_id) VALUES (?, ?)",
        [collection_id, user_id]
      )
      true # liked
    end
  end

  # Check if user is following collection
  def is_following?(collection_id, user_id)
    result = @db.execute(
      "SELECT id FROM collection_followers WHERE collection_id = ? AND user_id = ?",
      [collection_id, user_id]
    ).first
    
    !result.nil?
  end

  # Check if user has liked collection
  def has_liked?(collection_id, user_id)
    result = @db.execute(
      "SELECT id FROM collection_likes WHERE collection_id = ? AND user_id = ?",
      [collection_id, user_id]
    ).first
    
    !result.nil?
  end

  # Update collection
  def update_collection(collection_id, name: nil, description: nil, is_public: nil)
    updates = []
    params = []
    
    if name
      updates << "name = ?"
      params << name
      # Update slug if name changes
      user_id = get_collection(collection_id)['user_id']
      new_slug = generate_slug(name, user_id)
      updates << "slug = ?"
      params << new_slug
    end
    
    if description
      updates << "description = ?"
      params << description
    end
    
    if !is_public.nil?
      updates << "is_public = ?"
      params << (is_public ? 1 : 0)
    end
    
    updates << "updated_at = CURRENT_TIMESTAMP"
    
    params << collection_id
    
    @db.execute(
      "UPDATE user_collections SET #{updates.join(', ')} WHERE id = ?",
      params
    )
    
    get_collection(collection_id)
  end

  # Delete collection
  def delete_collection(collection_id)
    @db.execute("DELETE FROM user_collections WHERE id = ?", [collection_id])
    true
  end

  private

  def generate_slug(name, user_id)
    base_slug = name.downcase
                    .gsub(/[^a-z0-9\s-]/, '')
                    .gsub(/\s+/, '-')
                    .gsub(/-+/, '-')
                    .strip
    
    # Add user ID to ensure uniqueness
    slug = "#{base_slug}-#{user_id}-#{Time.now.to_i}"
    
    # Ensure it's unique
    counter = 1
    while collection_exists_with_slug?(slug)
      slug = "#{base_slug}-#{user_id}-#{Time.now.to_i}-#{counter}"
      counter += 1
    end
    
    slug
  end

  def collection_exists_with_slug?(slug)
    result = @db.execute("SELECT id FROM user_collections WHERE slug = ?", [slug]).first
    !result.nil?
  end

  def get_collection_meme_count(collection_id)
    @db.execute(
      "SELECT COUNT(*) as count FROM collection_items WHERE collection_id = ?",
      [collection_id]
    ).first['count']
  end

  def get_collection_follower_count(collection_id)
    @db.execute(
      "SELECT COUNT(*) as count FROM collection_followers WHERE collection_id = ?",
      [collection_id]
    ).first['count']
  end

  def get_collection_like_count(collection_id)
    @db.execute(
      "SELECT COUNT(*) as count FROM collection_likes WHERE collection_id = ?",
      [collection_id]
    ).first['count']
  end

  def update_collection_metadata(collection_id)
    meme_count = get_collection_meme_count(collection_id)
    
    @db.execute(
      "UPDATE user_collections SET meme_count = ?, updated_at = CURRENT_TIMESTAMP WHERE id = ?",
      [meme_count, collection_id]
    )
  end

  def get_user_info(user_id)
    user = @db.execute("SELECT id, username, email FROM users WHERE id = ?", [user_id]).first
    return nil unless user
    
    {
      'id' => user['id'],
      'username' => user['username'] || user['email']&.split('@')&.first || "User#{user['id']}"
    }
  end
end
