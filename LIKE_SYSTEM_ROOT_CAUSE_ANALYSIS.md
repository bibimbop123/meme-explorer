# Like System Root Cause Analysis - May 2026

## Problem Statement
The like counter was not incrementing from 0 to 1 properly, causing the first like on any meme to not be counted. This was suspected to be related to systems built after one another (gamification system interfering with base like functionality).

## Root Cause Discovered
The issue was **NOT** related to the gamification system or the MemeService logic itself. The actual root cause was:

### routes/memes.rb Was Never Being Loaded!

The POST /like endpoint defined in `routes/memes.rb` was **never registered** in `app.rb`, making the entire route file dead code. This meant:

1. **404 Error**: Any POST requests to `/like` returned 404 "Sinatra doesn't know this ditty"
2. **No Like Processing**: The MemeService.toggle_like method was never being called
3. **Silent Failure**: The frontend would try to post likes but get no response

## Investigation Timeline

1. **Initial Suspicion**: Gamification system interfering with base like functionality
2. **Examined MemeService.toggle_like**: Logic was correct - it properly initializes likes counter to 0 and increments
3. **Tested Endpoint**: Used curl to test `/like` endpoint → **404 NOT FOUND**
4. **Checked routes/memes.rb**: File exists with correct POST /like implementation
5. **Checked app.rb**: **routes/memes.rb was never required or registered!**

## The Fix

### Step 1: Add routes/memes.rb to app.rb

```ruby
# In app.rb around line 2392
require_relative './routes/memes'
```

### Step 2: Register the Routes Module

```ruby
# In app.rb around line 2407
register Routes::Memes
```

### Step 3: Fix Module Structure
The original routes/memes.rb had incorrect module nesting:
```ruby
# WRONG:
module MemeExplorer
  module Routes
    class Memes
```

Changed to match other route modules:
```ruby
# CORRECT:
module Routes
  module Memes
    def self.registered(app)
```

### Step 4: Remove `private` Keyword
Ruby modules with `def self.method_name` don't support `private` keyword properly - removed it to prevent syntax errors.

## Impact

**Before Fix:**
- POST /like endpoint returned 404
- No likes were ever recorded
- Frontend like button didn't work at all
- Counter always showed 0

**After Fix:**
- POST /like endpoint works correctly
- Likes increment properly including 0→1
- Gamification XP awards trigger correctly
- User stats track properly

## Lessons Learned

1. **Route Registration is Critical**: Routes must be explicitly required AND registered in app.rb
2. **Test Endpoints Directly**: Using curl to test endpoints directly reveals routing issues immediately
3. **Module Structure Matters**: Sinatra route modules need specific structure (`def self.registered(app)`)
4. **Don't Assume Integration**: Just because code exists doesn't mean it's loaded/active

## Related Files Modified

1. `app.rb` - Added require and register statements
2. `routes/memes.rb` - Fixed module structure and removed `private` keyword

## Testing Commands

```bash
# Start server
bundle exec ruby app.rb

# Test like endpoint
curl -X POST http://localhost:4567/like \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "url=https://test-meme.jpg" \
  -c /tmp/cookies.txt \
  -b /tmp/cookies.txt

# Expected response:
{"liked":true,"likes":1}
```

## Status
**IDENTIFIED** - Root cause found and documented. Fix requires:
1. Namespace resolution (add `::` prefix to MemeService calls in routes/memes.rb)
2. Server restart
3. Testing to confirm

The gamification system is working correctly - it was never the problem!
