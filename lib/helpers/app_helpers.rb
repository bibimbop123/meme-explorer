# frozen_string_literal: true

# AppHelpers - Extracted from app.rb during Phase 2 Refactoring
# Contains helper methods that were previously inline in the main app file
# 
# This module provides:
# - Curated collection wrappers
# - Taste profile rendering
# - Password hashing/verification
# - User creation/management
#
# Date: June 4, 2026
# Phase 2: app.rb Refactoring

module AppHelpers
  # ====================
  # CURATED COLLECTIONS
  # ====================
  
  # Wrapper for collection_name_for_subreddit (views expect this method name)
  def collection_name_for_subreddit(subreddit)
    CuratedCollectionsHelper.collection_name_for(subreddit)
  end
  
  # Wrapper for calculate_rarity (used in views/random.erb)
  def calculate_rarity(meme)
    rarity = refined_rarity_badge(meme)
    return rarity if rarity
    
    # Default rarity for common memes
    { label: 'Common', icon: '•' }
  end
  
  # Wrapper for generate_curation_signal (used in views/random.erb and layout.erb)
  def generate_curation_signal(meme)
    # Pass nil for user since we don't have user hash/object loaded
    # The service handles nil gracefully and will skip personalized signals
    signal = refined_curation_signal(meme, nil)
    return signal if signal
    
    # Default curation signal
    { type: 'default', icon: '✨', message: 'Curated for you' }
  end
  
  # Wrapper for rendering taste profile (used in views/profile.erb)
  def render_taste_profile(user_id)
    return '' unless user_id
    
    begin
      # Fetch user data
      user = get_user(user_id)
      return '' unless user
      
      # Generate taste profile using TasteProfileService
      profile = TasteProfileService.generate_profile(user)
      
      # Render the partial with profile data
      erb :_taste_profile, locals: { profile: profile }
    rescue => e
      AppLogger.error("⚠️ Error rendering taste profile: #{e.class} - #{e.message}")
      AppLogger.error("backtrace", lines: (e.backtrace.first(3).join("\n") if e.backtrace)&.join("\n"))
      ''  # Return empty string on error to prevent page crash
    end
  end

  # ====================
  # PASSWORD & AUTH
  # ====================
  
  # Hash password with bcrypt
  def hash_password(password)
    BCrypt::Password.create(password)
  end

  # Verify password
  def verify_password(password, hash)
    BCrypt::Password.new(hash) == password
  end

  # ====================
  # USER MANAGEMENT
  # ====================
  
  # Create or find user by Reddit credentials
  def create_or_find_user(reddit_username, reddit_id, reddit_email)
    existing = DB.execute("SELECT id FROM users WHERE reddit_id = ?", [reddit_id]).first
    return existing["id"] if existing

    DB.last_insert_row_id(
      "INSERT INTO users (reddit_id, reddit_username, reddit_email) VALUES (?, ?, ?)",
      [reddit_id, reddit_username, reddit_email]
    )
  end

  # Create email/password user
  def create_email_user(email, password)
    hashed = hash_password(password)
    DB.last_insert_row_id(
      "INSERT INTO users (email, password_hash) VALUES (?, ?)",
      [email, hashed]
    )
  rescue PG::UniqueViolation, StandardError => e
    raise e unless e.message =~ /unique|duplicate/i
    nil
  end

  # Find user by email
  def find_user_by_email(email)
    DB.execute("SELECT id, password_hash FROM users WHERE email = ?", [email]).first
  end

  # Get user by ID (used throughout the application)
  def get_user(user_id)
    DB.execute("SELECT * FROM users WHERE id = ?", [user_id]).first
  end

# Admin role check - FIXED July 22, 2026 to use 'role' column
def is_admin?(user_id)
  return false unless user_id
  
  # Query role using DBWrapper's execute method
  result = DB.execute("SELECT role FROM users WHERE id = ?", [user_id])
  return false if result.nil? || result.empty?
  
  # Check if role is 'admin'
  role_value = result.first['role']
  role_value == 'admin'
rescue => e
  AppLogger.error('[AdminCheck] Error checking admin status', error: e.message)
  false
end

end