require 'spec_helper'

describe UserService do
  describe '.create_or_find_from_reddit' do
    it 'creates a new user with Reddit OAuth data' do
      user_id = UserService.create_or_find_from_reddit('testuser', 'reddit123', 'test@reddit.com')
      expect(user_id).to be_a(Integer)
      
      user = DB.execute("SELECT * FROM users WHERE reddit_id = ?", ['reddit123']).first
      expect(user['reddit_username']).to eq('testuser')
    end

    it 'returns existing user ID if already exists' do
      first_id = UserService.create_or_find_from_reddit('testuser', 'reddit123', 'test@reddit.com')
      second_id = UserService.create_or_find_from_reddit('testuser', 'reddit123', 'test@reddit.com')
      expect(first_id).to eq(second_id)
    end
  end

  describe '.create_email_user' do
    it 'creates user with email and password hash' do
      user_id = UserService.create_email_user('user@example.com', 'password123')
      expect(user_id).to be_a(Integer)
      
      user = DB.execute("SELECT * FROM users WHERE email = ?", ['user@example.com']).first
      expect(user['email']).to eq('user@example.com')
      expect(user['password_hash']).to_not be_nil
    end

    it 'returns nil for duplicate email' do
      UserService.create_email_user('user@example.com', 'password123')
      result = UserService.create_email_user('user@example.com', 'password456')
      expect(result).to be_nil
    end
  end

  describe '.verify_password' do
    it 'returns true for correct password' do
      hashed = BCrypt::Password.create('password123')
      result = UserService.verify_password('password123', hashed)
      expect(result).to eq(true)
    end

    it 'returns false for incorrect password' do
      hashed = BCrypt::Password.create('password123')
      result = UserService.verify_password('wrongpassword', hashed)
      expect(result).to eq(false)
    end
  end

  describe '.find_by_email' do
    it 'finds user by email' do
      UserService.create_email_user('test@example.com', 'password123')
      user = UserService.find_by_email('test@example.com')
      expect(user).to_not be_nil
      expect(user['email']).to eq('test@example.com')
    end

    it 'returns nil for non-existent email' do
      user = UserService.find_by_email('nonexistent@example.com')
      expect(user).to be_nil
    end
  end

  describe '.is_admin?' do
    it 'returns false for regular user' do
      user_id = UserService.create_email_user('user@example.com', 'password123')
      result = UserService.is_admin?(user_id)
      expect(result).to eq(false)
    end

    it 'returns true for admin user' do
      user_id = UserService.create_email_user('admin@example.com', 'password123')
      DB.execute("UPDATE users SET role = 'admin' WHERE id = ?", [user_id])
      result = UserService.is_admin?(user_id)
      expect(result).to eq(true)
    end
  end

  describe '.save_meme' do
    it 'saves meme for user' do
      user_id = UserService.create_email_user('user@example.com', 'password123')
      UserService.save_meme(user_id, 'http://example.com/meme.jpg', 'Funny Meme', 'funny')
      
      saved = DB.execute("SELECT * FROM saved_memes WHERE user_id = ?", [user_id]).first
      expect(saved).to_not be_nil
      expect(saved['meme_url']).to eq('http://example.com/meme.jpg')
    end
  end

  describe '.get_saved_memes' do
    it 'retrieves paginated saved memes' do
      user_id = UserService.create_email_user('user@example.com', 'password123')
      3.times { |i| UserService.save_meme(user_id, "http://example.com/meme#{i}.jpg", "Meme #{i}", 'funny') }
      
      page1 = UserService.get_saved_memes(user_id, 1, 2)
      expect(page1.size).to eq(2)
      
      page2 = UserService.get_saved_memes(user_id, 2, 2)
      expect(page2.size).to eq(1)
    end
  end

  describe '.get_saved_memes_count' do
    it 'returns correct count of saved memes' do
      user_id = UserService.create_email_user('user@example.com', 'password123')
      3.times { |i| UserService.save_meme(user_id, "http://example.com/meme#{i}.jpg", "Meme #{i}", 'funny') }
      
      count = UserService.get_saved_memes_count(user_id)
      expect(count).to eq(3)
    end
  end
end
