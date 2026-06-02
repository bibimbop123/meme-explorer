# 🚀 Production Readiness Guide
## Meme Explorer - Complete Path to 100% Production Ready

**Date:** June 2, 2026  
**Current Status:** 77% Production Ready  
**Target:** 100% Production Ready  
**Timeline:** 2-3 weeks

---

## 📊 Executive Summary

### What's Done ✅
- CSRF Protection (Rack::CSRF)
- Database Indexes (12 critical indexes)
- Test Coverage (85%)
- Duplicate Files Cleaned
- Thread Pool Management
- Rate Limiting

### What Remains ⚠️
1. **PostgreSQL Migration** (P0 - CRITICAL)
2. **app.rb Refactoring** (P1 - HIGH)
3. **Input Validation** (P2 - MEDIUM)
4. **Enhanced Monitoring** (P2 - MEDIUM)

---

## 🎯 PHASE 1: PostgreSQL Migration (Week 1)
### Priority: P0 - CRITICAL FOR SCALING

**Why This Matters:**  
SQLite has a hard limit of ~1000 concurrent connections. Beyond that, your app will crash. PostgreSQL is required for production scale.

---

### DAY 1: Provision PostgreSQL

#### Step 1: Create Database on Render

1. **Log into Render.com**
   - Go to https://dashboard.render.com
   - Click your account dropdown

2. **Create New PostgreSQL Database**
   - Click "New +" button
   - Select "PostgreSQL"
   - Configuration:
     - Name: `meme-explorer-db`
     - Database: `meme_explorer`
     - User: `meme_explorer_user`
     - Region: Same as your web service
     - Plan: **Starter** ($7/month minimum for production)
   - Click "Create Database"

3. **Wait for Provisioning** (2-5 minutes)
   - Status will change from "Creating" to "Available"
   - Note the connection details

#### Step 2: Get Connection Details

On the database page, you'll see:

```
Internal Database URL: 
postgres://user:password@hostname:5432/database

External Database URL:
postgres://user:password@external-hostname:5432/database
```

**Copy the Internal Database URL** (faster, free bandwidth)

#### Step 3: Update Environment Variables

1. **Local Development** - Add to `.env`:
```bash
# PostgreSQL Connection
DATABASE_URL=postgresql://user:password@localhost:5432/meme_explorer_dev

# For production, use Internal URL from Render
# DATABASE_URL=postgres://user:pass@hostname:5432/database
```

2. **Render.com Production** - Add Environment Variable:
   - Go to your web service settings
   - Click "Environment"
   - Add new variable:
     - Key: `DATABASE_URL`
     - Value: (paste Internal Database URL from Step 2)
   - Click "Save Changes"

---

### DAY 2: Update Database Connection Code

#### Step 1: Install PostgreSQL Gem

Update `Gemfile`:
```ruby
# Replace or update:
# gem 'sqlite3'

# With:
gem 'pg', '~> 1.5'
```

Run:
```bash
bundle install
```

#### Step 2: Create New `db/setup.rb`

**Backup current file first:**
```bash
cp db/setup.rb db/setup.rb.backup_sqlite
```

**Replace `db/setup.rb` with:**
```ruby
require "pg"
require "redis"
require "connection_pool"

# Determine database type from environment
DATABASE_URL = ENV.fetch("DATABASE_URL", nil)

if DATABASE_URL&.start_with?("postgres")
  # PostgreSQL Configuration
  puts "🐘 Connecting to PostgreSQL..."
  
  DB_POOL = ConnectionPool.new(size: 25, timeout: 5) do
    PG.connect(DATABASE_URL)
  end
  
  # Wrapper to make ConnectionPool behave like direct DB connection
  DB = Object.new
  def DB.execute(sql, params = [])
    DB_POOL.with do |conn|
      result = if params.empty?
        conn.exec(sql)
      else
        conn.exec_params(sql, params)
      end
      
      # Convert PG::Result to array of hashes (like SQLite)
      result.map { |row| row.transform_keys(&:to_s) }
    end
  end
  
  def DB.transaction
    DB_POOL.with do |conn|
      conn.transaction do
        yield conn
      end
    end
  end
  
  puts "✅ PostgreSQL connected (pool: 25 connections)"
  
else
  # SQLite Configuration (Development/Fallback)
  require "sqlite3"
  
  puts "🗄️  Using SQLite (development mode)..."
  FileUtils.mkdir_p("db") unless Dir.exist?("db")
  
  DB = begin
    db = SQLite3::Database.new("db/memes.db")
    db.results_as_hash = true
    db.busy_timeout = 5000
    db
  rescue => e
    puts "❌ SQLite error: #{e.message}"
    db = SQLite3::Database.new(":memory:")
    db.results_as_hash = true
    db
  end
  
  puts "✅ SQLite connected"
end

# Create tables (PostgreSQL-compatible SQL)
# NOTE: These will be created by migration script, but kept for safety

# Redis
REDIS = begin
  Redis.new(url: ENV.fetch("REDIS_URL", "redis://localhost:6379/0"))
rescue => e
  puts "⚠️ Redis connection warning: #{e.message}"
  nil
end
```

---

### DAY 3: Create Migration Script

Create `scripts/migrate_sqlite_to_postgres.rb`:

```ruby
#!/usr/bin/env ruby

require 'sqlite3'
require 'pg'
require 'dotenv/load'

puts "=" * 60
puts "SQLite → PostgreSQL Migration Script"
puts "=" * 60

# Configuration
SQLITE_DB = "db/memes.db"
POSTGRES_URL = ENV['DATABASE_URL']

unless POSTGRES_URL
  puts "❌ ERROR: DATABASE_URL not set"
  puts "Set it in .env or environment"
  exit 1
end

unless File.exist?(SQLITE_DB)
  puts "❌ ERROR: SQLite database not found at #{SQLITE_DB}"
  exit 1
end

puts "\n📊 Source: #{SQLITE_DB}"
puts "📊 Target: #{POSTGRES_URL.gsub(/:[^:@]+@/, ':****@')}\n\n"

# Connect to databases
sqlite = SQLite3::Database.new(SQLITE_DB)
sqlite.results_as_hash = true
postgres = PG.connect(POSTGRES_URL)

# Tables to migrate
TABLES = %w[
  users
  meme_stats
  saved_memes
  user_meme_stats
  user_subreddit_preferences
  user_meme_exposure
  user_category_preferences
  push_subscriptions
  broken_images
]

# Create tables in PostgreSQL (from schema file)
puts "🔨 Creating PostgreSQL tables..."
schema = File.read("db/postgres_schema.sql")
postgres.exec(schema)
puts "✅ Tables created\n\n"

# Migrate data
TABLES.each do |table|
  print "📦 Migrating #{table}... "
  
  begin
    # Get row count from SQLite
    count = sqlite.get_first_value("SELECT COUNT(*) FROM #{table}")
    
    if count.to_i == 0
      puts "⏭️  Empty (skipped)"
      next
    end
    
    # Fetch all rows
    rows = sqlite.execute("SELECT * FROM #{table}")
    
    if rows.empty?
      puts "⏭️  Empty (skipped)"
      next
    end
    
    # Get column names
    columns = rows.first.keys.reject { |k| k.is_a?(Integer) }
    
    # Insert into PostgreSQL
    inserted = 0
    rows.each do |row|
      values = columns.map { |col| row[col] }
      placeholders = (1..columns.length).map { |i| "$#{i}" }.join(", ")
      
      sql = "INSERT INTO #{table} (#{columns.join(", ")}) VALUES (#{placeholders})"
      
      begin
        postgres.exec_params(sql, values)
        inserted += 1
      rescue PG::UniqueViolation
        # Skip duplicates
      rescue => e
        puts "\n⚠️  Row error: #{e.message}"
      end
    end
    
    puts "✅ #{inserted}/#{count} rows"
    
  rescue => e
    puts "❌ ERROR: #{e.message}"
  end
end

puts "\n" + "=" * 60
puts "Migration Complete!"
puts "=" * 60

# Verify counts
puts "\n📊 Verification:\n\n"
TABLES.each do |table|
  sqlite_count = sqlite.get_first_value("SELECT COUNT(*) FROM #{table}").to_i
  pg_count = postgres.exec("SELECT COUNT(*) FROM #{table}").first['count'].to_i
  
  status = sqlite_count == pg_count ? "✅" : "⚠️ "
  puts "#{status} #{table.ljust(30)} SQLite: #{sqlite_count.to_s.rjust(6)} → PostgreSQL: #{pg_count.to_s.rjust(6)}"
end

sqlite.close
postgres.close

puts "\n✅ Migration script complete!"
puts "📝 Next steps:"
puts "1. Verify data integrity"
puts "2. Test application locally"
puts "3. Deploy to production"
puts "4. Monitor for errors"
```

Make it executable:
```bash
chmod +x scripts/migrate_sqlite_to_postgres.rb
```

---

### DAY 4: Test Migration Locally

#### Step 1: Set Up Local PostgreSQL

**Option A: Install PostgreSQL locally**
```bash
# macOS
brew install postgresql@15
brew services start postgresql@15

# Create database
createdb meme_explorer_dev
```

**Option B: Use Docker**
```bash
docker run -d \
  --name meme-postgres \
  -e POSTGRES_DB=meme_explorer_dev \
  -e POSTGRES_USER=postgres \
  -e POSTGRES_PASSWORD=postgres \
  -p 5432:5432 \
  postgres:15

# Update .env
DATABASE_URL=postgresql://postgres:postgres@localhost:5432/meme_explorer_dev
```

#### Step 2: Run Migration

```bash
# Run migration script
ruby scripts/migrate_sqlite_to_postgres.rb

# Expected output:
# ✅ users: 150/150 rows
# ✅ meme_stats: 5000/5000 rows
# etc.
```

#### Step 3: Test Application

```bash
# Start app
ruby app.rb

# Test in browser
open http://localhost:8080

# Run tests
bundle exec rspec
```

**Verify:**
- [ ] Home page loads
- [ ] Can view memes
- [ ] Can like/save memes
- [ ] Leaderboard works
- [ ] User authentication works
- [ ] All tests pass

---

### DAY 5: Deploy to Production

#### Step 1: Backup Production Data

```bash
# Download current SQLite database
render ssh meme-explorer
sqlite3 db/memes.db .dump > backup_$(date +%Y%m%d).sql
exit

# Or use Render dashboard "Shell" tab and backup
```

#### Step 2: Update Production Code

```bash
git add .
git commit -m "feat: migrate to PostgreSQL"
git push origin main
```

Render will automatically:
1. Detect changes
2. Run `bundle install` (installs pg gem)
3. Restart application
4. Connect to PostgreSQL via DATABASE_URL

#### Step 3: Run Migration on Production

**Option A: Via Render Shell**
```bash
# In Render dashboard, open Shell
ruby scripts/migrate_sqlite_to_postgres.rb
```

**Option B: Via SSH**
```bash
render ssh meme-explorer
ruby scripts/migrate_sqlite_to_postgres.rb
exit
```

#### Step 4: Monitor & Verify

```bash
# Check logs
render logs meme-explorer --tail

# Look for:
# ✅ PostgreSQL connected (pool: 25 connections)
# ✅ No database errors
```

**Verify in production:**
- [ ] Site loads
- [ ] Can browse memes
- [ ] User data intact
- [ ] Leaderboard accurate
- [ ] No errors in logs

---

## 🎯 PHASE 2: app.rb Refactoring (Weeks 2-3)
### Priority: P1 - HIGH (Maintainability)

**Current:** 2,607 lines  
**Target:** < 500 lines  
**Approach:** Incremental extraction over 2-3 weeks

---

### Week 2: Extract Services & Helpers

#### Strategy: 100-200 Lines Per Day

**Day 1: Extract Meme Display Helpers**

Find in `app.rb`:
```ruby
def meme_image_src(meme)
  # 20-30 lines
end

def render_meme_card(meme)
  # 15-20 lines
end
```

Move to `lib/helpers/meme_display_helpers.rb`:
```ruby
module MemeDisplayHelpers
  def meme_image_src(meme)
    # ... existing code
  end
  
  def render_meme_card(meme)
    # ... existing code
  end
end
```

Include in app.rb:
```ruby
helpers MemeDisplayHelpers
```

**Day 2: Extract Gamification Helpers**

Move gamification methods to `lib/helpers/gamification_helpers.rb` (might already exist - consolidate)

**Day 3: Extract Analytics Helpers**

Create `lib/helpers/analytics_helpers.rb` for tracking methods

**Day 4: Extract Formatting Helpers**

Create `lib/helpers/formatting_helpers.rb` for date, number formatting

**Day 5: Review & Test**

- Run full test suite
- Check for missing methods
- Verify no regressions

---

### Week 3: Extract Routes & Final Cleanup

#### Move Remaining Routes

Many routes are already in `routes/` - consolidate remaining ones from app.rb

#### Final app.rb Structure

Target structure (< 500 lines):

```ruby
# app.rb - Configuration & Routing Only

require 'sinatra/base'
# ... other requires

# Load all helpers
Dir[File.join(__dir__, 'lib', 'helpers', '*.rb')].each { |f| require f }

# Load all services  
Dir[File.join(__dir__, 'lib', 'services', '*.rb')].each { |f| require f }

module MemeExplorer
  class App < Sinatra::Base
    # Configuration (100 lines)
    configure do
      # ... settings
    end
    
    # Include helpers (10 lines)
    helpers MemeHelpers
    helpers GamificationHelpers
    # ... etc
    
    # Register routes (50 lines)
    register Routes::Home
    register Routes::Memes
    # ... etc
    
    # Error handlers (20 lines)
    error 404 do
      # ...
    end
    
    # That's it! ~ 200 lines total
  end
end
```

---

## 🎯 PHASE 3: Input Validation (Week 3)
### Priority: P2 - MEDIUM

Create `lib/middleware/input_validator.rb`:

```ruby
class InputValidator
  def initialize(app)
    @app = app
  end
  
  def call(env)
    request = Rack::Request.new(env)
    
    # Validate common parameters
    if request.POST
      validate_params!(request.params)
    end
    
    @app.call(env)
  rescue ValidationError => e
    [400, {'Content-Type' => 'application/json'}, [{error: e.message}.to_json]]
  end
  
  private
  
  def validate_params!(params)
    # URL validation
    if params['url']
      raise ValidationError, "Invalid URL" unless valid_url?(params['url'])
    end
    
    # Integer validation
    if params['limit']
      limit = params['limit'].to_i
      raise ValidationError, "Limit out of range" unless limit.between?(1, 100)
    end
    
    # String sanitization
    if params['query']
      params['query'] = sanitize_string(params['query'])
    end
  end
  
  def valid_url?(url)
    url.match?(/\Ahttps?:\/\/.+\z/)
  end
  
  def sanitize_string(str)
    str.strip.gsub(/<[^>]*>/, '')[0..200]
  end
end

class ValidationError < StandardError; end
```

Add to app.rb:
```ruby
use InputValidator
```

---

## 🎯 PHASE 4: Enhanced Monitoring (Week 3)
### Priority: P2 - MEDIUM

Already have basic monitoring. Enhance it:

### Add Memory Monitoring

Create `lib/middleware/memory_monitor.rb`:

```ruby
class MemoryMonitor
  THRESHOLD_MB = 50
  
  def initialize(app)
    @app = app
  end
  
  def call(env)
    before_memory = get_memory_mb
    
    status, headers, body = @app.call(env)
    
    after_memory = get_memory_mb
    delta = after_memory - before_memory
    
    if delta > THRESHOLD_MB
      warn_memory_spike(env['PATH_INFO'], delta)
    end
    
    [status, headers, body]
  end
  
  private
  
  def get_memory_mb
    `ps -o rss= -p #{Process.pid}`.to_i / 1024.0
  end
  
  def warn_memory_spike(path, delta_mb)
    puts "⚠️  Memory spike: +#{delta_mb.round(1)}MB on #{path}"
    Sentry.capture_message("Memory spike detected", extra: {
      path: path,
      delta_mb: delta_mb
    }) if defined?(Sentry)
  end
end
```

---

## ✅ FINAL CHECKLIST

### Pre-Production
- [ ] PostgreSQL provisioned on Render
- [ ] DATABASE_URL environment variable set
- [ ] Migration script tested locally
- [ ] Migration run on production
- [ ] Data verified (row counts match)
- [ ] All tests passing on PostgreSQL
- [ ] No errors in production logs

### Post-Migration
- [ ] Monitor performance for 24 hours
- [ ] Check error rates
- [ ] Verify response times
- [ ] Test under load
- [ ] Backup strategy in place

### Refactoring (Ongoing)
- [ ] Extract 200 lines per week from app.rb
- [ ] Maintain test coverage above 80%
- [ ] Document each extraction
- [ ] Code review changes

### Production Health
- [ ] Response time P95 < 200ms
- [ ] Error rate < 0.1%
- [ ] Memory stable (no leaks)
- [ ] Database connections healthy
- [ ] Redis operational

---

## 📊 Success Metrics

### Technical
- **Production Readiness:** 77% → 100%
- **app.rb Size:** 2,607 → < 500 lines
- **Database:** SQLite → PostgreSQL
- **Performance:** Stable under 10K concurrent users

### Timeline
- **Week 1:** PostgreSQL migration complete
- **Week 2:** 50% of app.rb refactored
- **Week 3:** 100% production ready

---

## 🆘 Troubleshooting

### PostgreSQL Connection Fails

```ruby
# Check DATABASE_URL format
puts ENV['DATABASE_URL']

# Should be: postgresql://user:pass@host:5432/db
# NOT: postgres:// (some tools use this)
```

### Migration Row Count Mismatch

```bash
# Check for duplicate constraints
# Some rows might be skipped due to UNIQUE violations
# This is normal for some tables
```

### App Crashes After Migration

```bash
# Check logs
render logs meme-explorer --tail

# Common issues:
# 1. SQL syntax differences (SQLite vs PostgreSQL)
# 2. Missing gem: pg
# 3. CONNECTION_URL not set
```

---

## 📞 Support Resources

**Render Documentation:**
- PostgreSQL: https://render.com/docs/databases
- Environment Variables: https://render.com/docs/environment-variables

**PostgreSQL vs SQLite Differences:**
- Use `$1, $2` instead of `?` for parameterized queries in raw SQL
- Use `SERIAL` instead of `AUTOINCREMENT`
- Different date/time functions

**Need Help?**
- Check `render logs meme-explorer`
- Review `QUICK_WINS_COMPLETED_JUNE_2_2026.md`
- Reference existing documentation files

---

**Good luck! 🚀 You've got this.**
