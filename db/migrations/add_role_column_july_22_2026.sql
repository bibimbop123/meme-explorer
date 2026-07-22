-- Add role column to users table
-- Date: July 22, 2026
-- Purpose: Enable admin access functionality

-- Add role column with default value 'user'
ALTER TABLE users 
ADD COLUMN IF NOT EXISTS role VARCHAR(50) DEFAULT 'user' NOT NULL;

-- Create index on role for faster admin checks
CREATE INDEX IF NOT EXISTS idx_users_role ON users(role);

-- Update any existing NULL roles to 'user'
UPDATE users SET role = 'user' WHERE role IS NULL;

-- Verify column was added
SELECT column_name, data_type, column_default 
FROM information_schema.columns 
WHERE table_name = 'users' AND column_name = 'role';
