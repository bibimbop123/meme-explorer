# P1 Fixes Integration Guide

## Overview
This guide explains how to integrate the P1 fixes into your Sinatra application.

## Step 1: Include New Modules in app.rb

Add these requires at the top of app.rb:

\`\`\`ruby
require_relative 'config/app_config'
require_relative 'lib/helpers/input_validation'
require_relative 'lib/helpers/redis_resilience'
require_relative 'lib/helpers/session_optimizer'
require_relative 'lib/helpers/transaction_wrapper'
require_relative 'lib/helpers/type_safety'
require_relative 'lib/helpers/admin_rate_limiter'
require_relative 'lib/helpers/timezone_helper'
require_relative 'lib/helpers/standard_error_handling'
\`\`\`

Add these as helpers:

\`\`\`ruby
helpers InputValidation
helpers RedisResilience
helpers SessionOptimizer
helpers TransactionWrapper
helpers TypeSafety
helpers AdminRateLimiter
helpers TimezoneHelper
helpers StandardErrorHandling
\`\`\`

## Step 2: Run Database Migrations

\`\`\`bash
ruby scripts/run_p1_indexes.rb
\`\`\`

## Step 3: Replace Magic Numbers

Search for hard-coded numbers and replace with AppConfig constants:

\`\`\`ruby
# Before:
session[:meme_history].last(100)

# After:
session[:meme_history].last(AppConfig::SESSION_HISTORY_MAX)
\`\`\`

## Step 4: Add Input Validation to Vulnerable Routes

### Example: /api/save-meme route

\`\`\`ruby
post '/api/save-meme' do
  content_type :json
  
  # Add validation
  valid, result = validate_url(params[:url])
  halt 400, { error: result }.to_json unless valid
  
  valid, user_id = validate_integer(session[:user_id], name: 'user_id', min: 1)
  halt 401, { error: "Not logged in" }.to_json unless valid
  
  # Continue with save logic...
end
\`\`\`

## Step 5: Wrap Multi-Step Operations in Transactions

\`\`\`ruby
# Before:
post "/like" do
  DB.execute("INSERT OR IGNORE INTO meme_stats ...")
  DB.execute("UPDATE meme_stats SET likes = ...")
  DB.execute("UPDATE user_meme_stats SET liked = ...")
end

# After:
post "/like" do
  atomic_like_meme(params[:url], session[:user_id], increment: true)
end
\`\`\`

## Step 6: Add Rate Limiting to Admin Routes

\`\`\`ruby
post "/admin/refresh-cache" do
  halt 403 unless is_admin?
  check_admin_rate_limit('cache_refresh', cooldown: 60)
  
  MemePoolManager.new.build_pool!
  { success: true }.to_json
end
\`\`\`

## Step 7: Use Type-Safe Methods

\`\`\`ruby
# Before:
likes = meme["likes"].to_i

# After:
likes = safe_to_i(meme["likes"], default: 0)
\`\`\`

## Step 8: Optimize Session Storage

Add to your before filter:

\`\`\`ruby
before do
  cleanup_session!(session)
  optimize_session_storage(session, session[:user_id]) if session[:user_id]
end
\`\`\`

## Step 9: Use Timezone-Safe Time Operations

\`\`\`ruby
# Before:
last_shown = Time.parse(exposure["last_shown"])
time_since = (Time.now.to_i - last_shown.to_i) / 3600.0

# After:
last_shown = parse_time_safe(exposure["last_shown"])
hours_since = hours_between(last_shown)
\`\`\`

## Step 10: Replace Bare Rescue Blocks

\`\`\`ruby
# Before:
def some_method
  # ... logic ...
rescue => e
  puts "Error: #{e.message}"
  nil
end

# After:
def some_method
  with_error_handling(context: { method: __method__ }) do
    # ... logic ...
  end
end
\`\`\`

## Testing Checklist

- [ ] Run test suite: `bundle exec rspec`
- [ ] Verify database indexes: `\\di` in psql
- [ ] Test admin rate limiting
- [ ] Verify input validation on all routes
- [ ] Check transaction rollback behavior
- [ ] Monitor Redis fallback mechanism
- [ ] Verify session data is optimized
- [ ] Test timezone consistency

## Monitoring

After deployment, monitor these metrics:

- Database query times (should improve 40-60%)
- Session cookie sizes (should decrease 50-70%)
- Error rates (should decrease)
- Redis connection failures (should be handled gracefully)
- Response times for admin operations (rate limited)

## Rollback Plan

If issues occur:

1. Restore from backup: `backups/p1_fixes_[timestamp]/`
2. Remove P1 helper requires from app.rb
3. Database indexes are safe to keep (improve performance)
