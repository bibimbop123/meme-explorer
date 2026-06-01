# PostgreSQL Migration Guide

**Date:** November 2, 2025  
**Objective:** Migrate Meme Explorer from SQLite to PostgreSQL  
**Expected Impact:** 10x concurrent user capacity (100 → 1,000+)  
**Estimated Time:** 12-16 hours

---

## Phase 1: Local Development Setup (2-3 hours)

### Step 1: Install PostgreSQL
```bash
# macOS
brew install postgresql@15

# Start PostgreSQL service
brew services start postgresql@15

# Verify installation
psql --version
```

### Step 2: Create Development Database
```bash
# Create postgres user and database
createuser meme_explorer_dev
createdb -O meme_explorer_dev meme_explorer_dev

# Set password
psql -U postgres
ALTER USER meme_explorer_dev WITH PASSWORD 'dev_password_local';
\q
```

### Step 3: Install pg gem
```bash
bundle install
```

### Step 4: Update .env
```bash
# Add to .env
DATABASE_URL="postgresql://meme_explorer_dev:dev_password_local@localhost:5432/meme_explorer_dev"
DB_TYPE="postgres"  # Add this to switch between sqlite3 and postgres
```

---

## Phase 2: Database Schema Migration (3-4 hours)

### Step 1: Create Migration Script
See `db/migrate_sqlite_to_postgres.rb` for automated migration

### Step 2: Handle SQLite → PostgreSQL Type Conversions

| SQLite | PostgreSQL | Notes |
|--------|-----------|-------|
| INTEGER | INTEGER | Same |
| TEXT | TEXT | Same |
| REAL | DOUBLE PRECISION | Floats |
| BLOB | BYTEA | Binary data |
| TIMESTAMP | TIMESTAMP WITH TIME ZONE | Timezone aware |
| PRIMARY KEY autoincrement | SERIAL or BIGSERIAL | Auto-incrementing |

### Step 3: Create PostgreSQL Tables
```sql
-- users table
CREATE TABLE users (
  id SERIAL PRIMARY KEY,
  reddit_id VARCHAR(255) UNIQUE,
  reddit_username VARCHAR(255),
  reddit_email VARCHAR(255),
  email VARCHAR(255) UNIQUE,
  password_hash VARCHAR(255),
  created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- meme_stats table (critical for Phase 1)
CREATE TABLE meme_stats (
  id SERIAL PRIMARY KEY,
  url TEXT UNIQUE NOT NULL,
  title TEXT,
  subreddit VARCHAR(255),
  likes INTEGER DEFAULT 0,
  views INTEGER DEFAULT 0,
  failure_count INTEGER DEFAULT 0,
  first_failed_at TIMESTAMP,
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Create indexes for performance
CREATE INDEX idx_meme_stats_likes_views ON meme_stats(likes DESC, views DESC);
CREATE INDEX idx_meme_stats_subreddit ON meme_stats(subreddit);
CREATE INDEX idx_meme_stats_updated_at ON meme_stats(updated_at DESC);

-- user_meme_stats table
CREATE TABLE user_meme_stats (
  id SERIAL PRIMARY KEY,
  user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  meme_url TEXT NOT NULL,
  liked INTEGER DEFAULT 0,
  liked_at TIMESTAMP,
  unliked_at TIMESTAMP,
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
  UNIQUE(user_id, meme_url)
);

-- user_meme_exposure table (for Phase 3 spaced repetition)
CREATE TABLE user_meme_exposure (
  id SERIAL PRIMARY KEY,
  user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  meme_url TEXT NOT NULL,
  shown_count INTEGER DEFAULT 1,
  last_shown TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
  UNIQUE(user_id, meme_url)
);

-- user_subreddit_preferences table (Phase 2)
CREATE TABLE user_subreddit_preferences (
  id SERIAL PRIMARY KEY,
  user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  subreddit VARCHAR(255) NOT NULL,
  preference_score DOUBLE PRECISION DEFAULT 1.0,
  times_liked INTEGER DEFAULT 1,
  last_updated TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
  UNIQUE(user_id, subreddit)
);

-- saved_memes table
CREATE TABLE saved_memes (
  id SERIAL PRIMARY KEY,
  user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  meme_url TEXT NOT NULL,
  meme_title TEXT,
  meme_subreddit VARCHAR(255),
  saved_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
  UNIQUE(user_id, meme_url)
);

-- broken_images table
CREATE TABLE broken_images (
  id SERIAL PRIMARY KEY,
  url TEXT UNIQUE NOT NULL,
  failure_count INTEGER DEFAULT 1,
  first_failed_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
  last_failed_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);
```

---

## Phase 3: Update Application Code (3-4 hours)

### Step 1: Update db/setup.rb
```ruby
require "sequel"

# Detect database type from environment
db_type = ENV.fetch("DB_TYPE", "sqlite3")
database_url = ENV.fetch("DATABASE_URL", nil)

if db_type == "postgres" && database_url
  # PostgreSQL
  DB = Sequel.connect(database_url)
  DB.extension :pg_json
else
  # SQLite (default)
  DB = Sequel.connect('sqlite://meme_explorer.db')
end

# Enable results_as_hash for consistency
DB.extension :sqlite if db_type == "sqlite3"
```

### Step 2: Update app.rb Database Initialization
Replace:
```ruby
DB = ::DB
```

With connection pooling:
```ruby
# Connection pooling for multi-worker setup
DB = ::DB
DB.extension :connection_validator
DB.pool.connection_validation_timeout = 15
```

### Step 3: Update Query Syntax
- PostgreSQL uses `RETURNING` instead of `last_insert_id`
- Replace `datetime()` with PostgreSQL functions `NOW()`, `CURRENT_TIMESTAMP`
- Replace SQLite string concatenation with `||` operator

---

## Phase 4: Data Migration (2-3 hours)

### Step 1: Backup SQLite Database
```bash
cp db/memes.db db/memes.db.backup
```

### Step 2: Run Migration Script
```bash
ruby db/migrate_sqlite_to_postgres.rb
```

This script will:
1. Read all tables from SQLite
2. Transform data (type conversions, timestamp formats)
3. Insert into PostgreSQL
4. Verify data integrity

### Step 3: Verify Migration
```bash
# Check row counts
psql -U meme_explorer_dev -d meme_explorer_dev -c "SELECT 'users', COUNT(*) FROM users UNION ALL SELECT 'meme_stats', COUNT(*) FROM meme_stats UNION ALL SELECT 'user_meme_stats', COUNT(*) FROM user_meme_stats;"

# Check sample data
psql -U meme_explorer_dev -d meme_explorer_dev -c "SELECT * FROM meme_stats LIMIT 5;"
```

---

## Phase 5: Testing (2 hours)

### Step 1: Run Test Suite
```bash
DB_TYPE=postgres bundle exec rspec
```

Tests should pass:
- ✅ User authentication
- ✅ Meme navigation
- ✅ Like/unlike
- ✅ Profile access
- ✅ Search

### Step 2: Load Testing
```bash
# Test with 500 concurrent connections
apache2-bench -n 5000 -c 500 http://localhost:3000/random.json
```

Expected: <200ms avg response time

---

## Phase 6: Staging Deployment (2-3 hours)

### Step 1: Create PostgreSQL on Render
1. Go to Render dashboard
2. Create new PostgreSQL database
3. Copy connection string to .env

### Step 2: Deploy Application
```bash
git push origin main  # Triggers GitHub Actions
# → Runs tests
# → Deploys to staging
```

### Step 3: Verify Staging
```bash
# Check staging health
curl https://meme-explorer-staging.onrender.com/health

# Test meme endpoint
curl https://meme-explorer-staging.onrender.com/random.json
```

---

## Phase 7: Production Migration (1-2 hours)

### Step 1: Enable Maintenance Mode
- Set temporary "under maintenance" message
- Redirect users to status page

### Step 2: Create Production Database Backup
```bash
# Export current SQLite
sqlite3 db/memes.db ".dump" > db/backup_production_$(date +%s).sql
```

### Step 3: Deploy to Production
```bash
git push production main
# Application restarts with PostgreSQL
```

### Step 4: Monitor
- Check error rates in Sentry
- Monitor database performance
- Watch for scaling issues

### Step 5: Rollback Plan
If issues occur:
```bash
# Revert to SQLite backup
git revert <commit>
git push production main
# Application restarts with SQLite fallback
```

---

## Performance Improvements Expected

| Metric | SQLite | PostgreSQL | Improvement |
|--------|--------|-----------|------------|
| **Concurrent Users** | 100 | 1,000+ | 10x |
| **Write Throughput** | Sequential | Parallel | 5-10x |
| **Query Performance** | Good for <50 users | Excellent at scale | 2-3x |
| **Connection Pool** | No | Yes (5-20 conns) | ✅ |
| **Replication** | No | Yes | ✅ |
| **Backup Strategy** | File copy | PITR backup | ✅ |

---

## Troubleshooting

### Issue: "SCRAM authentication failed"
**Solution:** Ensure password is set correctly in .env

### Issue: "Connection refused"
**Solution:** Verify PostgreSQL service is running
```bash
brew services list
brew services start postgresql@15
```

### Issue: "Duplicate key value violates unique constraint"
**Solution:** Tables already exist, drop and recreate
```bash
psql -U meme_explorer_dev -d meme_explorer_dev -c "DROP SCHEMA public CASCADE; CREATE SCHEMA public;"
```

### Issue: "Integer out of range"
**Solution:** Use BIGSERIAL instead of SERIAL for high-velocity tables

---

## Success Criteria

- ✅ All tests pass on PostgreSQL
- ✅ Data integrity verified (row counts match)
- ✅ Response times <200ms at 500 concurrent users
- ✅ No errors in Sentry for 24 hours
- ✅ Can handle 1,000+ concurrent users

---

**Next Steps After Migration:**
1. Activate Phase 3 (spaced repetition)
2. Deploy multi-worker setup
3. Enable CDN for images
4. Monitor performance metrics
