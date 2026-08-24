# Week 1 Critical Fixes Execution Plan
**Date:** June 3, 2026  
**Based on:** SENIOR_RUBY_DEV_COMPREHENSIVE_AUDIT_JUNE_2026.md

## Critical Issues to Fix (Prioritized)

### ✅ Fix #1: Replace Thread.new with ANALYTICS_POOL (2 hours)
**Risk:** Production crash under load  
**Files affected:** `app.rb` (lines 1612-1634, 1718-1740)

### ✅ Fix #2: Require SESSION_SECRET in Production (15 minutes)
**Risk:** All sessions invalidated on restart  
**Files affected:** `app.rb` (line 154)

### ✅ Fix #3: Add Structured Logging Infrastructure (4 hours)
**Risk:** Cannot debug production issues  
**Files affected:** New file `lib/app_logger.rb`, update multiple files

### ✅ Fix #4: Remove Unsafe REDIS Constant (4 hours)
**Risk:** Race conditions, data corruption  
**Files affected:** `db/setup.rb`, ~20 files using REDIS constant

---

## Fix #1: Thread Pool Migration

### Current Problem
```ruby
# app.rb lines 1612-1634
Thread.new do
  # Analytics tracking
end
```
Under load, this spawns unlimited threads → memory exhaustion

### Solution
```ruby
# Use existing ANALYTICS_POOL
ANALYTICS_POOL.post do
  # Analytics tracking
end
```

### Files to Update
1. `app.rb` line 1612-1634 (root route)
2. `app.rb` line 1718-1740 (/random route)

---

## Fix #2: Session Secret Production Hardening

### Current Problem
```ruby
# app.rb line 154
set :session_secret, ENV.fetch("SESSION_SECRET", SecureRandom.hex(32))
# Falls back to random secret = all sessions die on restart
```

### Solution
```ruby
configure :production do
  # No fallback in production
  set :session_secret, ENV.fetch("SESSION_SECRET")
end

configure :development, :test do
  set :session_secret, ENV.fetch("SESSION_SECRET", SecureRandom.hex(32))
end
```

---

## Fix #3: Structured Logging

### Current Problem
```ruby
puts "⚠️ Error: #{e.message}"
puts "✅ Success"
```
Not parseable, no log levels, no context

### Solution: Create AppLogger
```ruby
# lib/app_logger.rb
require 'logger'
require 'json'

class AppLogger
  class << self
    def logger
      @logger ||= create_logger
    end
    
    def info(message, **context)
      log(:info, message, context)
    end
    
    def error(message, **context)
      log(:error, message, context)
    end
    
    def warn(message, **context)
      log(:warn, message, context)
    end
    
    def debug(message, **context)
      log(:debug, message, context)
    end
    
    private
    
    def create_logger
      logger = Logger.new(
        ENV['RACK_ENV'] == 'production' ? STDOUT : 'log/app.log',
        level: log_level,
        formatter: log_formatter
      )
      logger.level = log_level
      logger
    end
    
    def log_level
      case ENV.fetch('LOG_LEVEL', 'INFO').upcase
      when 'DEBUG' then Logger::DEBUG
      when 'INFO' then Logger::INFO
      when 'WARN' then Logger::WARN
      when 'ERROR' then Logger::ERROR
      else Logger::INFO
      end
    end
    
    def log_formatter
      proc do |severity, datetime, progname, msg|
        if ENV['RACK_ENV'] == 'production'
          # JSON format for log aggregation
          {
            timestamp: datetime.iso8601,
            severity: severity,
            message: msg.is_a?(String) ? msg : msg.inspect,
            request_id: Thread.current[:request_id],
            environment: ENV['RACK_ENV']
          }.to_json + "\n"
        else
          # Human-readable for development
          "[#{datetime.strftime('%Y-%m-%d %H:%M:%S')}] #{severity}: #{msg}\n"
        end
      end
    end
  end
end
```

---

## Fix #4: Remove Unsafe REDIS Constant

### Current Problem
```ruby
# db/setup.rb line 234
REDIS = REDIS_POOL.with { |conn| conn } rescue nil
# Single connection shared across threads = race conditions
```

### Solution
Remove REDIS constant entirely, use REDIS_POOL.with everywhere

### Search and Replace Strategy
```bash
# Find all REDIS usages (excluding REDIS_POOL)
grep -r "REDIS\." --include="*.rb" | grep -v REDIS_POOL
grep -r "if REDIS" --include="*.rb"
```

### Pattern Replacements
```ruby
# BEFORE
if REDIS
  REDIS.get(key)
end

# AFTER
if defined?(REDIS_POOL)
  REDIS_POOL.with { |redis| redis.get(key) }
end

# BEFORE
REDIS.set(key, value)

# AFTER
REDIS_POOL.with { |redis| redis.set(key, value) }
```

---

## Execution Checklist

### Phase 1: Thread Pool Fix (30 min)
- [ ] Update app.rb root route (line 1612-1634)
- [ ] Update app.rb /random route (line 1718-1740)
- [ ] Test locally
- [ ] Verify ANALYTICS_POOL defined

### Phase 2: Session Secret (15 min)
- [ ] Update app.rb configure blocks
- [ ] Update .env.example with warning
- [ ] Verify SESSION_SECRET in production .env
- [ ] Document in README

### Phase 3: Structured Logging (4 hours)
- [ ] Create lib/app_logger.rb
- [ ] Add to app.rb requires
- [ ] Replace puts in app.rb (50+ occurrences)
- [ ] Replace puts in lib/services (100+ files)
- [ ] Replace puts in routes (26 files)
- [ ] Test log output formats
- [ ] Update .gitignore for log/app.log

### Phase 4: REDIS Migration (4 hours)
- [ ] Identify all REDIS usages (~30 files)
- [ ] Create migration helper method
- [ ] Update lib/services files
- [ ] Update app.rb
- [ ] Remove REDIS constant from db/setup.rb
- [ ] Test Redis operations
- [ ] Update tests

---

## Testing Plan

### Unit Tests
```ruby
# spec/lib/app_logger_spec.rb
RSpec.describe AppLogger do
  it 'logs at correct level' do
    expect { AppLogger.info('test') }.not_to raise_error
  end
  
  it 'includes context in logs' do
    expect { AppLogger.error('error', user_id: 123) }.not_to raise_error
  end
end
```

### Integration Test
```bash
# Start server
bundle exec puma

# Generate load
ab -n 1000 -c 50 http://localhost:3000/random

# Check for:
# 1. No thread explosion (ps aux | grep ruby)
# 2. Sessions persist across restart
# 3. Logs are structured
# 4. No Redis race conditions
```

---

## Rollback Plan

If issues occur:
1. Git revert to previous commit
2. Deploy previous version
3. Monitor error rates
4. Fix issues offline, redeploy

---

## Success Metrics

- [ ] Thread count stays < 100 under load
- [ ] Sessions persist across deploys
- [ ] All logs are JSON in production
- [ ] No Redis connection errors
- [ ] Error rate stays < 0.1%
- [ ] p95 latency stays < 300ms

---

## Next Steps After Week 1

1. **Week 2-3:** Refactor app.rb into modules
2. **Month 2:** Add APM monitoring
3. **Quarter 2:** ORM migration

---

*Ready to execute. Estimate: 10-12 hours total*
