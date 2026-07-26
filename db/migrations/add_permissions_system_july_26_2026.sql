-- Phase 2: Authorization System Migration
-- Date: July 26, 2026
-- Purpose: Add permissions table for Role-Based Access Control (RBAC)

-- Create permissions table
CREATE TABLE IF NOT EXISTS permissions (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  role VARCHAR(50) NOT NULL,
  resource VARCHAR(100) NOT NULL,
  action VARCHAR(50) NOT NULL,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Create index for fast lookups
CREATE INDEX IF NOT EXISTS idx_permissions_role ON permissions(role);
CREATE INDEX IF NOT EXISTS idx_permissions_lookup ON permissions(role, resource, action);

-- Insert default admin permissions
INSERT OR IGNORE INTO permissions (role, resource, action) VALUES
  -- Admin has full access
  ('admin', '*', '*'),
  ('admin', 'users', 'read'),
  ('admin', 'users', 'write'),
  ('admin', 'users', 'delete'),
  ('admin', 'metrics', 'read'),
  ('admin', 'settings', 'write'),
  
  -- Moderator permissions
  ('moderator', 'users', 'read'),
  ('moderator', 'content', 'moderate'),
  ('moderator', 'metrics', 'read'),
  
  -- Premium user permissions
  ('premium', 'content', 'premium_access'),
  ('premium', 'metrics', 'read'),
  
  -- Regular user permissions
  ('user', 'content', 'read'),
  ('user', 'profile', 'write');

-- Create audit log table for tracking permission changes
CREATE TABLE IF NOT EXISTS permission_audit_log (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  user_id INTEGER NOT NULL,
  changed_by_user_id INTEGER,
  old_role VARCHAR(50),
  new_role VARCHAR(50),
  reason TEXT,
  ip_address VARCHAR(45),
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_audit_user_id ON permission_audit_log(user_id);
CREATE INDEX IF NOT EXISTS idx_audit_created_at ON permission_audit_log(created_at);
