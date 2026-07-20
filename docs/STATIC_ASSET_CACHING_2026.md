# Static Asset Caching Configuration

## Implementation
Added caching headers to static assets in config.ru

## Headers Applied
- **CSS/JS/Images:** Cache-Control: public, max-age=31536000, immutable
- **CORS:** Access-Control-Allow-Origin: *

## Cache Busting Strategy
Use query string versioning in production:
```erb
<link rel="stylesheet" href="/css/meme_explorer.css?v=<%= CACHE_VERSION %>">
```

## Performance Impact
- **Before:** Static assets revalidated on every request
- **After:** Static assets cached for 1 year
- **Estimated Improvement:** -60% bandwidth, faster page loads

## Manual Step Required
1. Add CACHE_VERSION to config/application.rb:
   ```ruby
   CACHE_VERSION = ENV.fetch('CACHE_VERSION', Time.now.to_i.to_s)
   ```

2. Update asset tags in layout.erb to include version parameter

3. Increment CACHE_VERSION on each deployment
