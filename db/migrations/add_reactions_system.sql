-- Reactions System (fixed: AUTOINCREMENT -> SERIAL, INSERT OR IGNORE -> ON CONFLICT DO NOTHING)
CREATE TABLE IF NOT EXISTS meme_reactions (
  id SERIAL PRIMARY KEY,
  user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  meme_url TEXT NOT NULL,
  reaction_type TEXT NOT NULL,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
  UNIQUE(user_id, meme_url, reaction_type)
);
CREATE INDEX IF NOT EXISTS idx_meme_reactions_meme ON meme_reactions(meme_url, reaction_type);
CREATE INDEX IF NOT EXISTS idx_meme_reactions_user ON meme_reactions(user_id, created_at DESC);

CREATE TABLE IF NOT EXISTS meme_reaction_counts (
  meme_url TEXT PRIMARY KEY,
  fire_count INTEGER DEFAULT 0,
  laugh_count INTEGER DEFAULT 0,
  wow_count INTEGER DEFAULT 0,
  sad_count INTEGER DEFAULT 0,
  total_count INTEGER DEFAULT 0,
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);
