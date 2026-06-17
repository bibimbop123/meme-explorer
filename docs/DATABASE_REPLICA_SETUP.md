# Database Read Replica Setup

## Overview

Read replicas improve performance by:
- Offloading read queries from primary database
- Reducing primary database load by 50-80%
- Enabling higher concurrent user capacity
- Providing redundancy for disaster recovery

## Architecture

```
Application
├─→ Primary Database (writes + critical reads)
└─→ Read Replica(s) (bulk reads)
```

## Configuration

### Render.com (PostgreSQL)

1. **Upgrade to Standard Plan** (required for replicas)
2. **Create Read Replica**:
   - Dashboard → Database → Create Read Replica
   - Select same region as primary
   - Choose replica size (can be smaller than primary)
3. **Get Connection String**:
   - Copy "External Connection String"
   - Add to environment as `DATABASE_REPLICA_URL`

### AWS RDS

1. **Create Read Replica**:
   ```bash
   aws rds create-db-instance-read-replica \
       --db-instance-identifier meme-explorer-replica \
       --source-db-instance-identifier meme-explorer-primary \
       --db-instance-class db.t3.medium
   ```
2. **Get Endpoint**:
   ```bash
   aws rds describe-db-instances \
       --db-instance-identifier meme-explorer-replica \
       --query 'DBInstances[0].Endpoint.Address'
   ```

### Environment Variables

```bash
# Primary database (existing)
DATABASE_URL=postgresql://user:pass@primary.render.com/db

# Read replica (new)
DATABASE_REPLICA_URL=postgresql://user:pass@replica.render.com/db
```

## Usage in Services

### Automatic Routing

```ruby
# Read operations (automatically routed to replica)
class MemeService
  def self.get_trending(limit = 50)
    DatabaseRouter.read do |conn|
      conn.exec("SELECT * FROM meme_stats ORDER BY likes DESC LIMIT $1", [limit])
    end
  end
end

# Write operations (automatically routed to primary)
class MemeService
  def self.increment_views(url)
    DatabaseRouter.write do |conn|
      conn.exec("UPDATE meme_stats SET views = views + 1 WHERE url = $1", [url])
    end
  end
end

# Transactions (always on primary)
def save_meme_with_stats(meme_data)
  DatabaseRouter.transaction do |conn|
    conn.exec("INSERT INTO memes (...) VALUES (...)")
    conn.exec("INSERT INTO meme_stats (...) VALUES (...)")
  end
end
```

### Force Primary (for consistency)

```ruby
# Force next query to use primary (avoid replica lag)
def check_recent_update(user_id)
  DatabaseRouter.force_primary!
  user = UserService.find(user_id)
  DatabaseRouter.clear_force_primary!
  user
end
```

## Monitoring

### Check Replica Lag

```bash
# Run monitoring script
ruby scripts/monitor_replica_lag.rb

# Output:
# [14:23:45] Replica Lag: 0.12s ✅ Excellent
# [14:23:55] Replica Lag: 2.45s ✓ Good
```

### Automatic Lag Management

The system automatically:
- Disables replica if lag > 30 seconds
- Re-enables replica when lag < 5 seconds
- Falls back to primary if replica fails

### Metrics to Track

- **Replica Lag**: Target < 5 seconds
- **Read Query Distribution**: Target 70-80% on replica
- **Primary Load**: Should decrease by 50-70%
- **Query Response Time**: Should improve by 20-40%

## Troubleshooting

### High Replica Lag

**Symptoms**: Lag > 10 seconds consistently

**Solutions**:
1. Upgrade replica instance size
2. Reduce write load on primary
3. Check network latency between primary and replica
4. Verify replica isn't under heavy query load

### Replica Connection Failures

**Symptoms**: Errors connecting to replica

**Solutions**:
1. Check DATABASE_REPLICA_URL is correct
2. Verify firewall rules allow connection
3. Check replica is in running state
4. System automatically falls back to primary

### Inconsistent Reads

**Symptoms**: Users see stale data after updates

**Solutions**:
1. Use `force_primary!` for critical reads after writes
2. Reduce acceptable replica lag threshold
3. Add `after_write` hook to clear cache
4. Use cache with shorter TTL for frequently updated data

## Best Practices

### Do's ✅
- Route bulk reads to replica (trending, search, stats)
- Route writes to primary (updates, inserts, deletes)
- Use transactions on primary only
- Monitor replica lag continuously
- Set up alerts for high lag (> 10s)

### Don'ts ❌
- Don't read from replica immediately after write
- Don't use replica for critical real-time data
- Don't ignore replica lag warnings
- Don't run analytics queries on primary
- Don't use replica for session storage

## Performance Impact

### Expected Improvements

- **Primary Database Load**: -50% to -70%
- **Read Query Latency**: -20% to -40%
- **Concurrent Users**: +100% to +200%
- **Database CPU Usage**: -40% to -60% (primary)

### Costs

- **Render.com**: ~$25/month additional (Standard plan)
- **AWS RDS**: ~$50/month (t3.medium instance)
- **Bandwidth**: Minimal (replication traffic)

## Scaling Beyond One Replica

### Multiple Read Replicas

```ruby
# config/initializers/database_replicas.rb
DB_REPLICAS = [
  ConnectionPool.new { PG.connect(ENV['REPLICA_1_URL']) },
  ConnectionPool.new { PG.connect(ENV['REPLICA_2_URL']) },
  ConnectionPool.new { PG.connect(ENV['REPLICA_3_URL']) }
]

# Round-robin load balancing
def get_replica
  @replica_index = (@replica_index || 0) + 1
  DB_REPLICAS[@replica_index % DB_REPLICAS.length]
end
```

---

**Created**: 2026-06-17
**Phase**: 4 - Performance & Scaling
