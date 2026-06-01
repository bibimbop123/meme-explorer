-- ============================================
-- PHASE 4: USER COLLECTIONS
-- ============================================
-- Allows users to create and share personal meme collections
-- Part of Social Validation (90 → 92/100 satisfaction)

-- User-created collections
CREATE TABLE IF NOT EXISTS user_collections (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  user_id INTEGER NOT NULL,
  name VARCHAR(255) NOT NULL,
  description TEXT,
  slug VARCHAR(255) NOT NULL UNIQUE,
  is_public BOOLEAN DEFAULT 1,
  meme_count INTEGER DEFAULT 0,
  total_likes INTEGER DEFAULT 0,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
);

-- Collection items (memes in collections)
CREATE TABLE IF NOT EXISTS collection_items (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  collection_id INTEGER NOT NULL,
  meme_url VARCHAR(500) NOT NULL,
  position INTEGER DEFAULT 0,
  note TEXT,
  added_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (collection_id) REFERENCES user_collections(id) ON DELETE CASCADE
);

-- Collection followers
CREATE TABLE IF NOT EXISTS collection_followers (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  collection_id INTEGER NOT NULL,
  user_id INTEGER NOT NULL,
  followed_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (collection_id) REFERENCES user_collections(id) ON DELETE CASCADE,
  FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
  UNIQUE(collection_id, user_id)
);

-- Collection likes/favorites
CREATE TABLE IF NOT EXISTS collection_likes (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  collection_id INTEGER NOT NULL,
  user_id INTEGER NOT NULL,
  liked_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (collection_id) REFERENCES user_collections(id) ON DELETE CASCADE,
  FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
  UNIQUE(collection_id, user_id)
);

-- Indexes for performance (create after ensuring tables exist)
CREATE INDEX IF NOT EXISTS idx_user_collections_user ON user_collections(user_id);
-- Note: is_public is a BOOLEAN which SQLite stores as INTEGER, so index should work
CREATE INDEX IF NOT EXISTS idx_user_collections_slug ON user_collections(slug);
CREATE INDEX IF NOT EXISTS idx_collection_items_collection ON collection_items(collection_id);
CREATE INDEX IF NOT EXISTS idx_collection_items_position ON collection_items(collection_id, position);
CREATE INDEX IF NOT EXISTS idx_collection_followers_collection ON collection_followers(collection_id);
CREATE INDEX IF NOT EXISTS idx_collection_followers_user ON collection_followers(user_id);
CREATE INDEX IF NOT EXISTS idx_collection_likes_collection ON collection_likes(collection_id);
CREATE INDEX IF NOT EXISTS idx_collection_likes_user ON collection_likes(user_id);
