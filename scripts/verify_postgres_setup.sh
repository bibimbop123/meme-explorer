#!/bin/bash

# PostgreSQL Migration Verification Script
# Verifies PostgreSQL is ready before running migration

set -e

echo "🔍 PostgreSQL Migration Verification"
echo "===================================="
echo ""

# Check 1: PostgreSQL installed
echo "1️⃣  Checking PostgreSQL installation..."
if ! command -v psql &> /dev/null; then
    echo "❌ PostgreSQL not found"
    echo "Install: brew install postgresql"
    exit 1
fi
echo "✅ PostgreSQL installed: $(psql --version)"
echo ""

# Check 2: PostgreSQL server running
echo "2️⃣  Checking PostgreSQL server..."
if ! pg_isready > /dev/null 2>&1; then
    echo "⚠️  PostgreSQL not running"
    echo "Start: brew services start postgresql"
    exit 1
fi
echo "✅ PostgreSQL is running"
echo ""

# Check 3: Can connect
echo "3️⃣  Testing connection..."
if ! psql -U postgres -d postgres -c "SELECT 1" > /dev/null 2>&1; then
    echo "❌ Cannot connect to PostgreSQL"
    exit 1
fi
echo "✅ Connection successful"
echo ""

# Check 4: Migration script exists
echo "4️⃣  Checking migration script..."
if [ ! -f "db/migrate_sqlite_to_postgres.rb" ]; then
    echo "❌ Migration script not found"
    exit 1
fi
echo "✅ Migration script found"
echo ""

# Check 5: Required gems
echo "5️⃣  Checking 'pg' gem..."
if ! bundle list | grep -q "pg"; then
    echo "⚠️  'pg' gem not installed"
    echo "Run: bundle install"
    exit 1
fi
echo "✅ 'pg' gem installed"
echo ""

# Check 6: SQLite database exists
echo "6️⃣  Checking SQLite source database..."
if [ ! -f "db/memes.db" ]; then
    echo "❌ SQLite database not found at db/memes.db"
    exit 1
fi
echo "✅ SQLite database found"
echo ""

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "✅ ALL CHECKS PASSED"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "Next step: Run migration"
echo "ruby db/migrate_sqlite_to_postgres.rb"
echo ""
