# Code Documentation Guidelines

## Purpose
Improve inline documentation for better maintainability and onboarding

## Standards

### 1. Class Documentation
Every service class should have:
```ruby
# frozen_string_literal: true

# Handles meme caching and retrieval from Redis
#
# This service provides a centralized interface for caching meme data
# with automatic expiration and fallback to database queries.
#
# @example Basic usage
#   service = CacheService.new
#   meme = service.get_or_set('meme:123') { fetch_from_db(123) }
#
# @example With custom TTL
#   service.get_or_set('key', ttl: 3600) { expensive_operation }
#
class CacheService
  # Default cache TTL in seconds
  DEFAULT_TTL = 1800
end
```

### 2. Method Documentation
Complex methods should include:
```ruby
# Fetches random meme avoiding recently viewed
#
# @param user_id [Integer] The ID of the current user
# @param options [Hash] Optional parameters
# @option options [String] :category Filter by category
# @option options [Integer] :limit Max number to consider
#
# @return [Hash, nil] Meme data or nil if none available
# @raise [ArgumentError] if user_id is invalid
#
def fetch_random_meme(user_id, options = {})
  # Implementation
end
```

### 3. Inline Comments
Use inline comments for:
- Complex business logic
- Performance optimizations
- Workarounds for external API limitations
- Security considerations

```ruby
# Use SET NX to prevent race conditions when multiple
# workers try to refresh the same cache key
redis.set(key, value, nx: true, ex: ttl)
```

### 4. TODO/FIXME/HACK Tags
```ruby
# TODO: Migrate to async processing after Redis upgrade
# FIXME: Handle edge case where subreddit returns empty array
# HACK: Temporary workaround for Reddit API rate limiting
```

## Priority Files for Documentation
1. lib/services/meme_service.rb
2. lib/services/diversity_engine_service.rb
3. lib/services/reddit_fetcher_service.rb
4. lib/services/turbocharged_reddit_fetcher.rb
5. lib/helpers/app_helpers.rb

## Automated Tools
- Use yard for generating documentation: `yard doc`
- Use rubocop to enforce documentation: `rubocop --only Style/Documentation`

## Examples

### Before
```ruby
def get_memes(user_id, cat)
  DB[:memes].where(category: cat).all
end
```

### After
```ruby
# Retrieves memes filtered by category for a specific user
#
# This method applies user-specific filtering (blocked content,
# already-viewed memes) before returning results.
#
# @param user_id [Integer] The authenticated user's ID
# @param category [String] Meme category (funny, wholesome, etc.)
# @return [Array<Hash>] Array of meme data hashes
# @raise [ArgumentError] if category is invalid
def get_memes(user_id, category)
  validate_category!(category)
  
  DB[:memes]
    .where(category: category)
    .exclude(id: viewed_meme_ids(user_id))
    .all
end
```
