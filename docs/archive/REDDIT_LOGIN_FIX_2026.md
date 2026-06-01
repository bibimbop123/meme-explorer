# Reddit Login Fix - May 2026

## Problem Identified
Reddit OAuth login was broken in production due to a database mismatch issue. The app uses:
- **SQLite3** in development (local)
- **PostgreSQL with Sequel** in production (Render)

## Root Cause
The `UserService` class was using SQLite-specific methods that don't exist in Sequel/PostgreSQL:
- `DB.last_insert_row_id` (SQLite only)
- Direct SQL with `DB.execute()` (SQLite only)
- Result format differences (string keys vs symbol keys)

When a user tried to log in with Reddit in production, the `create_or_find_from_reddit` method would fail because it tried to call SQLite-specific methods on a PostgreSQL/Sequel database connection.

## Solution Implemented
Updated `lib/services/user_service.rb` to detect and support both database systems:

### Database Detection
```ruby
if defined?(Sequel) && DB.is_a?(Sequel::Database)
  # Use Sequel methods for PostgreSQL
else
  # Use SQLite3 methods
end
```

### Methods Fixed
All methods in `UserService` now support both databases:

1. **`create_or_find_from_reddit`** - Creates Reddit users in both SQLite and PostgreSQL
2. **`create_email_user`** - Creates email/password users in both systems
3. **`find_by_email`** - Finds users by email with consistent return format
4. **`find_by_id`** - Finds users by ID with consistent return format
5. **`get_stats`** - Gets user stats (saved/liked counts)
6. **`is_admin?`** - Checks admin role
7. **`save_meme`** - Saves memes (uses `INSERT OR IGNORE` for SQLite, `insert_conflict(:ignore)` for PostgreSQL)
8. **`unsave_meme`** - Removes saved memes
9. **`is_meme_saved?`** - Checks if meme is saved
10. **`get_saved_memes`** - Gets paginated saved memes
11. **`get_saved_memes_count`** - Counts saved memes
12. **`get_liked_memes`** - Gets liked memes

### Key Differences Handled

| Feature | SQLite3 | PostgreSQL/Sequel |
|---------|---------|-------------------|
| Insert & Get ID | `DB.execute()` + `DB.last_insert_row_id` | `DB[:table].insert()` (returns ID) |
| Query | `DB.execute(sql, params)` | `DB[:table].where().select()` |
| Result Keys | String keys (`"id"`) | Symbol keys (`:id`) - converted to strings |
| Insert Ignore | `INSERT OR IGNORE` | `.insert_conflict(:ignore)` |
| Error Handling | `SQLite3::ConstraintException` | `Sequel::UniqueConstraintViolation` |

## What This Fixes
✅ **Reddit OAuth login in production** - Now works on Render (PostgreSQL)  
✅ **Reddit OAuth login in development** - Still works locally (SQLite)  
✅ **Email/password login** - Not broken, works in both environments  
✅ **User registration** - Works in both environments  
✅ **Save/unsave memes** - Works in both environments  
✅ **User profiles** - Works in both environments  
✅ **Admin features** - Works in both environments  

## Testing Checklist

### Production (Render - PostgreSQL)
- [x] Reddit login creates new user
- [x] Reddit login finds existing user
- [x] User can save memes
- [x] User can view profile
- [x] Leaderboard shows Reddit users

### Development (Local - SQLite)
- [x] Reddit login still works locally (if testing OAuth)
- [x] Email/password login works
- [x] Email/password signup works
- [x] Save/unsave memes works
- [x] Profile page works

## No Breaking Changes
This fix is **backward compatible** and does not break any existing features:
- Email/password authentication still works
- All user-related queries still work
- Saved memes functionality unchanged
- Leaderboard functionality unchanged

## Deployment Instructions
1. Commit the updated `lib/services/user_service.rb`
2. Push to production (Render auto-deploys)
3. Test Reddit login on production site
4. Monitor logs for any database-related errors

## Technical Notes
- The fix uses runtime database type detection, so the same code works in all environments
- Return values are normalized to use string keys for consistency across both database systems
- Error handling covers both SQLite and PostgreSQL constraint violations
- The solution follows the adapter pattern to abstract database differences

## Related Files
- `lib/services/user_service.rb` - Main fix location
- `lib/services/auth_service.rb` - OAuth verification (unchanged)
- `routes/auth.rb` - Authentication routes (unchanged)
- `db/setup.rb` - SQLite database setup
- `db/postgres_schema.sql` - PostgreSQL schema
- `config/puma.rb` - Database connection setup for production

---
**Fix Date:** May 12, 2026  
**Status:** ✅ Complete & Deployed  
**Committed:** commit 522658c  
**Deployed:** Auto-deployed via Render  
**Tested:** ✅ Production verified
