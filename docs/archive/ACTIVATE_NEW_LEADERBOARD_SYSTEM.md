# 🚀 Activating Advanced Leaderboard System - Step-by-Step Guide

**Goal:** Fully activate LeaderboardService with all advanced features  
**Time Estimate:** 15-20 minutes

---

## Step 1: Verify/Create Database Tables

### 1a. Check if tables exist

Run in your terminal:

```bash
sqlite3 memes.db.backup_20251123_172744 <<EOF
.tables
EOF
```

**Look for these 8 new tables:**
- `leaderboard_rankings`
- `leaderboard_activities`
- `leaderboard_periods`
- `leaderboard_snapshots`
- `leaderboard_achievements`
- `leaderboard_challenges`
- `leaderboard_rewards`
- `leaderboard_config`

### 1b. If tables DON'T exist, create them

**First, identify your active database:**

```bash
# Check which database file your app is using
ls -lh *.db* | head -5
```

**Then run the migration on the ACTIVE database:**

```bash
# Replace YOUR_DB_FILE.db with your actual database
ruby -e "
require 'sqlite3'
DB = SQLite3::Database.new('YOUR_DB_FILE.db')
DB.results_as_hash = true
sql = File.read('db/migrations/enhance_leaderboard_system.sql')
DB.execute_batch(sql)
puts '✅ Tables created successfully!'
"
```

### 1c. Verify tables were created

```bash
sqlite3 YOUR_DB_FILE.db ".schema leaderboard_rankings"
```

Should show the table structure. If you see output, tables exist!

---

## Step 2: Migrate Existing Data

### 2a. Copy old leaderboard data to new system

Create file: `scripts/migrate_leaderboard_data.rb`

```ruby
require_relative '../db/setup'
require_relative '../lib/services/leaderboard_service'

puts "🔄 Migrating weekly_leaderboard data to new system..."

# Get all existing weekly leaderboard entries
old_entries = DB.execute("SELECT * FROM weekly_leaderboard ORDER BY week_number DESC, rank ASC")

migrated = 0
old_entries.each do |entry|
  # Convert to new format
  period_id = entry['week_number']  # e.g., 202619
  user_id = entry['user_id']
  score = entry['metric_value']
  
  # Insert into new system
  DB.execute(
    "INSERT OR IGNORE INTO leaderboard_rankings 
     (user_id, leaderboard_type, period_id, total_score, rank, created_at, updated_at)
     VALUES (?, 'weekly', ?, ?, ?, datetime('now'), datetime('now'))",
    [user_id, period_id, score, entry['rank']]
  )
  
  migrated += 1
rescue => e
  puts "⚠️ Error migrating entry: #{e.message}"
end

puts "✅ Migrated #{migrated} entries to new system"

# Initialize config
DB.execute(
  "INSERT OR IGNORE INTO leaderboard_config (leaderboard_type, setting_key, setting_value)
   VALUES 
   ('weekly', 'activity_weights', '{\"view\":1,\"like\":5,\"save\":10,\"share\":15,\"streak\":50}'),
   ('monthly', 'activity_weights', '{\"view\":1,\"like\":5,\"save\":10,\"share\":15,\"streak\":50}'),
   ('all_time', 'activity_weights', '{\"view\":1,\"like\":5,\"save\":10,\"share\":15,\"streak\":50}')"
)

puts "✅ Leaderboard migration complete!"
```

**Run it:**

```bash
ruby scripts/migrate_leaderboard_data.rb
```

---

## Step 3: Connect Activity Tracking

### 3a. Update toggle_like() to record activities

In `app.rb`, find the `toggle_like` helper and modify:

```ruby
def toggle_like(url, liked_now, session)
  # ... existing code ...
  
  if liked_now && !was_liked_before && user_id
    # ... existing DB updates ...
    
    # NEW: Record activity in leaderboard system
    begin
      LeaderboardService.record_activity(
        user_id: user_id,
        activity_type: 'like',
        points: 5,
        metadata: { meme_url: url }.to_json
      )
    rescue => e
      puts "⚠️ Leaderboard activity tracking failed: #{e.message}"
    end
  end
  
  # ... rest of method ...
end
```

### 3b. Update save_meme() to record activities

In `app.rb`, find the `save_meme` helper:

```ruby
def save_meme(user_id, meme_url, meme_title, meme_subreddit)
  DB.execute(
    "INSERT OR IGNORE INTO saved_memes (user_id, meme_url, meme_title, meme_subreddit) VALUES (?, ?, ?, ?)",
    [user_id, meme_url, meme_title, meme_subreddit]
  )
  
  # NEW: Record save activity
  begin
    LeaderboardService.record_activity(
      user_id: user_id,
      activity_type: 'save',
      points: 10,
      metadata: { meme_url: meme_url, title: meme_title }.to_json
    )
  rescue => e
    puts "⚠️ Leaderboard save tracking failed: #{e.message}"
  end
  
  # Existing gamification code...
  add_xp(user_id, :save_meme) rescue nil
end
```

### 3c. Track view activities

In `app.rb`, in the `/random.json` route, add:

```ruby
# After tracking view in meme_stats
if session[:user_id]
  begin
    LeaderboardService.record_activity(
      user_id: session[:user_id],
      activity_type: 'view',
      points: 1,
      metadata: { meme_url: image_url }.to_json
    )
  rescue => e
    # Silent fail - don't break meme viewing
  end
end
```

---

## Step 4: Enable Score Calculation

### 4a. Create background job to calculate scores

Create: `scripts/calculate_leaderboard_scores.rb`

```ruby
require_relative '../db/setup'
require_relative '../lib/services/leaderboard_service'

puts "📊 Calculating leaderboard scores..."

# Calculate for all periods
['weekly', 'monthly', 'all_time'].each do |type|
  puts "\n#{type.capitalize} Leaderboard:"
  
  begin
    LeaderboardService.calculate_scores(type.to_sym)
    
    # Show top 5
    top = LeaderboardService.get_leaderboard(type: type.to_sym, limit: 5)
    top.each_with_index do |entry, i|
      username = entry['username'] || entry['email'] || "User #{entry['user_id']}"
      puts "  #{i+1}. #{username}: #{entry['total_score']} points"
    end
  rescue => e
    puts "  ⚠️ Error: #{e.message}"
  end
end

puts "\n✅ Score calculation complete!"
```

**Run it:**

```bash
ruby scripts/calculate_leaderboard_scores.rb
```

---

## Step 5: Test Each Leaderboard Type

### 5a. Restart server

```bash
# Stop server (Ctrl+C)
ruby app.rb
```

### 5b. Test URLs

Visit each type and verify it works:

```
http://localhost:4567/leaderboard
http://localhost:4567/leaderboard?type=weekly
http://localhost:4567/leaderboard?type=monthly
http://localhost:4567/leaderboard?type=all_time
http://localhost:4567/leaderboard?type=streak
```

**What to check:**
- ✅ Page loads without errors
- ✅ Shows actual rankings (not "No Rankings Yet")
- ✅ User rank card displays (if logged in)
- ✅ Type selector works
- ✅ Period dropdown has entries (for weekly/monthly)

---

## Step 6: Setup Automated Score Updates

### 6a. Add cron job (production)

Add to your deployment or crontab:

```bash
# Update leaderboard scores every hour
0 * * * * cd /path/to/meme-explorer && ruby scripts/calculate_leaderboard_scores.rb >> log/leaderboard_cron.log 2>&1
```

### 6b. Add background thread (development)

In `app.rb`, add after other background threads:

```ruby
# Leaderboard score calculation thread (every 10 minutes)
@leaderboard_calc_thread = Thread.new do
  sleep 300  # Wait 5 minutes on startup
  loop do
    begin
      puts "📊 [LEADERBOARD] Calculating scores..."
      [:weekly, :monthly, :all_time].each do |type|
        LeaderboardService.calculate_scores(type)
      end
      puts "✅ [LEADERBOARD] Scores updated"
    rescue => e
      puts "❌ [LEADERBOARD] Calc error: #{e.message}"
    end
    sleep 600  # Every 10 minutes
  end
end
```

---

## Step 7: Verify Advanced Features

### 7a. Check user rank card

**Log in** to your app, then visit `/leaderboard`

Should see:
- Your current rank
- Rank change indicator (↑↓−)
- Nearby competitors
- Smart insights ("You need X points for top 10!")

### 7b. Check historical periods

On weekly/monthly leaderboards, check the dropdown:
- Should have 5 previous periods
- Clicking should load that period's rankings

### 7c. Test type switching

Click the type buttons:
- Weekly → Monthly → All-Time → Streak
- Each should load different rankings

---

## Step 8: Monitor & Debug

### 8a. Check logs

```bash
tail -f log/production.log | grep LEADERBOARD
```

Look for:
- `✅ [LEADERBOARD] Scores updated`
- `📊 [LEADERBOARD] Calculating scores...`

### 8b. Verify activity tracking

In terminal/console:

```bash
sqlite3 YOUR_DB.db "SELECT COUNT(*) FROM leaderboard_activities;"
```

Should show increasing count as users interact.

### 8c. Check rankings table

```bash
sqlite3 YOUR_DB.db "SELECT * FROM leaderboard_rankings ORDER BY total_score DESC LIMIT 5;"
```

Should show current top 5 with scores.

---

## Troubleshooting

### Problem: "No Rankings Yet" after migration

**Solution:** Run score calculation manually:

```bash
ruby scripts/calculate_leaderboard_scores.rb
```

### Problem: Advanced features still not showing

**Check:**
1. Are you logged in? (rank card only shows for logged-in users)
2. Do you have activities? (like/save some memes)
3. Check browser console for JS errors

### Problem: Period dropdown empty

**Fix:** Ensure `current_period()` and `previous_period()` work:

```ruby
# In rails console or irb
require_relative 'lib/services/leaderboard_service'
puts LeaderboardService.current_period(:weekly)  # Should print 202619 or similar
```

---

## Success Criteria

✅ All 8 new tables exist  
✅ Old data migrated to new system  
✅ Activities being tracked (check count increasing)  
✅ Scores calculating correctly  
✅ All 4 leaderboard types working  
✅ Rank card displays for logged-in users  
✅ Historical periods dropdown populated  
✅ No errors in terminal logs  

---

## What You Get

After completion, you'll have:
- 📊 5 leaderboard types (weekly, monthly, all-time, streak, category)
- 🏆 User rank cards with position & change indicators
- 🎯 Smart insights ("45 points to top 10!")
- 👥 Nearby competitors view
- 📅 Historical period viewing
- 🎨 Beautiful modern UI
- ⚡ Real-time score updates
- 🔧 Extensible activity tracking system

You're transforming a basic counter into a full-featured competitive leaderboard system!
