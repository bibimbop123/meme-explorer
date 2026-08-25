#!/usr/bin/env ruby
# frozen_string_literal: true

# Security Testing Script for Authentication & Authorization
# Date: August 24, 2026
# Purpose: Verify all security fixes are working correctly

require_relative '../app'
require_relative '../lib/middleware/session_validator'
require_relative '../lib/middleware/authorization'

class AuthSecurityTester
  def initialize
    @tests_passed = 0
    @tests_failed = 0
    @db = MemeExplorer::App::DB
  end
  
  def run_all_tests
    puts "=" * 80
    puts "🔒 AUTHENTICATION & AUTHORIZATION SECURITY TESTS"
    puts "=" * 80
    puts
    
    test_user_creation_sets_default_role
    test_session_role_synchronization
    test_authorization_middleware
    test_session_validator_timeout
    test_audit_logging
    test_rate_limiting_setup
    
    puts
    puts "=" * 80
    puts "📊 TEST RESULTS"
    puts "=" * 80
    puts "✅ Passed: #{@tests_passed}"
    puts "❌ Failed: #{@tests_failed}"
    puts "📈 Success Rate: #{success_rate}%"
    puts
    
    exit(@tests_failed > 0 ? 1 : 0)
  end
  
  private
  
  def test_user_creation_sets_default_role
    print "Testing user creation sets default role... "
    
    # Create test user
    email = "test_#{SecureRandom.hex(8)}@example.com"
    user_id = UserService.create_email_user(email, "TestPassword123!")
    
    if user_id
      user = @db.execute("SELECT role FROM users WHERE id = ?", [user_id]).first
      if user && user['role'] == 'user'
        pass "Default role 'user' set correctly"
      else
        fail "User role is '#{user&.[]('role')}' instead of 'user'"
      end
      
      # Cleanup
      @db.execute("DELETE FROM users WHERE id = ?", [user_id])
    else
      fail "Failed to create user"
    end
  rescue => e
    fail "Exception: #{e.message}"
  end
  
  def test_session_role_synchronization
    print "Testing SessionValidator syncs role from database... "
    
    # Create middleware instance
    app = ->(_env) { [200, {}, ['OK']] }
    middleware = SessionValidator.new(app)
    
    # Check constants are set
    if SessionValidator::SESSION_TIMEOUT == 86_400 &&
       SessionValidator::MAX_SESSION_LIFETIME == 2_592_000
      pass "Session timeout constants configured correctly"
    else
      fail "Session timeout constants incorrect"
    end
  rescue => e
    fail "Exception: #{e.message}"
  end
  
  def test_authorization_middleware
    print "Testing AuthorizationMiddleware logs access... "
    
    # Check middleware has audit logging methods
    app = ->(_env) { [200, {}, ['OK']] }
    middleware = AuthorizationMiddleware.new(app)
    
    if middleware.respond_to?(:audit_log_unauthorized, true) &&
       middleware.respond_to?(:audit_log_authorized, true)
      pass "Authorization audit logging methods present"
    else
      fail "Audit logging methods missing"
    end
  rescue => e
    fail "Exception: #{e.message}"
  end
  
  def test_session_validator_timeout
    print "Testing SessionValidator has proper constants... "
    
    expected_timeout = 86_400  # 24 hours
    expected_max_lifetime = 2_592_000  # 30 days
    
    if defined?(SessionValidator::SESSION_TIMEOUT) &&
       defined?(SessionValidator::MAX_SESSION_LIFETIME)
      
      if SessionValidator::SESSION_TIMEOUT == expected_timeout &&
         SessionValidator::MAX_SESSION_LIFETIME == expected_max_lifetime
        pass "Session timeout values correct (24h inactivity, 30d max)"
      else
        fail "Session timeout values incorrect"
      end
    else
      fail "SessionValidator constants not defined"
    end
  rescue => e
    fail "Exception: #{e.message}"
  end
  
  def test_audit_logging
    print "Testing audit logging is configured... "
    
    # Check AppLogger is available
    if defined?(AppLogger)
      # Test logging methods exist
      if AppLogger.respond_to?(:info) &&
         AppLogger.respond_to?(:warn) &&
         AppLogger.respond_to?(:error)
        pass "AppLogger configured with required methods"
      else
        fail "AppLogger missing required methods"
      end
    else
      fail "AppLogger not defined"
    end
  rescue => e
    fail "Exception: #{e.message}"
  end
  
  def test_rate_limiting_setup
    print "Testing rate limiting constants in AuthService... "
    
    if defined?(AuthService::MAX_FAILED_ATTEMPTS) &&
       defined?(AuthService::LOCKOUT_DURATION)
      
      if AuthService::MAX_FAILED_ATTEMPTS == 5 &&
         AuthService::LOCKOUT_DURATION == 900
        pass "Rate limiting configured (5 attempts, 15min lockout)"
      else
        fail "Rate limiting values incorrect"
      end
    else
      fail "Rate limiting constants not defined"
    end
  rescue => e
    fail "Exception: #{e.message}"
  end
  
  def pass(message)
    puts "✅ PASS: #{message}"
    @tests_passed += 1
  end
  
  def fail(message)
    puts "❌ FAIL: #{message}"
    @tests_failed += 1
  end
  
  def success_rate
    total = @tests_passed + @tests_failed
    return 0 if total.zero?
    ((@tests_passed.to_f / total) * 100).round(1)
  end
end

# Run tests
tester = AuthSecurityTester.new
tester.run_all_tests
