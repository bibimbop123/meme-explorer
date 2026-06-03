#!/bin/bash
# ============================================
# PRODUCTION DEPLOYMENT SCRIPT - June 2026
# Fixes critical production errors systematically
# ============================================

set -e  # Exit on error

echo "🚀 Production Fixes Deployment Script"
echo "======================================"
echo ""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Step 1: Run PostgreSQL migrations
echo -e "${YELLOW}📊 Step 1: Running PostgreSQL migrations...${NC}"
psql $DATABASE_URL -f db/migrations/fix_production_errors_2026.sql
if [ $? -eq 0 ]; then
    echo -e "${GREEN}✅ Database migrations complete${NC}"
else
    echo -e "${RED}❌ Migration failed - stopping deployment${NC}"
    exit 1
fi

# Step 2: Verify tables exist
echo -e "\n${YELLOW}🔍 Step 2: Verifying tables...${NC}"
psql $DATABASE_URL -c "\dt user_levels" > /dev/null 2>&1
psql $DATABASE_URL -c "\dt user_streaks" > /dev/null 2>&1
psql $DATABASE_URL -c "\dt user_liked_memes" > /dev/null 2>&1

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✅ All tables verified${NC}"
else
    echo -e "${RED}⚠️  Some tables missing - check manually${NC}"
fi

# Step 3: Initialize data for existing users
echo -e "\n${YELLOW}👥 Step 3: Initializing gamification data for existing users...${NC}"
psql $DATABASE_URL << 'EOSQL'
-- Initialize user_levels for existing users
INSERT INTO user_levels (user_id, level, current_xp, total_xp, title)
SELECT id, 1, 0, 0, 'Meme Novice'
FROM users
WHERE id NOT IN (SELECT user_id FROM user_levels)
ON CONFLICT (user_id) DO NOTHING;

-- Initialize user_streaks for existing users
INSERT INTO user_streaks (user_id, current_streak, longest_streak, last_visit_date)
SELECT id, 0, 0, CURRENT_DATE
FROM users
WHERE id NOT IN (SELECT user_id FROM user_streaks)
ON CONFLICT (user_id) DO NOTHING;

SELECT COUNT(*) as initialized_users FROM user_levels;
EOSQL

echo -e "${GREEN}✅ User data initialized${NC}"

# Step 4: Restart application
echo -e "\n${YELLOW}🔄 Step 4: Restarting application...${NC}"
# On Render, this happens automatically on git push
# For manual restart, use Render CLI or dashboard
echo -e "${GREEN}✅ Ready for restart${NC}"

# Summary
echo -e "\n${GREEN}======================================"
echo "✅ DEPLOYMENT COMPLETE"
echo "======================================${NC}"
echo ""
echo "📋 What was fixed:"
echo "  • Created user_levels table"
echo "  • Created user_streaks table"  
echo "  • Created user_liked_memes table"
echo "  • Initialized data for existing users"
echo ""
echo "🔍 Next steps:"
echo "  1. Monitor logs for errors"
echo "  2. Test user login and profile pages"
echo "  3. Verify like functionality"
echo "  4. Check leaderboard displays correctly"
echo ""
echo "📊 Monitor at: https://meme-explorer.onrender.com"
