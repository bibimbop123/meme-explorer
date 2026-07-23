# RedisService Thread Leak Fix

## Problem
Every Redis error spawns a new thread. Under high load with Redis down, 
this creates thousands of threads leading to memory exhaustion.

## Location
File: `lib/services/redis_service.rb` (lines 369-376)

## Current Code (DANGEROUS):
```ruby
def handle_error(error, context = {})
  # ... error logging ...
  
  # Schedule availability re-check after 30 seconds
  @reconnect_thread = Thread.new do
    Thread.current.name = 'redis-reconnect'
    sleep 30
    refresh_availability!
    AppLogger.info("Redis availability re-checked", available: @redis_available)
  end
  @reconnect_thread.abort_on_exception = false
end
```

## Fixed Code (SAFE):
```ruby
def handle_error(error, context = {})
  # ... error logging ...
  
  # Use scheduled task instead of raw thread
  # Only one task can be scheduled at a time
  @reconnect_task&.cancel
  @reconnect_task = Concurrent::ScheduledTask.execute(30) do
    refresh_availability!
    AppLogger.info("Redis availability re-checked", available: @redis_available)
  end
end
```

## Apply Fix
1. Add `require 'concurrent'` at top of redis_service.rb
2. Replace Thread.new with Concurrent::ScheduledTask.execute
3. Cancel previous task before creating new one
4. Remove @reconnect_thread.abort_on_exception line

## Benefits
- Prevents thread leak (only 1 scheduled task at a time)
- Better error handling
- Automatic cleanup
- No unbounded growth
