# Performance Monitoring Configuration

## Middleware Added
`lib/middleware/performance_monitoring_middleware.rb`

## Features
1. **Slow Request Logging** - Logs requests over threshold (default: 1000ms)
2. **Response Time Headers** - X-Response-Time header for debugging
3. **StatsD Integration** - Optional metrics tracking

## Configuration
Set environment variable:
```bash
export SLOW_REQUEST_THRESHOLD=500  # Log requests over 500ms
```

## Integration
Add to app.rb:
```ruby
require_relative 'lib/middleware/performance_monitoring_middleware'
use PerformanceMonitoringMiddleware
```

## Monitoring
- Check logs for "SLOW REQUEST" entries
- Review X-Response-Time header in responses
- Set up StatsD/Datadog for visualization
