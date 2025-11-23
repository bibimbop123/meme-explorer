# User model for database abstraction
class User
  attr_reader :id, :email, :password_hash, :reddit_id, :reddit_username, :role

  def initialize(row)
    @id = row['id']
    @email = row['email']
    @password_hash = row['password_hash']
    @reddit_id = row['reddit_id']
    @reddit_username = row['reddit_username']
    @role = row['role'] || 'user'
  end

  # Find user by email
  def self.find_by(email:)
    return nil unless email
    row = DB.execute("SELECT * FROM users WHERE email = ?", [email]).first
    row ? new(row) : nil
  end

  # Find user by ID
  def self.find(id)
    return nil unless id
    row = DB.execute("SELECT * FROM users WHERE id = ?", [id]).first
    row ? new(row) : nil
  end

  # Authenticate password
  def authenticate(password)
    return false unless password && @password_hash
    BCrypt::Password.new(@password_hash) == password
  end

  # Check if user is admin
  def admin?
    @role == 'admin'
  end

  # Get user stats
  def stats
    {
      saved_count: DB.get_first_value("SELECT COUNT(*) FROM saved_memes WHERE user_id = ?", [@id]).to_i,
      liked_count: DB.get_first_value("SELECT COUNT(*) FROM user_meme_stats WHERE user_id = ? AND liked = 1", [@id]).to_i,
      created_at: DB.execute("SELECT created_at FROM users WHERE id = ?", [@id]).first['created_at']
    }
  end
end
