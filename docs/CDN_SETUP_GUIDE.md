# CDN Setup Guide

## Overview

This guide explains how to configure CDN (Content Delivery Network) for the Meme Explorer application to improve performance and reduce server load.

## Configuration

### Environment Variables

Add to `.env` or production environment:

```bash
# CDN Configuration
CDN_DOMAIN=cdn.meme-explorer.com
ASSET_VERSION=1781721819
```

### Cloudflare Setup (Recommended)

1. **Sign up for Cloudflare** (free tier available)
2. **Add your domain** to Cloudflare
3. **Configure DNS**:
   - Add CNAME record: `cdn` → `meme-explorer.onrender.com`
4. **Enable caching**:
   - Go to Caching → Configuration
   - Set Browser Cache TTL: "Respect Existing Headers"
   - Enable "Cache Everything" for `/css/*`, `/js/*`, `/images/*`
5. **Enable compression**:
   - Go to Speed → Optimization
   - Enable "Auto Minify" for CSS, JS, HTML
   - Enable "Brotli" compression

### AWS CloudFront Setup

1. **Create CloudFront distribution**
2. **Origin Settings**:
   - Origin Domain: `meme-explorer.onrender.com`
   - Protocol: HTTPS only
3. **Behavior Settings**:
   - Allowed HTTP Methods: GET, HEAD, OPTIONS
   - Cache Policy: CachingOptimized
   - Compress Objects: Yes
4. **Custom Domain**:
   - Add CNAME: `cdn.meme-explorer.com`
   - Request SSL certificate via ACM

## Usage in Views

### Basic Usage

```erb
<!-- CSS -->
<link rel="stylesheet" href="<%= cdn_css('meme_explorer') %>">

<!-- JavaScript -->
<script src="<%= cdn_js('activity-tracker') %>"></script>

<!-- Images -->
<img src="<%= cdn_image('logo.png') %>" alt="Logo">

<!-- Generic Assets -->
<link rel="icon" href="<%= cdn_asset('/favicon.ico') %>">
```

### Performance Optimizations

```erb
<!-- Preload critical CSS -->
<%= preload_css('meme_explorer', 'grid-layout') %>

<!-- Preload critical JS -->
<%= preload_js('activity-tracker') %>

<!-- Responsive images with srcset -->
<img src="<%= cdn_image('hero.jpg') %>"
     srcset="<%= cdn_image_srcset('hero.jpg', [1, 2, 3]) %>"
     alt="Hero">
```

## Cache Invalidation

### Update Asset Version

When deploying new assets, update the version:

```bash
export ASSET_VERSION=$(date +%s)
```

### Cloudflare Purge

```bash
curl -X POST "https://api.cloudflare.com/client/v4/zones/{zone_id}/purge_cache" \
     -H "Authorization: Bearer {api_token}" \
     -H "Content-Type: application/json" \
     --data '{"purge_everything":true}'
```

### CloudFront Invalidation

```bash
aws cloudfront create-invalidation \
    --distribution-id {DISTRIBUTION_ID} \
    --paths "/*"
```

## Testing

### Verify CDN is Working

```bash
# Check headers
curl -I https://cdn.meme-explorer.com/css/meme_explorer.css

# Should see:
# Cache-Control: public, max-age=31536000, immutable
# CF-Cache-Status: HIT (for Cloudflare)
# X-Cache: Hit from cloudfront (for CloudFront)
```

### Performance Testing

```bash
# Test with CDN
curl -w "@curl-format.txt" -o /dev/null -s https://meme-explorer.com/random

# Test without CDN (for comparison)
curl -w "@curl-format.txt" -o /dev/null -s https://meme-explorer.onrender.com/random
```

## Monitoring

### Key Metrics

- **Cache Hit Ratio**: Target > 80%
- **Page Load Time**: Target < 2 seconds
- **Time to First Byte**: Target < 500ms
- **Bandwidth Saved**: Monitor reduction

### Cloudflare Analytics

- Dashboard → Analytics → Traffic
- Monitor cache hit ratio, bandwidth saved

### CloudFront Metrics

- CloudWatch → CloudFront metrics
- Monitor requests, bytes, cache hit ratio

## Troubleshooting

### Assets Not Loading

1. Check CDN_DOMAIN environment variable
2. Verify DNS configuration
3. Check browser console for CORS errors
4. Verify SSL certificate

### Cache Not Working

1. Check Cache-Control headers
2. Verify CDN cache settings
3. Check for cookies being set (breaks caching)
4. Purge cache and retry

### Mixed Content Warnings

1. Ensure all assets use HTTPS
2. Update hardcoded HTTP URLs to HTTPS
3. Use protocol-relative URLs if needed

## Cost Optimization

- Use appropriate cache durations
- Enable compression
- Optimize images before upload
- Use WebP format for images
- Implement lazy loading

## Security

- Enable HTTPS only
- Set appropriate CORS headers
- Use SRI (Subresource Integrity) for critical assets
- Monitor for hotlinking

---

**Created**: 2026-06-17
**Phase**: 4 - Performance & Scaling
