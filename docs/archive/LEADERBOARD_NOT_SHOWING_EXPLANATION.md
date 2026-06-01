# 🏆 Leaderboard Not Showing - Root Cause Analysis

**Date**: May 11, 2026  
**Status**: ❌ **CRITICAL DATABASE ISSUE**

---

## 🔍 Problem Summary

The leaderboard feature is not displaying any data because:

1. **Missing `users` table** in the database
2. **Empty leaderboard tables** (no data populated)
3. **Database queries failing** due to missing table references

---

## 🐛 Root Causes Identified

### 1. **Missing Users Table** ⚠️ CRITICAL
```sql
-- The database is missing this table:
Error: in prepare, no such table: users
```

**Evidence:**
- All gamification tables have foreign keys to `users(id)`
- The `users` table definition exists in `db/setup.rb` but was never executed
- Queries in `LeaderboardService` JOIN with `users` table, causing failures

**Tables referencing missing `users` table:**
- `user_streaks` 
- `user_levels`
- `user_collections`
- `user_friendships`
- `user_challenges`
- `weekly_leaderboard` (via JOINs)
- `monthly_leaderboard` (via JOINs)

### 2. **Empty Leaderboard Data** 📊
```bash
# Database query results:
weekly_leaderboard: 0 rows
user_levels with XP > 0: 0 rows
```

**Why it's empty:**
- No users have been created
- No activities have been tracked
- No leaderboard scores have been calculated

### 3. **Service Query Failures** 💥

The `LeaderboardService` queries fail at lines 114-133:
```ruby
def get_weekly_leaderboard(week_num, limit, offset)
  DB.execute(
    "SELECT 
      wl.rank,
      wl.user_id,
      wl.metric_value as score,
      u.reddit_username,    # ❌ FAILS HERE
      u.email,               # ❌ users table doesn't exist
      ul.level,
      ul.title,
      ul.total_xp,
      us.current_streak
     FROM weekly_leaderboard wl
     JOIN users u ON wl.user_id = u.id  # ❌ FAILS: no users table
     ...
```

---

## 📋 Current Database State

### Tables That Exist:
✅ `user_streaks`
✅ `user_levels` 
✅ `meme_collections`
✅ `user_collections`
✅ `weekly_challenges`
✅ `weekly_leaderboard`
✅ `xp_activity_log`
✅ `monthly_leaderboard`
✅ `category_leaderboard`
✅ `achievements_log`

### Tables That Are Missing:
❌ `users` - **CRITICAL**

### Tables That Are Empty:
- `weekly_leaderboard` (0 rows)
- `user_levels` (0 rows with XP)
- `monthly_leaderboard` (likely 0 rows)

---

## 🔧 How the Leaderboard SHOULD Work

### Expected Flow:
1. **User signs up** → Creates entry in `users` table
2. **User likes/saves memes** → Creates entry in `xp_activity_log`
3. **ActivityTrackerService** → Updates `user_levels` with XP
4. **Leaderboard calculation script** → Populates `weekly_leaderboard`
5. **LeaderboardService** → JOINs data and returns to view
6. **View displays** → Shows rankings with user info

### Actual Flow:
1. ❌ No `users` table exists
2. ❌ No users can be created
3. ❌ No activities can be tracked properly
4. ❌ Leaderboard queries fail on JOIN
5. ❌ View shows "No Rankings Yet"

---

## 🚨 Why The View Shows Nothing

The `views/leaderboard.erb` checks:
```erb
<% if @leaderboard && @leaderboard.any? %>
  <!-- Show leaderboard entries -->
<% else %>
  <div class="leaderboard-empty">
    <h3>No Rankings Yet</h3>
    <p>Be the first to climb the leaderboard!</p>
  </div>
<% end %>
```

The `@leaderboard` array is empty because:
1. LeaderboardService returns `[]` when queries fail
2. The service has rescue blocks that catch errors and return empty arrays
3. No data exists even if queries succeeded

---

## 🛠️ Solutions Required

### Solution 1: Create Missing Users Table ⚡ URGENT

**Option A: Run the setup script**
```bash
ruby db/setup.rb
```

**Option B: Manual SQL**
```sql
CREATE TABLE IF NOT EXISTS users (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  email TEXT UNIQUE,
  password_hash TEXT,
  reddit_id TEXT UNIQUE,
  reddit_username TEXT,
  role TEXT DEFAULT 'user',
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
```

### Solution 2: Populate Data 📊

**Step 1: Create test users**
```ruby
# Via Rails console or script
3.times do |i|
  DB.execute(
    "INSERT INTO users (email, reddit_username) VALUES (?, ?)",
    ["user#{i}@test.com", "TestUser#{i}"]
  )
end
```

**Step 2: Initialize user_levels**
```ruby
users = DB.execute("SELECT id FROM users")
users.each do |user|
  DB.execute(
    "INSERT INTO user_levels (user_id, total_xp) VALUES (?, ?)",
    [user['id'], rand(100..1000)]
  )
end
```

**Step 3: Calculate leaderboard**
```bash
ruby scripts/calculate_leaderboard_scores.rb
```

### Solution 3: Fix Database Schema Migration 🔄

The proper fix is to ensure migrations run in correct order:

1. **Create base tables** (users, meme_stats, etc.)
2. **Add gamification tables** (user_levels, streaks, etc.)
3. **Add leaderboard tables** (weekly, monthly, etc.)
4. **Populate initial data**

---

## 📝 Quick Fix Commands

### Immediate Fix (Development):
```bash
# 1. Ensure users table exists
sqlite3 memes.db << EOF
CREATE TABLE IF NOT EXISTS users (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  email TEXT UNIQUE,
  password_hash TEXT,
  reddit_id TEXT UNIQUE,
  reddit_username TEXT,
  role TEXT DEFAULT 'user',
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
EOF

# 2. Create test users and data
ruby -r './db/setup.rb' -e "
3.times do |i|
  DB.execute('INSERT OR IGNORE INTO users (email, reddit_username) VALUES (?, ?)', 
    [\"testuser#{i}@example.com\", \"TestUser#{i}\"])
  user_id = DB.last_insert_row_id
  DB.execute('INSERT OR IGNORE INTO user_levels (user_id, total_xp, level) VALUES (?, ?, ?)',
    [user_id, (100 * (i + 1)), i + 1])
end
puts '✅ Created 3 test users'
"

# 3. Calculate leaderboard scores
ruby scripts/calculate_leaderboard_scores.rb

# 4. Restart server
# Visit /leaderboard
```

---

## 🎯 Verification Steps

After applying fixes:

1. **Check users table exists:**
   ```bash
   sqlite3 memes.db "SELECT COUNT(*) FROM users;"
   ```

2. **Check user_levels has data:**
   ```bash
   sqlite3 memes.db "SELECT * FROM user_levels LIMIT 5;"
   ```

3. **Check leaderboard data:**
   ```bash
   sqlite3 memes.db "SELECT COUNT(*) FROM weekly_leaderboard;"
   ```

4. **Test the endpoint:**
   ```bash
   curl http://localhost:8080/leaderboard
   # Should show user entries
   ```

---

## 🎓 Lessons Learned

1. **Foreign key dependencies must be created in order**
   - Base tables first (users)
   - Dependent tables second (user_levels)
   - Reference tables third (leaderboards)

2. **Migration scripts should check dependencies**
   - Verify prerequisite tables exist before creating referencing tables

3. **Service layer needs better error handling**
   - Currently fails silently, returning empty arrays
   - Should log specific error messages for debugging

4. **Initial data seeding is critical**
   - Empty tables make features appear broken
   - Need seed data for development/testing

---

## 📚 Related Files

- **Service**: `lib/services/leaderboard_service.rb`
- **View**: `views/leaderboard.erb`
- **Route**: `app.rb` (line 1951)
- **Migration**: `db/migrations/add_gamification_tables.sql`
- **Setup**: `db/setup.rb`
- **Scripts**: `scripts/calculate_leaderboard_scores.rb`

---

## ✅ Success Criteria

The leaderboard will work when:
- [x] Identified root causes
- [ ] `users` table exists in database
- [ ] Users have been created (or can be created)
- [ ] `user_levels` has entries with XP > 0
- [ ] `weekly_leaderboard` has calculated scores
- [ ] LeaderboardService queries succeed
- [ ] View displays user rankings

---

**Next Step**: Run the quick fix commands above to populate the database with test data.
