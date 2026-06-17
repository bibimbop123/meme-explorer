# Horizontal Scaling Guide

## Overview

Horizontal scaling adds more application instances to handle increased traffic, providing:
- Higher availability (no single point of failure)
- Better performance (load distributed across instances)
- Automatic failover (if one instance fails)
- Elastic scaling (scale up/down based on demand)

## Architecture

```
              Load Balancer
                    |
    +---------------+---------------+
    |               |               |
Instance 1      Instance 2      Instance 3
    |               |               |
    +---------------+---------------+
                    |
        +-----------+-----------+
        |           |           |
    Database    Redis Cache  Sidekiq
```

## Prerequisites

### 1. Stateless Application

**Required Changes:**
- ✅ Use Redis for session storage (not in-memory)
- ✅ Store uploads in S3/cloud storage (not local disk)
- ✅ Use Redis/database for cache (not in-memory)
- ✅ Coordinate background jobs via Redis/database

**Check:**
```ruby
# BAD: In-memory session storage
use Rack::Session::Cookie

# GOOD: Redis session storage
use Rack::Session::Redis, redis_server: REDIS_POOL
```

### 2. Health Checks

Ensure your application responds to health checks:

```bash
# Should return 200 OK
curl https://your-app.com/health
curl https://your-app.com/ready
```

### 3. Shared State

All state must be in:
- PostgreSQL (persistent data)
- Redis (cache, sessions, job queue)
- Cloud storage (file uploads)

## Configuration

### Render.com (Recommended)

1. **Update render.yaml:**
   ```yaml
   services:
     - type: web
       name: meme-explorer-web
       scaling:
         minInstances: 2
         maxInstances: 10
         targetCPUPercent: 70
         targetMemoryPercent: 80
   ```

2. **Deploy:**
   ```bash
   git push origin main
   # Render automatically deploys with new scaling config
   ```

3. **Monitor:**
   - Dashboard → Services → meme-explorer-web
   - View active instances, CPU, memory

### Heroku

```bash
# Scale to 2 instances
heroku ps:scale web=2

# Enable autoscaling
heroku ps:autoscale:enable web \
  --min 2 --max 10 \
  --p95 400
```

### AWS ECS

```bash
# Update service with auto-scaling
aws ecs update-service \
  --cluster meme-explorer \
  --service web \
  --desired-count 2

# Configure auto-scaling
aws application-autoscaling register-scalable-target \
  --service-namespace ecs \
  --resource-id service/meme-explorer/web \
  --scalable-dimension ecs:service:DesiredCount \
  --min-capacity 2 \
  --max-capacity 10
```

## Testing

### Verify Load Balancing

```bash
# Make multiple requests and check instance IDs
for i in {1..10}; do
  curl -s https://meme-explorer.com/health | jq '.instance_id'
done

# Should see different instance IDs
```

### Simulate Instance Failure

1. Manually stop one instance in dashboard
2. Verify application still responds
3. Check logs for failover
4. Verify new instance spins up

### Load Testing

```bash
# Install Apache Bench
brew install ab

# Test with 1000 requests, 100 concurrent
ab -n 1000 -c 100 https://meme-explorer.com/random

# Should see:
# - All requests successful
# - Response time consistent
# - No connection errors
```

## Session Affinity (Sticky Sessions)

### When Needed

- Real-time features (WebSockets)
- In-memory caching per instance
- Specific user flows requiring consistency

### Configuration

**Render.com:**
```yaml
services:
  - type: web
    stickySession: true
```

**AWS ALB:**
```bash
aws elbv2 modify-target-group-attributes \
  --target-group-arn {ARN} \
  --attributes Key=stickiness.enabled,Value=true
```

### Note
We recommend **avoiding sticky sessions** if possible. Use Redis for all shared state instead.

## Monitoring & Alerting

### Key Metrics

- **Instance Count**: Current vs. desired
- **CPU Usage**: Per instance and aggregate
- **Memory Usage**: Per instance and aggregate
- **Request Rate**: Requests per second
- **Response Time**: P50, P95, P99
- **Error Rate**: 4xx and 5xx responses

### Set Up Alerts

**High CPU Alert:**
```
Alert when: CPU > 80% for 5 minutes
Action: Email ops team, auto-scale up
```

**High Error Rate Alert:**
```
Alert when: Error rate > 1% for 2 minutes
Action: Page on-call, create incident
```

**Instance Down Alert:**
```
Alert when: Instance count < minInstances
Action: Page on-call immediately
```

## Cost Optimization

### Right-Sizing

```ruby
# Analyze memory usage
ObjectSpace.memsize_of_all / 1024 / 1024  # MB

# Recommended instance sizes:
# - Light traffic (< 100 req/min): 512MB instances
# - Medium traffic (100-500 req/min): 1GB instances
# - Heavy traffic (> 500 req/min): 2GB instances
```

### Scaling Strategy

**Conservative (Cost-Optimized):**
```yaml
minInstances: 2
maxInstances: 5
targetCPUPercent: 80
```

**Aggressive (Performance-Optimized):**
```yaml
minInstances: 3
maxInstances: 15
targetCPUPercent: 60
```

### Cost Examples (Render.com Standard)

- **2 instances**: $14/month
- **5 instances**: $35/month
- **10 instances**: $70/month

## Troubleshooting

### Uneven Load Distribution

**Symptoms:** One instance receiving more traffic

**Solutions:**
1. Check load balancer algorithm (should be round-robin)
2. Disable sticky sessions if not needed
3. Verify all instances are healthy
4. Check for connection pooling issues

### Session Loss

**Symptoms:** Users getting logged out

**Solutions:**
1. Verify Redis session storage configured
2. Check session cookie domain setting
3. Ensure Redis is accessible from all instances
4. Verify session TTL is appropriate

### Inconsistent Behavior

**Symptoms:** Different behavior across requests

**Solutions:**
1. Eliminate all in-memory state
2. Use Redis for all caching
3. Ensure environment variables consistent
4. Check for race conditions in code

## Best Practices

### Do's ✅
- Start with 2 instances minimum
- Use Redis for all shared state
- Implement graceful shutdown
- Monitor instance health
- Test failover scenarios
- Set appropriate scaling thresholds

### Don'ts ❌
- Don't use in-memory sessions
- Don't store files on local disk
- Don't assume single instance
- Don't skip health check endpoints
- Don't ignore scaling metrics
- Don't over-provision initially

## Deployment Checklist

- [ ] Redis session storage configured
- [ ] Health check endpoints working
- [ ] All state externalized
- [ ] Auto-scaling configured
- [ ] Monitoring and alerts set up
- [ ] Load testing completed
- [ ] Failover tested
- [ ] Cost estimates reviewed
- [ ] Documentation updated
- [ ] Team trained on scaling operations

## Performance Impact

### Expected Improvements

| Metric | Single Instance | 2 Instances | 5 Instances |
|--------|----------------|-------------|-------------|
| Max Users | 500 | 1,000 | 2,500 |
| Req/sec | 50 | 100 | 250 |
| Availability | 99% | 99.9% | 99.95% |
| P95 Response | 500ms | 300ms | 200ms |

### Cost vs. Performance

```
Instances: 1    2    3    5    10
Cost:      $7   $14  $21  $35  $70
Users:     500  1K   1.5K 2.5K 5K
$/User:    $14  $14  $14  $14  $14
```

## Next Steps

1. **Week 22:** Deploy with 2 instances
2. **Week 23:** Monitor and tune scaling
3. **Week 24:** Increase to 3-5 instances
4. **Month 6:** Evaluate auto-scaling effectiveness

---

**Created**: 2026-06-17
**Phase**: 4 - Performance & Scaling
