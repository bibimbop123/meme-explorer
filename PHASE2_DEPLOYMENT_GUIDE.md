# Phase 2: Image Optimization Pipeline - Deployment Guide

**Timeline:** 1-2 hours to deploy
**Environment:** Development → Staging → Production Canary
**Expected Results:** LCP <1.5s, +50% performance improvement

---

## PRE-DEPLOYMENT CHECKLIST

### Prerequisites
- [ ] AWS account with S3 access
- [ ] AWS credentials in `.env` (AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY)
- [ ] PostgreSQL database (for image_urls, image_metadata columns)
- [ ] Ruby 3.2.1 environment
- [ ] 30 minutes for staging validation

---

## STEP 1: INSTALL GEMS (5 minutes)

```bash
# From project root
cd /Users/brian/DiscoveryPartnersInstitute/meme_explorer

# Install new gems
bundle install

# Verify installation
bundle list | grep -E "image_processing|ruby-vips|aws-sdk-s3"
```

**Expected Output:**
```
image_processing (1.12.2)
ruby-vips (2.1.x)
aws-sdk-s3 (1.120.x)
```

---

## STEP 2: SET UP AWS INFRASTRUCTURE (10 minutes)

### Create S3 Bucket

```bash
# Install AWS CLI if not present
brew install awscli

# Configure AWS credentials
aws configure

# Create S3 bucket
aws s3 mb s3://meme-explorer-images-prod --region us-east-1

# Enable versioning (optional, for rollback)
aws s3api put-bucket-versioning \
  --bucket meme-explorer-images-prod \
  --versioning-configuration Status=Enabled

# Block public access (security)
aws s3api put-public-access-block \
  --bucket meme-explorer-images-prod \
  --public-access-block-configuration "BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true"

# Set CORS for image serving
cat > /tmp/cors.json << 'EOF'
{
  "CORSRules": [
    {
      "AllowedOrigins": ["https://meme-explorer.onrender.com", "https://staging.meme-explorer.com"],
      "AllowedMethods": ["GET"],
      "AllowedHeaders": ["*"],
      "MaxAgeSeconds": 3000
    }
  ]
}
EOF

aws s3api put-bucket-cors \
  --bucket meme-explorer-images-prod \
  --cors-configuration file:///tmp/cors.json
```

### Create CloudFront Distribution

```bash
# Create CloudFront distribution (via AWS console or CLI)
# Origin: S3 bucket URL
# Distribution: meme-explorer-images-prod.cloudfront.net
# Cache TTL: 31536000 (1 year for immutable content)

# Update .env with CloudFront URL
# AWS_CLOUDFRONT_DISTRIBUTION=meme-explorer-images-prod
```

**Or use AWS Console:**
1. Go to CloudFront console
2. Create distribution
3. Select S3 bucket as origin
4. Set default TTL to 31536000
5. Enable compression
6. Update .env with distribution domain

---

## STEP 3: DATABASE MIGRATION (5 minutes)

```bash
# Run migration to add optimization columns
ruby db/migrate_add_image_optimization_to_memes.rb

# Verify columns were added
psql -d meme_explorer -c "\d memes" | grep -E "image_urls|image_metadata|optimization_status|optimized_at"
```

**Expected Output:**
```
 image_urls              | jsonb
 image_metadata          | jsonb
 optimization_status     | character varying
 optimized_at            | timestamp without time zone
```

---

## STEP 4: STAGING DEPLOYMENT (20 minutes)

### Verify in Staging First

```bash
# Push to staging branch
git add Gemfile config/storage.yml .env lib/services/image_optimization_service.rb \
        db/migrate_add_image_optimization_to_memes.rb app/components/progressive_image_component.rb \
        routes/api/v1/trending_optimized.rb

git commit -m "Phase 2: Add image optimization pipeline (JPEG+WebP, S3/CloudFront)"

git push staging main:main

# Verify deployment
# Check logs for errors
heroku logs --app meme-explorer-staging --tail

# Test API endpoint
curl "https://staging.meme-explorer.com/api/v1/trending?time_window=24h"

# Verify images load
open https://staging.meme-explorer.com/trending
```

### Validate Performance

```bash
# Install Lighthouse CI
npm install -g @lhci/cli

# Run performance test
lhci autorun

# Expected scores:
# - Performance: 85+
# - LCP: <2.0s (will improve with more memes optimized)
# - CLS: <0.1
# - FID: <100ms
```

---

## STEP 5: PRODUCTION CANARY ROLLOUT (30 minutes monitoring)

### Canary Deployment (5% Traffic)

```bash
# Deploy to production
git push production main:main

# Monitor immediately
heroku logs --app meme-explorer --tail

# Watch for errors in real-time
# Look for: "Image optimization failed", "S3 upload error", etc.
```

### Monitor Key Metrics

```bash
# Check error rate (target: <0.1%)
heroku metrics --app meme-explorer | grep errors

# Check CDN performance
# CloudFront console → Distribution → Cache Statistics
# Monitor: Cache Hit Rate (target: 95%+)

# Check load times
# Sentry → Performance → Trending
# Look for: LCP improvements, image load times
```

### Expand to 100% (After 30 min validation)

```bash
# If metrics look good, expand to full production
# This typically happens automatically on Render/Heroku
# Or manually increase traffic allocation from 5% → 100%
```

---

## STEP 6: POST-DEPLOYMENT VALIDATION

### Verify Images Are Optimized

```bash
# Check in browser DevTools:
# Network tab → Trending page
# Should see:
# - WebP images for Chrome browsers (65% smaller)
# - JPEG images for Safari/Firefox
# - 600px for mobile, 1200px for desktop
# - Cache-Control: max-age=31536000

# DevTools Console:
# Look for no errors
# Images should load in <200ms (from cache)
```

### Performance Checks

```bash
# Lighthouse score should improve
# LCP: <1.5s (was 2-3s)
# Image load: <200ms (was 300-500ms)
# File sizes: 400-600KB (was 2-5MB)

# Open trending page, measure:
# Time to interactive: <2s
# Cumulative Layout Shift: 0 (no images shifting)
```

### Error Monitoring

```bash
# Sentry dashboard
# Filter: event.level = error AND tags.service = "trending"
# Verify: <0.1% error rate

# Common issues to monitor:
# - S3 timeout: "Failed to upload to S3"
# - CloudFront: CDN serving stale content
# - Memory: Image processing consuming too much RAM
```

---

## ROLLBACK PROCEDURE (If Issues Found)

```bash
# Immediate rollback to Phase 1 (takes 2 minutes)
git revert HEAD~1
git push production main:main

# This reverts to:
# - Phase 1 image loading (real images, no optimization)
# - Original API endpoints
# - No S3 dependency
# System stays functional, just slower (but still +50-70% better than before Phase 1)

# Investigate issue
# Fix in code
# Re-deploy when ready
```

---

## MONITORING & METRICS (Ongoing)

### Key Performance Indicators

| Metric | Target | How to Monitor |
|--------|--------|----------------|
| LCP | <1.5s | Sentry Performance tab |
| Image load time | <200ms | DevTools Network |
| S3 upload success | 99.9% | Sentry Errors |
| CDN hit rate | 95%+ | CloudFront console |
| Error rate | <0.1% | Sentry dashboard |

### Set Up Alerts

```bash
# Sentry Alert: Image optimization failures
# Condition: event.logger = "ImageOptimizationService"
# Action: Slack notification

# Sentry Alert: High error rate
# Condition: issue.error_rate > 1%
# Action: Email + Slack

# CloudFront Alert: Low cache hit rate
# Condition: cache_hit_rate < 90%
# Action: Investigate & optimize
```

---

## TROUBLESHOOTING

### Issue: "AWS credentials not found"
```bash
# Check .env has AWS_ACCESS_KEY_ID and AWS_SECRET_ACCESS_KEY
cat .env | grep AWS_

# If missing, update:
echo "AWS_ACCESS_KEY_ID=your_key" >> .env
echo "AWS_SECRET_ACCESS_KEY=your_secret" >> .env
```

### Issue: "S3 bucket doesn't exist"
```bash
# Verify bucket was created
aws s3 ls | grep meme-explorer-images-prod

# If missing, create:
aws s3 mb s3://meme-explorer-images-prod --region us-east-1
```

### Issue: "CloudFront returns 403 Forbidden"
```bash
# Check S3 bucket policy allows CloudFront access
# CloudFront console → Distribution → Origins → Edit
# Verify OAI (Origin Access Identity) is created
# Add OAI to S3 bucket policy
```

### Issue: "Images not loading from CloudFront"
```bash
# Check distribution is deployed (takes 15-20 minutes)
aws cloudfront list-distributions --query 'DistributionList.Items[?DomainName==`meme-explorer-images-prod.cloudfront.net`]'

# Check cache is not stale
# CloudFront console → Invalidations → Create invalidation
# Path: /memes/* (invalidate all meme images)
```

### Issue: "Memory usage too high during processing"
```bash
# ruby-vips has high memory overhead during batch processing
# Solution: Process in background jobs (Sidekiq)
# Implement: async queue for image optimization
# Defer to Phase 2.5 optimization
```

---

## SUCCESS INDICATORS

✅ **Phase 2 Deployed Successfully When:**
- [ ] All gems installed without errors
- [ ] Database migration completed
- [ ] S3 bucket created and accessible
- [ ] CloudFront distribution deployed
- [ ] Staging deployment successful
- [ ] LCP <1.5s measured
- [ ] Image load time <200ms
- [ ] Error rate <0.1%
- [ ] CDN hit rate 95%+
- [ ] Production canary stable for 30 minutes
- [ ] Expanded to 100% traffic
- [ ] No rollbacks needed

---

## WHAT'S NEXT

### Immediate (After Deployment)
- Monitor metrics for 24 hours
- Collect performance data
- Track user engagement improvements

### Week 2 (Phase 2.5 - Optional)
- Implement async image processing (Sidekiq background jobs)
- Add blur-up effect (LQIP preview images)
- Batch-process existing memes (don't block on optimization)

### Weeks 3-4 (Phase 3)
- Smart category fallbacks
- User preference tracking
- Seasonal content rotation
- Target: +167% total engagement (3x)

---

*Phase 2 Deployment Guide - Complete Production Guide*
