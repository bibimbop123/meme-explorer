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
