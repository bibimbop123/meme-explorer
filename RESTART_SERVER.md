# 🔄 Server Restart Required

**Database changes have been made** - the server must be restarted to pick them up.

---

## ⚠️ Important: Restart Your Server

The `users` table and `reddit_email` column have been added to the database, but your running server instance is still using the old database connection that was established before these changes.

### How to Restart:

**Step 1: Stop the current server**
```bash
# In the terminal where the server is running:
Press Ctrl+C
```

**Step 2: Start the server again**
```bash
cd /Users/brian/DiscoveryPartnersInstitute/meme-explorer
bundle exec rackup -p 8080
```

**Step 3: Verify it's working**
```bash
# In a new terminal, test the database connection:
cd /Users/brian/DiscoveryPartnersInstitute/meme-explorer
sqlite3 memes.db "SELECT COUNT(*) FROM users;"
# Should output: 0
```

**Step 4: Visit the leaderboard**
```
Open browser to: http://localhost:8080/leaderboard
Should show: "No Rankings Yet - Be the first to climb the leaderboard!"
```

---

## 🧪 After Restart: Test It Works

### Create a test user:
1. Go to http://localhost:8080/signup
2. Sign up with any email/password
3. Like a meme to earn XP
4. Visit http://localhost:8080/leaderboard
5. You should see your user ranked!

---

## 🔍 Check Server Logs

After restarting, watch the server logs for:
```
✅ Good signs:
- "🏆 [LEADERBOARD] Route accessed"
- "🏆 [LEADERBOARD] Got X entries"

❌ Bad signs:
- "Error: no such table: users"
- "Error: no such column: reddit_email"

If you see errors, share them and I'll help debug.
```

---

## 💡 Why Restart is Required

The server establishes a database connection when it starts. Our changes were made directly to the SQLite database file (`memes.db`), but the running server process doesn't know about them yet. Restarting the server forces it to reconnect to the database and see the new schema.

---

**After restarting, the leaderboard will work correctly!** 🎉
