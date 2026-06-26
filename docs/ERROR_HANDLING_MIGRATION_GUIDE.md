# Error Handling Migration Guide

## OLD PATTERN (Dangerous):
```ruby
rescue => e
  puts "Error: #{e.message}"
  nil
end
```

## NEW PATTERN (Proper):
```ruby
rescue => e
  handle_error(e, context: { user_id: user_id, operation: 'fetch_meme' })
  nil  # Or appropriate default
end
```

## Usage Examples:

### Simple Error Handling:
```ruby
def fetch_user_data(user_id)
  with_error_handling(context: { user_id: user_id }, default_return: {}) do
    # Code that might fail
    DB.execute("SELECT * FROM users WHERE id = ?", [user_id])
  end
end
```

### Database Errors:
```ruby
begin
  DB.execute(query, params)
rescue => e
  handle_db_error(e, query: query, params: params)
  []
end
```

### Worker Errors:
```ruby
class MyWorker
  def perform(data)
    # work
  rescue => e
    handle_worker_error(e, worker_name: 'MyWorker', job_data: data)
    raise  # Re-raise for Sidekiq retry
  end
end
```

## Migration Status:
- Total bare rescues found: ~300
- Priority files to update:
  1. app.rb (main routes)
  2. lib/services/*.rb (all services)
  3. app/workers/*.rb (all workers)
  4. routes/*.rb (all route files)

## Automated Migration:
Run: `ruby scripts/migrate_error_handling.rb`
