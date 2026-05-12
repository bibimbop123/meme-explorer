# User Service - Handles user-related operations
class UserService
  def self.create_or_find_from_reddit(reddit_username, reddit_id, reddit_email)
    # Check if using Sequel (PostgreSQL) or SQLite3
    if defined?(Sequel) && DB.is_a?(Sequel::Database)
      # Sequel/PostgreSQL
      existing = DB[:users].where(reddit_id: reddit_id).select(:id).first
      return existing[:id] if existing

      DB[:users].insert(
        reddit_id: reddit_id,
        reddit_username: reddit_username,
        reddit_email: reddit_email
      )
    else
      # SQLite3
      existing = DB.execute("SELECT id FROM users WHERE reddit_id = ?", [reddit_id]).first
      return existing["id"] if existing

      DB.execute(
        "INSERT INTO users (reddit_id, reddit_username, reddit_email) VALUES (?, ?, ?)",
        [reddit_id, reddit_username, reddit_email]
      )
      DB.last_insert_row_id
    end
  end

  def self.create_email_user(email, password)
    hashed = BCrypt::Password.create(password)
    
    if defined?(Sequel) && DB.is_a?(Sequel::Database)
      # Sequel/PostgreSQL
      begin
        DB[:users].insert(
          email: email,
          password_hash: hashed
        )
      rescue Sequel::UniqueConstraintViolation
        nil
      end
    else
      # SQLite3
      DB.execute(
        "INSERT INTO users (email, password_hash) VALUES (?, ?)",
        [email, hashed]
      )
      DB.last_insert_row_id
    end
  rescue SQLite3::ConstraintException
    nil
  end

  def self.find_by_email(email)
    if defined?(Sequel) && DB.is_a?(Sequel::Database)
      # Sequel/PostgreSQL - returns hash with symbol keys
      result = DB[:users].where(email: email).select(:id, :password_hash).first
      result ? { "id" => result[:id], "password_hash" => result[:password_hash] } : nil
    else
      # SQLite3 - returns hash with string keys
      DB.execute("SELECT id, password_hash FROM users WHERE email = ?", [email]).first
    end
  end

  def self.find_by_id(user_id)
    if defined?(Sequel) && DB.is_a?(Sequel::Database)
      # Sequel/PostgreSQL - returns hash with symbol keys
      result = DB[:users].where(id: user_id).select(:id, :reddit_username, :email, :created_at).first
      if result
        {
          "id" => result[:id],
          "reddit_username" => result[:reddit_username],
          "email" => result[:email],
          "created_at" => result[:created_at]
        }
      else
        nil
      end
    else
      # SQLite3 - returns hash with string keys
      DB.execute("SELECT id, reddit_username, email, created_at FROM users WHERE id = ?", [user_id]).first
    end
  end

  def self.verify_password(password, hash)
    BCrypt::Password.new(hash) == password
  end

  def self.get_stats(user_id)
    if defined?(Sequel) && DB.is_a?(Sequel::Database)
      # Sequel/PostgreSQL
      saved_count = DB[:saved_memes].where(user_id: user_id).count
      liked_count = DB[:user_meme_stats].where(user_id: user_id, liked: 1).count
    else
      # SQLite3
      saved_count = DB.get_first_value("SELECT COUNT(*) FROM saved_memes WHERE user_id = ?", [user_id]).to_i
      liked_count = DB.get_first_value("SELECT COUNT(*) FROM user_meme_stats WHERE user_id = ? AND liked = 1", [user_id]).to_i
    end
    { saved_count: saved_count, liked_count: liked_count }
  end

  def self.is_admin?(user_id)
    return false unless user_id
    begin
      if defined?(Sequel) && DB.is_a?(Sequel::Database)
        # Sequel/PostgreSQL
        user = DB[:users].where(id: user_id).select(:role).first
        user && user[:role] == "admin"
      else
        # SQLite3
        user = DB.execute("SELECT role FROM users WHERE id = ?", [user_id]).first
        user && user["role"] == "admin"
      end
    rescue
      false
    end
  end

  def self.save_meme(user_id, meme_url, meme_title, meme_subreddit)
    if defined?(Sequel) && DB.is_a?(Sequel::Database)
      # Sequel/PostgreSQL - use insert_conflict(:ignore)
      DB[:saved_memes].insert_conflict(:ignore).insert(
        user_id: user_id,
        meme_url: meme_url,
        meme_title: meme_title,
        meme_subreddit: meme_subreddit
      )
    else
      # SQLite3
      DB.execute(
        "INSERT OR IGNORE INTO saved_memes (user_id, meme_url, meme_title, meme_subreddit) VALUES (?, ?, ?, ?)",
        [user_id, meme_url, meme_title, meme_subreddit]
      )
    end
  end

  def self.unsave_meme(user_id, meme_url)
    if defined?(Sequel) && DB.is_a?(Sequel::Database)
      # Sequel/PostgreSQL
      DB[:saved_memes].where(user_id: user_id, meme_url: meme_url).delete
    else
      # SQLite3
      DB.execute("DELETE FROM saved_memes WHERE user_id = ? AND meme_url = ?", [user_id, meme_url])
    end
  end

  def self.is_meme_saved?(user_id, meme_url)
    if defined?(Sequel) && DB.is_a?(Sequel::Database)
      # Sequel/PostgreSQL
      DB[:saved_memes].where(user_id: user_id, meme_url: meme_url).select(:id).first
    else
      # SQLite3
      DB.execute("SELECT id FROM saved_memes WHERE user_id = ? AND meme_url = ?", [user_id, meme_url]).first
    end
  end

  def self.get_saved_memes(user_id, page = 1, limit = 10)
    offset = (page - 1) * limit
    
    if defined?(Sequel) && DB.is_a?(Sequel::Database)
      # Sequel/PostgreSQL - returns array of hashes with symbol keys
      results = DB[:saved_memes]
        .where(user_id: user_id)
        .select(:id, :meme_url, :meme_title, :meme_subreddit, :saved_at)
        .order(Sequel.desc(:saved_at))
        .limit(limit)
        .offset(offset)
        .all
      
      # Convert symbol keys to string keys for consistency
      results.map do |row|
        {
          "id" => row[:id],
          "meme_url" => row[:meme_url],
          "meme_title" => row[:meme_title],
          "meme_subreddit" => row[:meme_subreddit],
          "saved_at" => row[:saved_at]
        }
      end
    else
      # SQLite3 - returns array of hashes with string keys
      DB.execute(
        "SELECT id, meme_url, meme_title, meme_subreddit, saved_at FROM saved_memes WHERE user_id = ? ORDER BY saved_at DESC LIMIT ? OFFSET ?",
        [user_id, limit, offset]
      )
    end
  end

  def self.get_saved_memes_count(user_id)
    if defined?(Sequel) && DB.is_a?(Sequel::Database)
      # Sequel/PostgreSQL
      DB[:saved_memes].where(user_id: user_id).count
    else
      # SQLite3
      DB.get_first_value("SELECT COUNT(*) FROM saved_memes WHERE user_id = ?", [user_id]) || 0
    end
  end

  def self.get_liked_memes(user_id, limit = 50)
    if defined?(Sequel) && DB.is_a?(Sequel::Database)
      # Sequel/PostgreSQL - returns array of hashes with symbol keys
      results = DB[:user_meme_stats]
        .where(user_id: user_id, liked: 1)
        .select(:meme_url, :liked_at)
        .order(Sequel.desc(:liked_at))
        .limit(limit)
        .all
      
      # Convert symbol keys to string keys for consistency
      results.map do |row|
        {
          "meme_url" => row[:meme_url],
          "liked_at" => row[:liked_at]
        }
      end
    else
      # SQLite3 - returns array of hashes with string keys
      DB.execute(
        "SELECT meme_url, liked_at FROM user_meme_stats WHERE user_id = ? AND liked = 1 ORDER BY liked_at DESC LIMIT ?",
        [user_id, limit]
      )
    end
  end
end
