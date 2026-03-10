# 🎮 Gamification Quick Start Guide
**Created:** March 10, 2026  
**Time to implement:** 2-3 hours

---

## ✅ COMPLETED

- [x] Database tables created (`user_streaks`, `user_levels`, `meme_collections`, etc.)
- [x] Helper module created (`lib/helpers/gamification_helpers.rb`)
- [x] Migration executed successfully

---

## 🚀 NEXT STEPS (Do These Now)

### Step 1: Add Helpers to app.rb (5 minutes)

Add this line near the top of `app.rb` after other require statements:

```ruby
require_relative "./lib/helpers/gamification_helpers"
```

Then inside the `MemeExplorer` class, add:

```ruby
helpers GamificationHelpers
```

### Step 2: Track Streaks on Page Load (10 minutes)

In `app.rb`, find the `before` filter and add streak tracking:

```ruby
before do
  @start_time = Time.now
  @seen_memes = # ... existing code ...
  
  # NEW: Track streak for logged-in users
  if session[:user_id]
    @streak_data = update_streak(session[:user_id])
    @user_level = get_user_level(session[:user_id])
  end
end
```

### Step 3: Award XP for Actions (15 minutes)

**In the `toggle_like` method**, add XP rewards:

```ruby
def toggle_like(url, liked_now, session)
  # ... existing code ...
  
  if liked_now && !was_liked_before
    # ... existing DB updates ...
    
    # NEW: Award XP for liking
    if session[:user_id]
      xp_result = add_xp(session[:user_id], :like_meme)
      session[:last_xp_gain] = xp_result if xp_result
      
      # Update weekly leaderboard
      update_weekly_leaderboard(session[:user_id], 1)
    end
  end
  
  # ... rest of method ...
end
```

**In the `save_meme` helper**, add:

```ruby
def save_meme(user_id, meme_url, meme_title, meme_subreddit)
  DB.execute(
    "INSERT OR IGNORE INTO saved_memes (user_id, meme_url, meme_title, meme_subreddit) VALUES (?, ?, ?, ?)",
    [user_id, meme_url, meme_title, meme_subreddit]
  )
  
  # NEW: Award XP for saving
  add_xp(user_id, :save_meme)
end
```

### Step 4: Add Streak Banner to UI (20 minutes)

In `views/layout.erb`, add this after the `<nav>` section:

```html
<!-- Streak Banner -->
<% if session[:user_id] && @streak_data %>
  <div class="streak-banner" id="streak-banner">
    <% if @streak_data[:streak_increased] %>
      🔥 <strong><%= @streak_data[:days] %> Day Streak!</strong>
      <% if @streak_data[:milestone] %>
        <span class="milestone">🎉 MILESTONE! +<%= @streak_data[:xp_gained] %> XP</span>
      <% end %>
    <% elsif @streak_data[:new_streak] %>
      ✨ Welcome! Start your streak today!
    <% elsif @streak_data[:streak_broken] %>
      💔 Streak broken. Was <%= @streak_data[:old_streak] %> days. Start fresh!
    <% elsif @streak_data[:streak_frozen] %>
      ❄️ Streak freeze used! <%= @streak_data[:freezes_left] %> freezes left
    <% else %>
      🔥 <%= @streak_data[:days] %> day streak
    <% end %>
  </div>
<% end %>

<!-- Level Badge -->
<% if session[:user_id] && @user_level %>
  <div class="user-level-badge">
    <div class="level-info">
      <span class="level-number">Lv. <%= @user_level["level"] %></span>
      <span class="level-title"><%= @user_level["title"] %></span>
    </div>
    <div class="xp-bar">
      <div class="xp-fill" style="width: <%= @user_level["xp_progress"] %>%"></div>
    </div>
    <div class="xp-text">
      <%= @user_level["current_xp"] %> / <%= xp_for_level(@user_level["level"] + 1) %> XP
    </div>
  </div>
<% end %>

<style>
.streak-banner {
  position: fixed;
  top: 70px;
  right: 20px;
  background: linear-gradient(135deg, #ff6b6b, #ff8e53);
  color: white;
  padding: 12px 20px;
  border-radius: 30px;
  font-weight: 600;
  font-size: 0.9rem;
  box-shadow: 0 4px 15px rgba(255, 107, 107, 0.4);
  animation: slideInRight 0.5s ease-out;
  z-index: 1000;
}

.milestone {
  display: inline-block;
  margin-left: 10px;
  padding: 4px 12px;
  background: rgba(255, 255, 255, 0.2);
  border-radius: 15px;
  font-size: 0.85rem;
}

@keyframes slideInRight {
  from { transform: translateX(100%); opacity: 0; }
  to { transform: translateX(0); opacity: 1; }
}

.user-level-badge {
  position: fixed;
  top: 70px;
  left: 20px;
  background: linear-gradient(135deg, #667eea, #764ba2);
  color: white;
  padding: 12px 20px;
  border-radius: 15px;
  font-size: 0.85rem;
  box-shadow: 0 4px 15px rgba(102, 126, 234, 0.4);
  min-width: 200px;
  z-index: 1000;
}

.level-info {
  display: flex;
  justify-content: space-between;
  align-items: center;
  margin-bottom: 8px;
}

.level-number {
  font-weight: 700;
  font-size: 1.1rem;
}

.level-title {
  font-size: 0.8rem;
  opacity: 0.9;
}

.xp-bar {
  height: 8px;
  background: rgba(0, 0, 0, 0.2);
  border-radius: 4px;
  overflow: hidden;
  margin-bottom: 4px;
}

.xp-fill {
  height: 100%;
  background: linear-gradient(90deg, #4CAF50, #8BC34A);
  transition: width 0.5s ease;
  box-shadow: 0 0 10px rgba(76, 175, 80, 0.5);
}

.xp-text {
  font-size: 0.75rem;
  text-align: center;
  opacity: 0.9;
}

/* Mobile responsive */
@media (max-width: 768px) {
  .streak-banner, .user-level-badge {
    position: static;
    margin: 10px;
    display: inline-block;
  }
}
</style>
```

### Step 5: Add Level-Up Celebration (15 minutes)

Add confetti library to `views/layout.erb` before `</body>`:

```html
<!-- Confetti for celebrations -->
<script src="https://cdn.jsdelivr.net/npm/canvas-confetti@1.5.1/dist/confetti.browser.min.js"></script>

<script>
// Check for level up
<% if session[:last_xp_gain] && session[:last_xp_gain][:leveled_up] %>
  // Celebrate level up!
  setTimeout(() => {
    const duration = 3 * 1000;
    const animationEnd = Date.now() + duration;
    const defaults = { startVelocity: 30, spread: 360, ticks: 60, zIndex: 9999 };

    function randomInRange(min, max) {
      return Math.random() * (max - min) + min;
    }

    const interval = setInterval(function() {
      const timeLeft = animationEnd - Date.now();

      if (timeLeft <= 0) {
        return clearInterval(interval);
      }

      const particleCount = 50 * (timeLeft / duration);
      
      confetti(Object.assign({}, defaults, {
        particleCount,
        origin: { x: randomInRange(0.1, 0.3), y: Math.random() - 0.2 }
      }));
      confetti(Object.assign({}, defaults, {
        particleCount,
        origin: { x: randomInRange(0.7, 0.9), y: Math.random() - 0.2 }
      }));
    }, 250);
    
    // Show level up toast
    alert('🎉 LEVEL UP! You are now level <%= session[:last_xp_gain][:level] %> - <%= session[:last_xp_gain][:title] %>!');
  }, 500);
  
  <% session.delete(:last_xp_gain) %>
<% end %>

// Milestone celebration
<% if @streak_data && @streak_data[:milestone] %>
  setTimeout(() => {
    confetti({
      particleCount: 100,
      spread: 70,
      origin: { y: 0.6 }
    });
  }, 500);
<% end %>
</script>
```

### Step 6: Add Leaderboard Page (30 minutes)

Create `views/leaderboard.erb`:

```html
<!DOCTYPE html>
<html>
<head>
  <title>Weekly Leaderboard - Meme Explorer</title>
</head>
<body>
  <div class="leaderboard-container">
    <h1>🏆 Weekly Challenge</h1>
    
    <% if @challenge %>
      <div class="challenge-card">
        <h2><%= @challenge["description"] %></h2>
        <p>Reward: <strong><%= @challenge["reward_xp"] %> XP</strong></p>
        <p>Ends: <%= Date.parse(@challenge["ends_at"].to_s).strftime("%B %d, %Y") %></p>
      </div>
    <% end %>
    
    <h2>Top 10 Players</h2>
    <div class="leaderboard-list">
      <% @leaderboard.each_with_index do |entry, index| %>
        <div class="leaderboard-entry <%= 'highlight' if @user_rank && entry['user_id'] == @user_rank['user_id'] %>">
          <span class="rank">
            <% if index == 0 %>🥇
            <% elsif index == 1 %>🥈
            <% elsif index == 2 %>🥉
            <% else %>#<%= entry["rank"] %>
            <% end %>
          </span>
          <span class="username"><%= entry["reddit_username"] || entry["email"]&.split("@")&.first || "User #{entry['user_id']}" %></span>
          <span class="level">Lv. <%= entry["level"] || 1 %></span>
          <span class="score"><%= entry["metric_value"] %> pts</span>
        </div>
      <% end %>
    </div>
    
    <% if @user_rank %>
      <div class="my-rank">
        <h3>Your Rank</h3>
        <p>Position: <strong>#<%= @user_rank["rank"] %></strong></p>
        <p>Score: <strong><%= @user_rank["metric_value"] %> points</strong></p>
      </div>
    <% end %>
    
    <a href="/random" class="btn-back">Back to Memes</a>
  </div>
  
  <style>
    .leaderboard-container {
      max-width: 800px;
      margin: 50px auto;
      padding: 20px;
    }
    
    .challenge-card {
      background: linear-gradient(135deg, #667eea, #764ba2);
      color: white;
      padding: 30px;
      border-radius: 15px;
      margin-bottom: 30px;
      text-align: center;
    }
    
    .leaderboard-entry {
      display: flex;
      justify-content: space-between;
      align-items: center;
      padding: 15px 20px;
      background: white;
      border-radius: 10px;
      margin-bottom: 10px;
      box-shadow: 0 2px 8px rgba(0,0,0,0.1);
    }
    
    .leaderboard-entry.highlight {
      background: #fff3cd;
      border: 2px solid #ffc107;
    }
    
    .rank {
      font-size: 1.5rem;
      font-weight: 700;
      min-width: 60px;
    }
    
    .username {
      flex: 1;
      font-weight: 600;
    }
    
    .my-rank {
      background: #f8f9fa;
      padding: 20px;
      border-radius: 10px;
      margin-top: 30px;
    }
    
    .btn-back {
      display: inline-block;
      margin-top: 20px;
      padding: 12px 30px;
      background: #667eea;
      color: white;
      text-decoration: none;
      border-radius: 8px;
      font-weight: 600;
    }
  </style>
</body>
</html>
```

Add route to `app.rb`:

```ruby
get "/leaderboard" do
  @challenge = current_weekly_challenge
  @leaderboard = get_leaderboard
  @user_rank = nil
  
  if session[:user_id]
    @user_rank = get_my_rank(session[:user_id])
  end
  
  erb :leaderboard
end
```

---

## 🧪 TESTING (15 minutes)

### Test Streaks:
1. Log in as a user
2. Visit `/random` - should see "✨ Welcome! Start your streak today!"
3. Refresh page - should show "🔥 1 day streak"
4. Manually update database to test different scenarios:
```sql
UPDATE user_streaks SET last_visit_date = date('now', '-1 day') WHERE user_id = 1;
-- Then visit page to see streak increase
```

### Test XP:
1. Like a meme - should see XP gain
2. Save a meme - should see XP gain
3. Check profile to see level progress

### Test Leaderboard:
1. Visit `/leaderboard`
2. Should see current week's challenge
3. Like multiple memes to increase your score
4. Refresh to see rank update

---

## 📊 VERIFY IT'S WORKING

Run these queries to check data:

```bash
sqlite3 memes.db "SELECT * FROM user_streaks;"
sqlite3 memes.db "SELECT * FROM user_levels;"
sqlite3 memes.db "SELECT * FROM meme_collections;"
sqlite3 memes.db "SELECT * FROM weekly_leaderboard;"
```

---

## 🎯 EXPECTED RESULTS

After implementation:
- ✅ Users see streak counter on every page
- ✅ Users see level badge showing progress
- ✅ Confetti animation on level-ups
- ✅ Leaderboard shows top players
- ✅ XP awarded for likes and saves
- ✅ Collections tracking in background

---

## 🚀 LAUNCH CHECKLIST

- [ ] Database migration complete
- [ ] Helpers integrated into app.rb
- [ ] UI elements added to layout
- [ ] Leaderboard page created
- [ ] XP rewards wired up
- [ ] Tested streak tracking
- [ ] Tested level-ups
- [ ] Mobile responsiveness checked
- [ ] Ready to deploy!

---

## 📈 MONITOR THESE METRICS

After launch, track:
- Daily Active Users (DAU)
- 7-day retention rate
- Average session time
- Likes per user
- Saves per user
- Users with 7+ day streaks

**Expected improvements within 2 weeks:**
- +30% DAU
- +50% 7-day retention
- +40% session time

---

## 🐛 TROUBLESHOOTING

**Streak not showing?**
- Check if user_id is in session
- Verify user_streaks table has data
- Check browser console for errors

**XP not adding?**
- Verify gamification_helpers is required
- Check if helpers module is included
- Look for error messages in logs

**Level badge not appearing?**
- Verify `@user_level` is set in before filter
- Check if user_levels table has data
- Inspect element to see if CSS is loaded

---

**Time to ship: 2-3 hours from now! 🚀**

Questions? Check `ADDICTIVE_FEATURES_GUIDE.md` for detailed implementation examples.
