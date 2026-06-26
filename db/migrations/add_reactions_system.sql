-- Add Reactions System (v2)

CREATE TABLE IF NOT EXISTS meme_reactions (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  meme_id INTEGER NOT NULL,
  user_id INTEGER NOT NULL,
  reaction_type TEXT NOT NULL, -- 'laugh', 'wow', 'cry', 'fire', 'dead'
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (meme_id) REFERENCES memes(id) ON DELETE CASCADE,
  FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
  UNIQUE(meme_id, user_id, reaction_type)
);

CREATE INDEX idx_meme_reactions_meme ON meme_reactions(meme_id);
CREATE INDEX idx_meme_reactions_user ON meme_reactions(user_id);
CREATE INDEX idx_meme_reactions_type ON meme_reactions(reaction_type);
CREATE INDEX idx_meme_reactions_created ON meme_reactions(created_at);

-- Add reaction counts to memes table
ALTER TABLE memes ADD COLUMN reaction_laugh INTEGER DEFAULT 0;
ALTER TABLE memes ADD COLUMN reaction_wow INTEGER DEFAULT 0;
ALTER TABLE memes ADD COLUMN reaction_cry INTEGER DEFAULT 0;
ALTER TABLE memes ADD COLUMN reaction_fire INTEGER DEFAULT 0;
ALTER TABLE memes ADD COLUMN reaction_dead INTEGER DEFAULT 0;
