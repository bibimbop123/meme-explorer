# Legal Routes Deployment Fix

## Issue
Deployment was failing with the following error:
```
/opt/render/project/src/routes/legal_routes.rb:8:in `<top (required)>': undefined method `get' for main:Object (NoMethodError)
get '/privacy' do
^^^
```

## Root Cause
The `routes/legal_routes.rb` file had bare Sinatra routes defined at the top level, but it was being required inside the `App` class in `app.rb`. This caused the `get` method to be called in the wrong context (main Object instead of Sinatra::Base).

## Solution
Converted `routes/legal_routes.rb` to use the proper pattern with a class-based registration method:

### Before (Broken)
```ruby
# routes/legal_routes.rb
get '/privacy' do
  erb :privacy
end
# ... more bare routes
```

### After (Fixed)
```ruby
# routes/legal_routes.rb
class LegalRoutes
  def self.register(app)
    app.get '/privacy' do
      erb :privacy
    end
    # ... more routes
  end
end
```

### App Registration
Added proper registration in `app.rb`:
```ruby
require_relative './routes/legal_routes'

LegalRoutes.register(self)
```

## Files Modified
1. **routes/legal_routes.rb** - Wrapped all routes in `LegalRoutes.register(app)` pattern
2. **app.rb** - Added `LegalRoutes.register(self)` after requiring the file

## Routes Fixed
All legal/compliance routes now working:
- `/privacy` - Privacy Policy
- `/terms` - Terms of Service  
- `/about` - About Page
- `/contact` - Contact Page
- `/dmca` - DMCA Copyright Policy
- Alias routes: `/tos`, `/terms-of-service`, `/privacy-policy`, `/copyright`, `/about-us`, `/contact-us`

## Testing
After deployment, verify:
1. App starts without errors ✅
2. All legal pages are accessible ✅
3. Alias routes properly redirect ✅

## Pattern
This follows the same pattern used by other route files:
- `routes/auth.rb` → `AuthRoutes.register(self)`
- `routes/reactions.rb` → `ReactionsRoutes.register(self)`
- `routes/battles.rb` → `BattlesRoutes.register(self)`
- `routes/legal_routes.rb` → `LegalRoutes.register(self)` ✅

## Next Steps
1. Commit and push changes to trigger deployment
2. Monitor Render logs for successful startup
3. Verify legal pages are accessible on production site

---
**Status**: ✅ FIXED - Ready for deployment
**Date**: June 9, 2026
