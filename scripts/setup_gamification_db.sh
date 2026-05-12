#!/bin/bash

# Setup Gamification Database Tables
# This script helps you run the gamification migration on your production database

echo "🎮 Gamification Database Setup"
echo "=============================="
echo ""

# Check if DATABASE_URL is provided
if [ -z "$1" ]; then
    echo "❌ ERROR: DATABASE_URL not provided"
    echo ""
    echo "📋 How to get your DATABASE_URL:"
    echo "1. Go to https://dashboard.render.com"
    echo "2. Click on your PostgreSQL database (not web service)"
    echo "3. Look for 'External Database URL' or 'Internal Database URL'"
    echo "4. Copy the entire URL (starts with postgresql://)"
    echo ""
    echo "📝 Usage:"
    echo "./scripts/setup_gamification_db.sh 'postgresql://user:pass@host:port/dbname'"
    echo ""
    echo "OR set it as environment variable:"
    echo "export PROD_DATABASE_URL='postgresql://user:pass@host:port/dbname'"
    echo "./scripts/setup_gamification_db.sh"
    exit 1
fi

DATABASE_URL="$1"

echo "✅ Database URL provided"
echo "🔄 Running gamification migration..."
echo ""

# Run the SQL migration
psql "$DATABASE_URL" << 'EOF'
-- Create user_achievements table for milestones
CREATE TABLE IF NOT EXISTS user_achievements (
  id SERIAL PRIMARY KEY,
  user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  achievement_type VARCHAR(50) NOT NULL,
  achievement_data TEXT,
  earned_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_user_achievements_user_id ON user_achievements(user_id);
CREATE INDEX IF NOT EXISTS idx_user_achievements_type ON user_achievements(achievement_type);

-- Verify table was created
SELECT 'user_achievements' as table_name, COUNT(*) as row_count FROM user_achievements;
EOF

if [ $? -eq 0 ]; then
    echo ""
    echo "✅ Gamification tables created successfully!"
    echo "🎉 Gamification is now active on your site!"
    echo ""
    echo "Visit https://meme-explorer.onrender.com/random and refresh 5 times to see milestones!"
else
    echo ""
    echo "❌ Migration failed. Check error above."
    echo ""
    echo "💡 TIP: Make sure psql is installed:"
    echo "   brew install postgresql  # macOS"
    echo "   sudo apt install postgresql-client  # Linux"
fi
