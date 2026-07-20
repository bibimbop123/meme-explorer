-- Add admin column to users table
-- Part of Code Audit Week 1 fixes (P0-5)
-- Created: July 19, 2026

-- For PostgreSQL
ALTER TABLE users ADD COLUMN IF NOT EXISTS admin BOOLEAN DEFAULT FALSE;

-- Create index for faster admin lookups
CREATE INDEX IF NOT EXISTS idx_users_admin ON users(admin) WHERE admin = TRUE;

-- Add comment
COMMENT ON COLUMN users.admin IS 'Role-based access control flag for admin users';

-- For SQLite (commented out, uncomment if using SQLite)
-- ALTER TABLE users ADD COLUMN admin INTEGER DEFAULT 0;
-- CREATE INDEX IF NOT EXISTS idx_users_admin ON users(admin) WHERE admin = 1;
