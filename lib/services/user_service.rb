# User Service - Handles user-related operations
class UserService
  def self.create_or_find_from_reddit(reddit_username, reddit_id, reddit_email)
    existing = DB.execute("SELECT id FROM users WHERE reddit_id = ?", [reddit_id]).first
    return existing["id"] if existing

    DB.execute(
      "INSERT INTO users (reddit_id, reddit_username, reddit_email) VALUES (?, ?, ?)",
      [reddit_id, reddit_username, reddit_email]
    )
    DB.last_insert_row_id
  end

  def self.create_email_user(email, password)
    hashed = BCrypt::Password.create(password)
    DB.execute(
      "INSERT INTO users (email, password_hash) VALUES (?, ?)",
      [email, hashed]
    )
    DB.last_insert_row_id
  rescue SQLite3::ConstraintException
    nil
  end

  def self.find_by_email(email)
    DB.execute("SELECT id, password_hash FROM users WHERE email = ?", [email]).first
  end

  def self.find_by_id(user_id)
    DB.execute("SELECT id, reddit_username, email, created_at FROM users WHERE id = ?", [user_id]).first
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
    begin
      user = DB.execute("SELECT role FROM users WHERE id = ?", [user_id]).first
      user && user["role"] == "admin"
    rescue
      false
    end
  end

  def self.save_meme(user_id, meme_url, meme_title, meme_subreddit)
    DB.execute(
      "INSERT OR IGNORE INTO saved_memes (user_id, meme_url, meme_title, meme_subreddit) VALUES (?, ?, ?, ?)",
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
    DB.get_first_value("SELECT COUNT(*) FROM saved_memes WHERE user_id = ?", [user_id]) || 0
  end

  def self.get_liked_memes(user_id, limit = 50)
    DB.execute(
      "SELECT meme_url, liked_at FROM user_meme_stats WHERE user_id = ? AND liked = 1 ORDER BY liked_at DESC LIMIT ?",
      [user_id, limit]
    )
  end
end
