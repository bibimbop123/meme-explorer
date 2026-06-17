# Redis Cluster Setup Guide

## Overview

Redis clustering provides:
- High availability through replication
- Automatic failover
- Horizontal scaling
- Better performance under load

## Architecture

```
Application
├─→ Redis Node 1 (Primary)
├─→ Redis Node 2 (Replica)
└─→ Redis Node 3 (Replica)
└─→ Memory Cache (Fallback)
```

## Configuration Options

### Option 1: Redis Cluster (Recommended for Production)

Best for: High traffic, mission-critical applications

**Setup on Render.com:**
1. Upgrade to Redis Premium
2. Enable clustering in dashboard
3. Get cluster endpoints
4. Configure application

**Environment Variables:**
```bash
REDIS_CLUSTER=true
REDIS_CLUSTER_URLS=redis://node1:6379,redis://node2:6379,redis://node3:6379
REDIS_POOL_SIZE=50
```

### Option 2: Redis Sentinel (High Availability)

Best for: Automatic failover without full clustering

**Setup:**
1. Deploy Redis with Sentinel
2. Configure sentinel nodes
3. Application connects via sentinel

**Environment Variables:**
```bash
REDIS_SENTINEL=true
REDIS_SENTINELS=sentinel1:26379,sentinel2:26379
REDIS_MASTER_NAME=mymaster
```

### Option 3: Single Instance with Fallback (Current)

Best for: Development, small applications

**Environment Variables:**
```bash
REDIS_URL=redis://localhost:6379/0
REDIS_POOL_SIZE=50
```

## Testing Failover

### Manual Test

```ruby
# In rails console or script
require_relative 'config/application'

# Test normal operation
RedisService.set_with_fallback('test_key', 'test_value')
puts RedisService.get_with_fallback('test_key')
# => "test_value"

# Simulate Redis failure
# (stop Redis service)

# Test fallback
RedisService.set_with_fallback('test_key_2', 'test_value_2')
puts RedisService.get_with_fallback('test_key_2')
# => "test_value_2" (from memory cache)
```

### Automated Test

```bash
ruby scripts/test_redis_failover.rb
```

## Monitoring

### Health Check

```ruby
# Check if Redis is available
RedisService.redis_healthy?
# => true or false

# Get Redis statistics
RedisService.redis_info
# => {version: "6.2.6", used_memory: "2.5M", ...}
```

### Metrics to Monitor

- **Connection Pool Usage**: Target < 80%
- **Response Time**: Target < 10ms
- **Hit Rate**: Target > 80%
- **Memory Usage**: Monitor for leaks
- **Eviction Rate**: Should be low

## Performance Tuning

### Connection Pool Size

```ruby
# Formula: (Number of Puma workers × Puma threads) + buffer
# Example: (2 workers × 5 threads) + 10 buffer = 20 connections
REDIS_POOL_SIZE=50  # Conservative default
```

### Key Expiration Strategy

```ruby
# Short-lived data (30 seconds to 5 minutes)
RedisService.set('trending_memes', data, ex: 300)

# Medium-lived data (1 to 24 hours)
RedisService.set('user_preferences', data, ex: 3600)

# Long-lived data (1 to 7 days)
RedisService.set('subreddit_stats', data, ex: 86400)
```

### Memory Management

```bash
# Set max memory in redis.conf
maxmemory 256mb
maxmemory-policy allkeys-lru
```

## Troubleshooting

### Connection Timeouts

**Symptoms**: Redis::TimeoutError

**Solutions**:
1. Increase pool size
2. Increase timeout setting
3. Check network latency
4. Review slow queries

### Memory Issues

**Symptoms**: Redis running out of memory

**Solutions**:
1. Review TTL on keys
2. Implement key expiration
3. Use SCAN instead of KEYS
4. Upgrade Redis instance size

### Cluster Split Brain

**Symptoms**: Inconsistent data across nodes

**Solutions**:
1. Check network connectivity
2. Verify cluster configuration
3. Use Redis Sentinel for failover
4. Monitor cluster health

## Best Practices

### Do's ✅
- Always set TTL on keys
- Use connection pooling
- Implement fallback to memory cache
- Monitor Redis health
- Use pipelines for bulk operations

### Don'ts ❌
- Don't use KEYS command in production
- Don't store large objects (> 1MB)
- Don't ignore connection pool exhaustion
- Don't forget to handle Redis failures
- Don't use Redis as primary data store

## Cost Comparison

### Render.com

- **Starter**: $7/month (256MB, single instance)
- **Standard**: $25/month (1GB, single instance)
- **Premium**: $100/month (4GB, clustering)

### AWS ElastiCache

- **cache.t3.micro**: $15/month
- **cache.t3.small**: $30/month
- **cache.m5.large**: $100/month (clustering)

### Upstash (Serverless)

- **Free**: 10K commands/day
- **Pay-as-you-go**: $0.20 per 100K commands

## Migration Path

### Phase 1: Add Failover (Current Phase)
- Implement memory cache fallback
- Add health monitoring
- Test failure scenarios

### Phase 2: Add Replication (Week 22)
- Set up Redis replicas
- Configure automatic failover
- Test failover process

### Phase 3: Full Clustering (Month 6)
- Deploy Redis Cluster
- Migrate data to cluster
- Update application for cluster support

---

**Created**: 2026-06-17
**Phase**: 4 - Performance & Scaling
