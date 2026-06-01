# 🚀 Fix Production Leaderboard (Render/PostgreSQL)

**Issue**: Production uses PostgreSQL which is missing gamification tables.

---

## 🎯 Quick Fix - Run Migration on Render

### Option 1: Using Render Shell (Recommended)

**Step 1: Open Render Shell**
```
1. Go to https://dashboard.render.com
2. Click on your "meme-explorer" service
3. Click "Shell" in the left sidebar
4. Wait for shell to open
```

**Step 2: Connect to PostgreSQL and Run Migration**
```bash
# In the Render shell, run:
psql $DATABASE_URL -f db/migrations/postgres_add_gamification.sql
```

**Step 3: Verify Tables Were Created**
```bash
psql $DATABASE_URL -c "\dt" | grep -E "user_levels|user_streaks"
```

Should show:
```
user_levels
user_streaks
xp_activity_log
weekly_leaderboard
monthly_leaderboard
```

**Step 4: Restart Your Service**
```
1. Go back to your service dashboard
2. Click "Manual Deploy" > "Clear build cache & deploy"
```

---

### Option 2: Local Connection to Render PostgreSQL

**Step 1: Get Database URL**
```
1. Go to Render Dashboard
2. Click on your PostgreSQL database
3. Copy the "External Database URL"
```

**Step 2: Run Migration from Local Machine**
```bash
# Replace with your actual DATABASE_URL
psql "postgresql://user:password@host:port/database" -f db/migrations/postgres_add_gamification.sql
```

---

### Option 3: Using SQL Editor (Manual)

**Step 1: Get Database Credentials**
```
1. Go to Render Dashboard > PostgreSQL database
2. Click "Connect"
3. Copy credentials
```

**Step 2: Connect with pgAdmin or TablePlus**
```
Host: [from Render]
Port: 5432
Database: [from Render]
User: [from Render]
Password: [from Render]
```

**Step 3: Run the SQL**
```
1. Open db/migrations/postgres_add_gamification.sql
2. Copy all contents
3. Paste into SQL editor
4. Execute
```

---

## 🔍 Verify It Worked

### Check Tables Exist
```sql
SELECT table_name 
FROM information_schema.tables 
WHERE table_schema = 'public' 
AND table_name LIKE '%user_%';
```

Should return:
- user_levels
- user_streaks
- user_collections
- (and more)

### Check Your User
```sql
SELECT u.id, u.reddit_username, 
       ul.level, ul.total_xp
FROM users u
LEFT JOIN user_levels ul ON u.id = ul.user_id
LIMIT 5;
```

If `user_levels` column is NULL, initialize your user:
```sql
INSERT INTO user_levels (user_id, level, total_xp) 
SELECT id, 1, 0 FROM users 
ON CONFLICT (user_id) DO NOTHING;
```

---

## ✅ After Migration

**1. Visit Your Production Site**
```
https://meme-explorer.onrender.com/leaderboard
```

**2. Expected Behavior**
- Page loads without error
- Shows "No Rankings Yet" (correct - you have 0 XP)

**3. Test It Works**
- Like a meme on production
- Visit /leaderboard again
- You should see yourself ranked!

---

## 🐛 If Still Getting Errors

### Check Render Logs
```
1. Go to Render Dashboard
2. Click on your service
3. Click "Logs"
4. Look for error messages
```

### Common Issues:

**"relation user_levels does not exist"**
→ Migration didn't run. Try Option 1 again.

**"permission denied"**
→ Use the Render shell (Option 1) which has correct permissions.

**"syntax error"**
→ Make sure you're running the PostgreSQL migration file, not the SQLite one.

---

## 📝 Summary

**What This Does:**
- Creates `user_levels` table (for XP/leaderboard)
- Creates `user_streaks` table (for daily streaks)
- Creates `weekly_leaderboard`, `monthly_leaderboard` tables
- Creates XP activity tracking

**Why Production Needed This:**
- Production uses PostgreSQL (different from local SQLite)
- The tables were only in local database
- Production database was missing all gamification features

**After Running:**
- ✅ Leaderboard will work in production
- ✅ Users can earn XP
- ✅ Rankings will display
- ✅ No more Internal Server Errors

---

**Run the migration using any option above, then your production leaderboard will work!** 🎉
