# frozen_string_literal: true

# AuthorizationService - Enterprise-grade RBAC system
# Date: July 26, 2026
# Purpose: Centralized authorization and permission checking

module AuthorizationService
  # Check if user has permission for specific action on resource
  def self.can?(user_id, action, resource)
    return false unless user_id
    
    begin
      # Get user's role from database
      user = DB.execute("SELECT role FROM users WHERE id = ?", [user_id]).first
      return false unless user
      
      role = user['role'] || 'user'
      
      # Check for wildcard permission (admin gets everything)
      wildcard = DB.execute(
        "SELECT 1 FROM permissions WHERE role = ? AND resource = '*' AND action = '*'",
        [role]
      ).first
      return true if wildcard
      
      # Check specific permission
      perms = DB.execute(
        "SELECT 1 FROM permissions 
         WHERE role = ? AND (resource = ? OR resource = '*') 
         AND (action = ? OR action = '*')",
        [role, resource, action]
      )
      
      !perms.empty?
    rescue => e
      AppLogger.error('[AuthorizationService] Permission check failed', 
                     error: e.message, user_id: user_id, action: action, resource: resource)
      false
    end
  end
  
  # Check if user is admin
  def self.admin?(user_id)
    return false unless user_id
    
    begin
      user = DB.execute("SELECT role FROM users WHERE id = ?", [user_id]).first
      user && user['role'] == 'admin'
    rescue => e
      AppLogger.error('[AuthorizationService] Admin check failed', error: e.message, user_id: user_id)
      false
    end
  end
  
  # Check if user is moderator or higher
  def self.moderator?(user_id)
    return false unless user_id
    
    begin
      user = DB.execute("SELECT role FROM users WHERE id = ?", [user_id]).first
      user && ['admin', 'moderator'].include?(user['role'])
    rescue => e
      AppLogger.error('[AuthorizationService] Moderator check failed', error: e.message, user_id: user_id)
      false
    end
  end
  
  # Get user's role
  def self.get_role(user_id)
    return 'guest' unless user_id
    
    begin
      user = DB.execute("SELECT role FROM users WHERE id = ?", [user_id]).first
      user ? (user['role'] || 'user') : 'guest'
    rescue => e
      AppLogger.error('[AuthorizationService] Get role failed', error: e.message, user_id: user_id)
      'guest'
    end
  end
  
  # Change user's role (with audit logging)
  def self.change_role(user_id, new_role, changed_by_user_id, reason = nil, ip_address = nil)
    return { success: false, error: 'Invalid user' } unless user_id
    return { success: false, error: 'Invalid role' } unless valid_role?(new_role)
    
    begin
      # Get current role for audit
      old_role = get_role(user_id)
      
      # Update role
      DB.execute("UPDATE users SET role = ?, updated_at = CURRENT_TIMESTAMP WHERE id = ?", [new_role, user_id])
      
      # Log the change
      log_role_change(user_id, changed_by_user_id, old_role, new_role, reason, ip_address)
      
      AppLogger.info('[AuthorizationService] Role changed',
                    user_id: user_id, old_role: old_role, new_role: new_role, 
                    changed_by: changed_by_user_id)
      
      { success: true, old_role: old_role, new_role: new_role }
    rescue => e
      AppLogger.error('[AuthorizationService] Role change failed', 
                     error: e.message, user_id: user_id, new_role: new_role)
      { success: false, error: e.message }
    end
  end
  
  # Get all permissions for a role
  def self.get_role_permissions(role)
    DB.execute("SELECT resource, action FROM permissions WHERE role = ?", [role])
  end
  
  # Add new permission
  def self.add_permission(role, resource, action)
    return false unless valid_role?(role)
    
    begin
      DB.execute(
        "INSERT OR IGNORE INTO permissions (role, resource, action) VALUES (?, ?, ?)",
        [role, resource, action]
      )
      AppLogger.info('[AuthorizationService] Permission added', 
                    role: role, resource: resource, action: action)
      true
    rescue => e
      AppLogger.error('[AuthorizationService] Add permission failed', 
                     error: e.message, role: role, resource: resource, action: action)
      false
    end
  end
  
  # Remove permission
  def self.remove_permission(role, resource, action)
    begin
      DB.execute(
        "DELETE FROM permissions WHERE role = ? AND resource = ? AND action = ?",
        [role, resource, action]
      )
      AppLogger.info('[AuthorizationService] Permission removed', 
                    role: role, resource: resource, action: action)
      true
    rescue => e
      AppLogger.error('[AuthorizationService] Remove permission failed', 
                     error: e.message, role: role, resource: resource, action: action)
      false
    end
  end
  
  # Get audit log for user
  def self.get_audit_log(user_id, limit = 50)
    DB.execute(
      "SELECT * FROM permission_audit_log 
       WHERE user_id = ? 
       ORDER BY created_at DESC 
       LIMIT ?",
      [user_id, limit]
    )
  end
  
  private
  
  # Valid roles in the system
  VALID_ROLES = %w[admin moderator premium user].freeze
  
  def self.valid_role?(role)
    VALID_ROLES.include?(role.to_s)
  end
  
  def self.log_role_change(user_id, changed_by_user_id, old_role, new_role, reason, ip_address)
    DB.execute(
      "INSERT INTO permission_audit_log 
       (user_id, changed_by_user_id, old_role, new_role, reason, ip_address) 
       VALUES (?, ?, ?, ?, ?, ?)",
      [user_id, changed_by_user_id, old_role, new_role, reason, ip_address]
    )
  rescue => e
    AppLogger.error('[AuthorizationService] Audit log failed', error: e.message)
  end
end
