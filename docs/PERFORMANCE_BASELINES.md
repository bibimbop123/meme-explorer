# Performance Baselines - Meme Explorer

**Last Updated:** 2026-06-26  
**Next Review:** 2026-07-26  
**Status:** Initial Baseline

---

## 📊 Response Times

### P50/P95/P99 Percentiles (Target)
- **Homepage:** 200ms / 500ms / 800ms
- **Random Meme:** 150ms / 400ms / 700ms
- **Search:** 300ms / 800ms / 1200ms
- **Trending:** 250ms / 600ms / 900ms
- **User Profile:** 200ms / 500ms / 800ms
- **Collections:** 250ms / 600ms / 900ms

### Alert Thresholds
- **Warn:** P95 > 2x baseline
- **Critical:** P95 > 3x baseline

---

## 🗄️ Database Performance

### Query Performance
- **Average Query Time:** <20ms
- **P95 Query Time:** <100ms
- **P99 Query Time:** <200ms
- **Slow Query Threshold:** >200ms

### Connection Pool
- **Pool Size:** 25 connections
- **Checkout Time:** <50ms average
- **Queue Time:** <10ms average

### Database Size
- **Total Size:** ~500MB (will grow)
- **Largest Tables:**
  - `cached_memes`: ~200MB
  - `users`: ~50MB
  - `user_sessions`: ~30MB

---

## 💾 Cache Performance

### Hit Rates (Target)
- **Meme Cache:** >80%
- **User Session Cache:** >95%
- **Trending Cache:** >90%
- **API Response Cache:** >75%

### Redis Metrics
- **Memory Usage:** ~256MB baseline
- **Keys:** ~10,000-50,000
- **Average Operation Time:** <5ms
- **Eviction Rate:** <1% per hour

---

## 🖥️ Resource Usage

### Memory
- **Baseline:** ~512MB
- **Under Load:** <1GB
- **Critical Threshold:** >1.5GB
- **Alert Threshold:** >1.2GB

### CPU
- **Baseline:** <20%
- **Average:** <30%
- **Peak:** <70%
- **Critical Threshold:** >80% for >5 minutes

### Disk I/O
- **Read:** <30 MB/s average
- **Write:** <20 MB/s average
- **Peak:** <100 MB/s

---

## 🌐 External Services

### Reddit API
- **Response Time:** <500ms
- **Timeout:** 10s
- **Retry Strategy:** 3 attempts with exponential backoff
- **Circuit Breaker:** Open after 5 consecutive failures

### PostgreSQL
- **Connection Time:** <50ms
- **Query Time:** <20ms average
- **Replication Lag:** N/A (single instance)

### Redis
- **Connection Time:** <10ms
- **Operation Time:** <5ms average
- **Failover:** No replica configured

---

## 📈 Traffic Patterns

### Daily Patterns
- **Peak Hours:** 6-10 PM local time
- **Off-Peak:** 2-6 AM local time
- **Weekend vs Weekday:** +30% weekend traffic

### Request Volume
- **Average:** 100-200 req/min
- **Peak:** 500-800 req/min
- **Burst Capacity:** 1000 req/min

### User Behavior
- **Average Session:** 8-12 minutes
- **Pages Per Session:** 15-25
- **Bounce Rate:** <35%

---

## 🎯 SLO (Service Level Objectives)

### Availability
- **Target:** 99.5% uptime
- **Monthly Downtime Budget:** 3.6 hours
- **Planned Maintenance:** Off-peak hours only

### Performance
- **P95 Response Time:** <800ms
- **P99 Response Time:** <2000ms
- **Error Rate:** <1%

### Reliability
- **Failed Requests:** <0.5%
- **Timeout Rate:** <0.1%
- **5xx Errors:** <0.1%

---

## 🔍 Monitoring Checklist

### Real-Time Monitoring
- [ ] Response times by endpoint
- [ ] Error rates
- [ ] Cache hit rates
- [ ] Database query performance
- [ ] External API response times

### Daily Checks
- [ ] Review slow queries
- [ ] Check error patterns
- [ ] Verify backup completion
- [ ] Review resource usage trends
- [ ] Check alert history

### Weekly Review
- [ ] Performance trends
- [ ] Capacity planning
- [ ] Cost optimization
- [ ] Feature usage metrics

### Monthly Review
- [ ] Update baselines
- [ ] Capacity planning
- [ ] Performance improvements
- [ ] SLO compliance

---

## 📝 Measurement Methodology

### How to Measure

1. **Response Times:**
   ```ruby
   PerformanceTracker.track('operation_name') do
     # operation code
   end
   ```

2. **Database Queries:**
   - Enable PostgreSQL slow query log
   - Review `pg_stat_statements`
   - Monitor with PerformanceTracker

3. **Cache Hit Rates:**
   ```ruby
   # Track cache hits/misses
   RedisService.get_with_tracking(key)
   ```

4. **Resource Usage:**
   - Monitor via Render dashboard
   - Set up external monitoring (optional)
   - Review application metrics

---

## 🚨 Alert Conditions

### Critical Alerts (Page Immediately)
- **Site Down:** >1% of requests failing
- **Database Down:** Can't connect
- **Severe Performance Degradation:** P95 >5x baseline
- **Memory Exhaustion:** >90% memory used

### Warning Alerts (Review Within Hours)
- **Elevated Error Rate:** >2% of requests
- **Slow Performance:** P95 >2x baseline
- **High Memory:** >75% memory used
- **Slow Database Queries:** >10% queries over threshold

### Info Alerts (Review Daily)
- **Cache Performance:** Hit rate <target
- **API Slowness:** External APIs responding slowly
- **Resource Trends:** Gradual increase in usage

---

## 📊 Baseline Data Collection

### Initial Measurement Period: Week of 2026-06-26

**To establish accurate baselines:**

1. Deploy performance tracking
2. Collect data for 7 days
3. Calculate percentiles
4. Update this document
5. Set alert thresholds

**Data to collect:**
- Request durations (all endpoints)
- Database query times
- Cache hit/miss ratios
- Resource usage patterns
- Error rates and types
- Traffic patterns

---

## 🔄 Review Schedule

- **Daily:** Check alerts and anomalies
- **Weekly:** Review performance trends
- **Monthly:** Update baselines and SLOs
- **Quarterly:** Major performance review

---

## 📈 Historical Changes

### 2026-06-26: Initial Baseline
- Created initial baseline document
- Deployed performance tracking
- Set initial target values
- **Next:** Collect 7 days of data

### Future Updates
- Update this section after each baseline review
- Document major performance changes
- Track optimization impact

---

## 🎯 Improvement Targets

### Q3 2026 Goals
- Reduce P95 response time by 20%
- Achieve >85% cache hit rate
- Reduce database query time by 30%
- Implement automated alerting

### Q4 2026 Goals
- Achieve 99.9% uptime
- P95 <500ms for all endpoints
- <0.5% error rate
- Scale to 2x current traffic

---

**NOTE:** These are initial target baselines. Update this document after collecting real production data for at least 7 days.
