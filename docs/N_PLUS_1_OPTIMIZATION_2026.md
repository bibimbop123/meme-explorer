# N+1 Query Optimization - Trending Service

## Issues Found

### Issue 1: Trending Service - User lookups
**Location:** lib/services/trending_service.rb (~line 45)
**Problem:** Loading user for each meme individually

```ruby
# BEFORE (N+1):
trending_memes.each do |meme|
  user = DB[:users].where(id: meme[:user_id]).first  # N queries!
  # ...
end

# AFTER (Optimized):
user_ids = trending_memes.map { |m| m[:user_id] }.compact.uniq
users = DB[:users].where(id: user_ids).all.index_by { |u| u[:id] }

trending_memes.each do |meme|
  user = users[meme[:user_id]]  # 1 query total!
  # ...
end
```

### Issue 2: Leaderboard - Activity counts
**Location:** lib/services/leaderboard_service.rb (~line 30)
**Problem:** Counting activities for each user

```ruby
# BEFORE (N+1):
users.each do |user|
  user[:activity_count] = DB[:meme_activity_log]
    .where(user_id: user[:id]).count  # N queries!
end

# AFTER (Optimized):
activity_counts = DB[:meme_activity_log]
  .select(:user_id)
  .select_append { count('*').as(activity_count) }
  .group(:user_id)
  .all
  .index_by { |r| r[:user_id] }

users.each do |user|
  user[:activity_count] = activity_counts.dig(user[:id], :activity_count) || 0
end
```

## Performance Impact
- **Before:** O(N) database queries
- **After:** O(1) database queries
- **Estimated Improvement:** 30-50ms per request on trending endpoints

## Action Items
- [ ] Apply trending service optimization
- [ ] Apply leaderboard service optimization
- [ ] Add query performance logging
- [ ] Monitor slow query log
