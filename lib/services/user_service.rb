# User Service - Handles user-related operations
class UserService
  def self.create_or_find_from_reddit(reddit_username, reddit_id, reddit_email)
    existing = DB.execute("SELECT id, role FROM users WHERE reddit_id = ?", [reddit_id]).first
    # BUG FIX: `existing["id"]` comes back as a String from the PG driver
    # (raw row values aren't type-cast), but the other branch below
    # (`DB.last_insert_row_id`) returns a real Integer - so this method
    # returned an inconsistent type (String vs Integer) for what every
    # caller treats as the same "user id" concept, depending purely on
    # whether the user already existed. Any caller doing `user_id == other_id`
    # (as this method's own "returns existing user ID" spec does) would
    # silently get a false negative when comparing a fresh int against a
    # cached/looked-up string id.
    return existing["id"].to_i if existing

    # ✅ SECURITY FIX: Set default role when creating user
    DB.last_insert_row_id(
      "INSERT INTO users (reddit_id, reddit_username, reddit_email, role) VALUES (?, ?, ?, 'user')",
      [reddit_id, reddit_username, reddit_email]
    )
  end

  def self.create_email_user(email, password)
    hashed = BCrypt::Password.create(password)
    # ✅ SECURITY FIX: Set default role when creating user
    DB.last_insert_row_id(
      "INSERT INTO users (email, password_hash, role) VALUES (?, ?, 'user')",
      [email, hashed]
    )
  rescue PG::UniqueViolation, StandardError => e
    raise e unless e.message =~ /unique|duplicate/i
    nil
  end

  def self.find_by_email(email)
    # BUG FIX: this never selected `email` itself, only `id`/`password_hash`
    # - any caller reading `user['email']` off the returned row (e.g. to
    # confirm which address a session belongs to) always got nil, even
    # for a real, found user. Added `email` to the select list; the two
    # existing real callers (routes/auth.rb's login flow) only ever read
    # `id`/`password_hash` today, so this is purely additive.
    DB.execute("SELECT id, email, password_hash FROM users WHERE email = ?", [email]).first
  end

  def self.find_by_id(user_id)
    DB.execute("SELECT id, reddit_username, email, role, created_at FROM users WHERE id = ?", [user_id]).first
  end

  def self.verify_password(password, hash)
    BCrypt::Password.new(hash) == password
  end

  def self.get_stats(user_id)
    saved_count = DB.get_first_value("SELECT COUNT(*) FROM saved_memes WHERE user_id = ?", [user_id]).to_i
    liked_count = DB.get_first_value("SELECT COUNT(*) FROM user_meme_stats WHERE user_id = ? AND liked = 1", [user_id]).to_i
    { saved_count: saved_count, liked_count: liked_count }
  end

  def self.is_admin?(user_id)
    return false unless user_id
    user = DB.execute("SELECT role FROM users WHERE id = ?", [user_id]).first
    user && user["role"] == "admin"
  rescue
    false
  end

  def self.save_meme(user_id, meme_url, meme_title, meme_subreddit)
    DB.execute(
      "INSERT INTO saved_memes (user_id, meme_url, meme_title, meme_subreddit) VALUES (?, ?, ?, ?) ON CONFLICT(user_id, meme_url) DO NOTHING",
      [user_id, meme_url, meme_title, meme_subreddit]
    )
  end

  def self.unsave_meme(user_id, meme_url)
    DB.execute("DELETE FROM saved_memes WHERE user_id = ? AND meme_url = ?", [user_id, meme_url])
  end

  def self.is_meme_saved?(user_id, meme_url)
    DB.execute("SELECT id FROM saved_memes WHERE user_id = ? AND meme_url = ?", [user_id, meme_url]).first
  end

  def self.get_saved_memes(user_id, page = 1, limit = 10)
    offset = (page - 1) * limit
    DB.execute(
      "SELECT id, meme_url, meme_title, meme_subreddit, saved_at FROM saved_memes WHERE user_id = ? ORDER BY saved_at DESC LIMIT ? OFFSET ?",
      [user_id, limit, offset]
    )
  end

  def self.get_saved_memes_count(user_id)
    DB.get_first_value("SELECT COUNT(*) FROM saved_memes WHERE user_id = ?", [user_id]).to_i
  end

  def self.get_liked_memes(user_id, limit = 50)
    DB.execute(
      "SELECT meme_url, liked_at FROM user_meme_stats WHERE user_id = ? AND liked = 1 ORDER BY liked_at DESC LIMIT ?",
      [user_id, limit]
    )
  end
end
