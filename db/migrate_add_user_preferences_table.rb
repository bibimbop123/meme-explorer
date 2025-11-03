# Database Migration: Create user_preferences table
# Phase 3: Advanced Features - User Preference Tracking

class AddUserPreferencesTable
  def self.up
    # Create user_preferences table
    execute <<-SQL
      CREATE TABLE user_preferences (
        id SERIAL PRIMARY KEY,
        user_id INTEGER REFERENCES users(id) ON DELETE CASCADE,
        session_id VARCHAR(255) UNIQUE NOT NULL,
        preferences JSONB DEFAULT '{}'::jsonb,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
      );
    SQL

    # Create indices for efficient queries
    execute "CREATE INDEX idx_user_preferences_user_id ON user_preferences(user_id);"
    execute "CREATE INDEX idx_user_preferences_session_id ON user_preferences(session_id);"
    execute "CREATE INDEX idx_user_preferences_preferences ON user_preferences USING gin(preferences);"

    puts "✅ User preferences table created"
  end

  def self.down
    execute "DROP TABLE IF EXISTS user_preferences CASCADE;"
    puts "✅ User preferences table dropped"
  end

  private

  def self.execute(sql)
    if defined?(Sequel)
      DB.run(sql)
    elsif defined?(ActiveRecord)
      ActiveRecord::Base.connection.execute(sql)
    else
      # Raw PG connection for Sinatra
      conn = PG.connect(
        host: ENV['DB_HOST'] || 'localhost',
        user: ENV['DB_USER'] || 'postgres',
        password: ENV['DB_PASSWORD'],
        database: ENV['DATABASE_URL']&.split('/')&.last || 'meme_explorer'
      )
      conn.exec(sql)
      conn.close
    end
  end
end

# Usage: ruby db/migrate_add_user_preferences_table.rb
if __FILE__ == $0
  AddUserPreferencesTable.up
end
