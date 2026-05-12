# Gamification & Leaderboard Fix - May 12, 2026

## Issues Fixed

### 1. ❌ Push Notification Error
**Problem**: PostgreSQL syntax used in SQLite database
```
unrecognized token: ":":"
INSERT INTO push_subscriptions (user_id, subscription_data) 
VALUES (?, ?) 
ON CONFLICT (user_id, md5(subscription_data::text)) DO UPDATE 
SET updated_at = CURRENT_TIMESTAMP
```

**Root Cause**: 
- Migration file `db/migrations/add_push_subscriptions.sql` used PostgreSQL syntax
- App uses SQLite, not PostgreSQL
- PostgreSQL-specific features: `JSONB`, `::text` casting, `md5()` function

**Fix**:
1. ✅ Created SQLite-compatible migration: `db/migrations/add_push_subscriptions_sqlite.sql`
2. ✅ Updated `db/setup.rb` to create `push_subscriptions` table on startup
3. ✅ Modified `app.rb` to use SQLite-compatible upsert logic
4. ✅ Updated `PushNotificationService` to handle text-stored JSON

**Changes Made**:

**db/setup.rb**:
```ruby
DB.execute <<-SQL
  CREATE TABLE IF NOT EXISTS push_subscriptions (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    user_id INTEGER NOT NULL,
    subscription_data TEXT NOT NULL,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
  );
SQL

# Add index
DB.execute("CREATE INDEX IF NOT EXISTS idx_push_subscriptions_user_id ON push_subscriptions(user_id)")
```

**app.rb** (lines 2183-2225):
```ruby
post "/api/subscribe-push" do
  halt 401, { error: "Not logged in" }.to_json unless session[:user_id]
  
  begin
    subscription_data = JSON.parse(request.body.read)
    subscription_json = subscription_data.to_json
    
    # Store subscription in database (SQLite-compatible)
    # Check if subscription already exists
    existing = DB.execute(
      "SELECT id FROM push_subscriptions WHERE user_id = ? AND subscription_data = ?",
      [session[:user_id], subscription_json]
    ).first
    
    if existing
      # Update existing subscription timestamp
      DB.execute(
        "UPDATE push_subscriptions SET updated_at = CURRENT_TIMESTAMP WHERE id = ?",
        [existing['id']]
      )
    else
      # Insert new subscription
      DB.execute(
        "INSERT INTO push_subscriptions (user_id, subscription_data, created_at, updated_at) 
         VALUES (?, ?, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)",
        [session[:user_id], subscription_json]
      )
    end
    
    puts "✅ Push subscription saved for user #{session[:user_id]}"
    
    content_type :json
    { success: true, message: "Push subscription saved" }.to_json
  rescue => e
    puts "❌ Push subscription error: #{e.message}"
    halt 500, { error: "Failed to save subscription", details: e.message }.to_json
  end
end
```

**lib/services/push_notification_service.rb**:
```ruby
def self.get_user_subscriptions(user_id)
  DB.execute(
    "SELECT subscription_data FROM push_subscriptions WHERE user_id = ?",
    [user_id]
  ).map do |row|
    data = row["subscription_data"]
    # Handle both string and already-parsed JSON
    data.is_a?(String) ? JSON.parse(data) : data
  end
rescue => e
  puts "❌ Error fetching subscriptions: #{e.message}"
  []
end
```

---

### 2. ⚠️ Gamification Not Reflected in Leaderboard
**Problem**: XP is being awarded but leaderboard not updating

**Root Cause**: 
- Leaderboard calculation runs via Sidekiq worker
- Worker might not be running or scheduled incorrectly
- XP updates in `user_levels` table don't automatically trigger leaderboard recalculation

**Fix**:
1. ✅ Created manual sync script: `scripts/fix_leaderboard_sync.rb`
2. ✅ Script repopulates leaderboard from `user_levels` table
3. ✅ Recalculates ranks correctly

**How XP & Leaderboard Work**:

1. **XP Award Flow**:
   ```
   User Action (like, view, save, streak) 
   → add_xp() in gamification_helpers.rb
   → Updates user_levels table (total_xp, current_xp, level)
   → Does NOT automatically update leaderboard
   ```

2. **Leaderboard Update Flow**:
   ```
   Sidekiq Worker (LeaderboardCalculationWorker)
   → Runs periodically (configured in config/sidekiq.yml)
   → Reads total_xp from user_levels
   → Updates weekly_leaderboard & monthly_leaderboard
   → Recalculates ranks
   ```

3. **The Gap**: If Sidekiq isn't running or worker hasn't executed, leaderboard stays stale

**Manual Sync Script**:
```bash
# Run this to sync leaderboard with current XP
ruby scripts/fix_leaderboard_sync.rb
```

**What the Script Does**:
1. Gets current week/month numbers
2. Fetches all users with XP > 0
3. Clears old leaderboard entries for current period
4. Populates leaderboard from user_levels.total_xp
5. Recalculates ranks
6. Shows top 10

---

## Testing

### Test Push Notifications
1. **Restart Server**: Kill and restart your server to load new code
   ```bash
   # Stop server (Ctrl+C)
   ruby app.rb
   ```

2. **Login** to the app

3. **Open Browser Console** and check for errors

4. **Subscribe** to push notifications (if prompted)

5. **Verify** no more errors in console

### Test Leaderboard
1. **Run Sync Script**:
   ```bash
   ruby scripts/fix_leaderboard_sync.rb
   ```

2. **Restart Server**

3. **Visit** `/leaderboard`

4. **Verify** you see users with XP listed

5. **Like a meme** and run sync script again to see ranking update

---

## Monitoring

### Check If Sidekiq Is Running
```bash
# Look for Sidekiq process
ps aux | grep sidekiq

# Or check in app
# Visit /health endpoint and look for worker status
```

### Enable Automatic Leaderboard Updates
Ensure Sidekiq is running with your app:
```bash
# Start Sidekiq (in separate terminal)
bundle exec sidekiq -C config/sidekiq.yml

# Or use Procfile with foreman
foreman start
```

### Check Leaderboard Worker Schedule
In `config/sidekiq.yml`, verify schedule:
```yaml
:schedule:
  leaderboard_calculation:
    every: '15m'  # Runs every 15 minutes
    class: LeaderboardCalculationWorker
```

---

## Prevention

### For Push Notifications
- ✅ Always test SQL syntax matches database (SQLite vs PostgreSQL)
- ✅ Use `CREATE TABLE IF NOT EXISTS` in migrations
- ✅ Handle JSON properly (TEXT in SQLite, JSONB in PostgreSQL)

### For Leaderboard
- ✅ Run Sidekiq workers in production
- ✅ Monitor worker execution with logging
- ✅ Consider adding real-time leaderboard updates (update on each XP award)
- ✅ Cache leaderboard results for performance

---

## Quick Reference

### Restart Server
```bash
# Stop (Ctrl+C) then:
ruby app.rb
```

### Sync Leaderboard
```bash
ruby scripts/fix_leaderboard_sync.rb
```

### Check Database
```bash
sqlite3 db/memes.db

# Check push_subscriptions table
SELECT * FROM push_subscriptions;

# Check user XP
SELECT u.reddit_username, u.email, ul.total_xp, ul.level 
FROM users u 
JOIN user_levels ul ON u.id = ul.user_id 
ORDER BY ul.total_xp DESC LIMIT 10;

# Check leaderboard
SELECT wl.rank, u.reddit_username, wl.metric_value 
FROM weekly_leaderboard wl 
JOIN users u ON wl.user_id = u.id 
ORDER BY wl.rank ASC LIMIT 10;
```

---

## Summary

✅ **Push Notifications**: Fixed PostgreSQL → SQLite syntax incompatibility
✅ **Leaderboard**: Created sync script to populate from user XP
✅ **Tables**: Created push_subscriptions table on startup
✅ **Indexes**: Added for performance

**Next Steps**:
1. Restart server
2. Run leaderboard sync script
3. Test both features
4. Consider enabling Sidekiq for automatic updates

---

**Date**: May 12, 2026
**Issues Fixed**: Push notification SQL error, Leaderboard not syncing
**Files Modified**: 
- `app.rb`
- `db/setup.rb`
- `lib/services/push_notification_service.rb`
- `db/migrations/add_push_subscriptions_sqlite.sql` (new)
- `scripts/fix_leaderboard_sync.rb` (new)
