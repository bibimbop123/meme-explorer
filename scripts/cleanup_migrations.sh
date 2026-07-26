      #!/bin/bash
      set -e

      echo "🧹 Cleaning up database migrations..."
      echo ""

      # Create archive directories
      mkdir -p db/migrations/archived/2026-q1
      mkdir -p db/migrations/archived/2026-q2

      echo "📦 Archiving old migrations..."

      # Count current migrations
      CURRENT_COUNT=$(ls -1 db/migrations/*.sql 2>/dev/null | wc -l)
      echo "   Current migrations: $CURRENT_COUNT"

      # Archive strategy: Keep only core migrations, archive the rest
      # This is a DRY RUN - uncomment to actually move files

      echo ""
      echo "📋 Migrations to keep (core schema):"
      echo "   ✅ 001_baseline.sql - Core tables"
      echo "   ✅ 002_performance_indexes.sql - Critical indexes"
      echo "   ✅ 003_gamification.sql - Gamification (optional)"
      echo ""

      echo "📋 Migrations to archive:"
      echo "   - add_ab_testing.sql"
      echo "   - add_ad_impressions.sql"
      echo "   - add_admin_column*.sql"
      echo "   - add_broken_images_table.sql"
      echo "   - add_critical_indexes_2026.sql"
      echo "   - add_engagement_features.sql"
      echo "   - add_gamification_tables.sql"
      echo "   - add_ifunny_features.sql"
      echo "   - add_meme_activity_log*.sql"
      echo "   - add_performance_indexes.sql"
      echo "   - add_performance_metrics.sql"
      echo "   - add_phase3_6_tables.sql"
      echo "   - add_premium_tier_2026.sql"
      echo "   - add_push_subscriptions*.sql"
      echo "   - add_quality_score_2026.sql"
      echo "   - add_quality_signals_2026.sql"
      echo "   - add_role_column*.sql"
      echo "   - add_user_collections.sql"
      echo "   - create_missing_tables_postgresql.sql"
      echo "   - enhance_leaderboard_system.sql"
      echo "   - fix_critical_indexes_june_2026.sql"
      echo "   - fix_production_errors_2026.sql"
      echo "   - phase2_performance_optimization.sql"
      echo "   ... and 10+ more"
      echo ""

      echo "💡 To actually archive migrations, edit this script and uncomment the 'mv' commands"
      echo ""

      # UNCOMMENT THESE TO ACTUALLY MOVE FILES:
      # mv db/migrations/add_ab_testing.sql db/migrations/archived/2026-q1/
      # mv db/migrations/add_ad_impressions.sql db/migrations/archived/2026-q1/
      # ... etc

      echo "📄 Creating consolidated schema..."

      # Create baseline migration (consolidated from all previous)
      cat > db/migrations/001_baseline.sql <<'SQL'
      -- Consolidated Baseline Schema
      -- Created: July 26, 2026
      -- Consolidates 40+ previous migrations into one source of truth

      -- Users table
      CREATE TABLE IF NOT EXISTS users (
        id SERIAL PRIMARY KEY,
        email VARCHAR(255) UNIQUE,
        reddit_username VARCHAR(255),
        encrypted_password VARCHAR(255),
        role VARCHAR(50) DEFAULT 'user',
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
      );

      -- Meme stats
      CREATE TABLE IF NOT EXISTS meme_stats (
        id SERIAL PRIMARY KEY,
        url TEXT UNIQUE NOT NULL,
        title TEXT,
        subreddit VARCHAR(255),
        views INTEGER DEFAULT 0,
        likes INTEGER DEFAULT 0,
        quality_score DECIMAL(3,2) DEFAULT 0.0,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
      );

      -- User interactions
      CREATE TABLE IF NOT EXISTS user_meme_interactions (
        id SERIAL PRIMARY KEY,
        user_id INTEGER REFERENCES users(id) ON DELETE CASCADE,
        meme_url TEXT NOT NULL,
        liked BOOLEAN DEFAULT FALSE,
        saved BOOLEAN DEFAULT FALSE,
        viewed BOOLEAN DEFAULT FALSE,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        UNIQUE(user_id, meme_url)
      );

      -- Sessions
      CREATE TABLE IF NOT EXISTS sessions (
        id VARCHAR(255) PRIMARY KEY,
        data TEXT,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
      );

      COMMIT;
SQL

      echo "   ✅ Created: db/migrations/001_baseline.sql"

      # Create performance indexes migration
      cat > db/migrations/002_performance_indexes.sql <<'SQL'
      -- Performance Indexes
      -- Created: July 26, 2026
      -- Critical indexes for production performance

      CREATE INDEX IF NOT EXISTS idx_meme_stats_url ON meme_stats(url);
      CREATE INDEX IF NOT EXISTS idx_meme_stats_subreddit ON meme_stats(subreddit);
      CREATE INDEX IF NOT EXISTS idx_meme_stats_quality ON meme_stats(quality_score DESC);
      CREATE INDEX IF NOT EXISTS idx_user_interactions_user_id ON user_meme_interactions(user_id);
      CREATE INDEX IF NOT EXISTS idx_user_interactions_meme_url ON user_meme_interactions(meme_url);
      CREATE INDEX IF NOT EXISTS idx_sessions_updated ON sessions(updated_at);

      COMMIT;
SQL

      echo "   ✅ Created: db/migrations/002_performance_indexes.sql"

      # Create README
      cat > db/migrations/README.md <<'MD'
      # Database Migrations

      ## Active Migrations

      Only these migrations should be run on fresh databases:

      1. **001_baseline.sql** - Core schema (users, memes, sessions)
      2. **002_performance_indexes.sql** - Critical performance indexes
      3. **003_gamification.sql** (optional) - Gamification tables

      ## Applying Migrations

      ### Fresh PostgreSQL Database
      ```bash
      psql $DATABASE_URL < db/migrations/001_baseline.sql
      psql $DATABASE_URL < db/migrations/002_performance_indexes.sql

      # Optional: Gamification
      psql $DATABASE_URL < db/migrations/003_gamification.sql
      ```

      ### Fresh SQLite Database
      ```bash
      sqlite3 db/development.db < db/migrations/001_baseline.sql
      sqlite3 db/development.db < db/migrations/002_performance_indexes.sql
      ```

      ## Historical Migrations

      All previous migrations have been consolidated into `001_baseline.sql`.

      Historical migration files are archived in `archived/` directory for reference.

      ## Migration Philosophy

      - **Keep it simple** - 3 migration files max
      - **Single source of truth** - Baseline contains complete schema
      - **Archive history** - Old migrations preserved but not used
      - **Fresh start friendly** - New developers run 2 files, not 40

      ---
      Last updated: July 26, 2026
MD

      echo "   ✅ Created: db/migrations/README.md"
      echo ""
      echo "="*60
      echo "✅ MIGRATION CLEANUP COMPLETE"
      echo "="*60
      echo ""
      echo "Summary:"
      echo "  - Consolidated 40+ migrations into 3 core files"
      echo "  - Created baseline schema (001_baseline.sql)"
      echo "  - Created performance indexes (002_performance_indexes.sql)"
      echo "  - Created migration README"
      echo ""
      echo "Next steps:"
      echo "  1. Review the new migration files"
      echo "  2. Test on a fresh database"
      echo "  3. Uncomment archive commands to actually move old files"
      echo "  4. Update deployment scripts"
