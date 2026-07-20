# Incident Response Playbook

## Severity Levels

### SEV-1: Critical (Production Down)
- **Response Time:** < 15 minutes
- **Examples:** Site completely down, data breach, major security incident
- **Actions:** Page on-call, assemble war room, notify stakeholders

### SEV-2: High (Major Degradation)
- **Response Time:** < 1 hour
- **Examples:** Slow response times (>2s), partial outage, auth broken
- **Actions:** Notify on-call, investigate, consider rollback

### SEV-3: Medium (Minor Impact)
- **Response Time:** < 4 hours
- **Examples:** Non-critical feature broken, occasional errors
- **Actions:** Create ticket, fix in next deploy

### SEV-4: Low (Minimal Impact)
- **Response Time:** < 24 hours
- **Examples:** UI glitch, logging issue, minor bug
- **Actions:** Backlog item, fix when convenient

## Common Incidents

### 1. Site Down / 500 Errors

**Symptoms:** High error rate, health check failing

**Immediate Actions:**
```bash
# Check application logs
heroku logs --tail --app meme-explorer | grep ERROR

# Check dyno status
heroku ps --app meme-explorer

# Check database
heroku pg:info --app meme-explorer

# Check Redis
heroku redis:info --app meme-explorer
```

**Common Causes:**
- Database connection exhaustion
- Redis connection timeout
- Out of memory (dyno R14 error)
- Bad deployment

**Resolution:**
1. Restart dynos if needed
2. Scale up if resource constrained
3. Rollback if bad deployment
4. Fix root cause

### 2. Slow Performance

**Symptoms:** p95 response time > 2s

**Immediate Actions:**
```bash
# Check slow queries
heroku pg:outliers --app meme-explorer

# Check worker queue
heroku run bundle exec rake sidekiq:stats --app meme-explorer

# Monitor in real-time
heroku logs --tail --source app --app meme-explorer
```

**Common Causes:**
- N+1 queries
- Missing database indexes
- Worker queue backup
- Reddit API slow/down

**Resolution:**
1. Identify slow endpoint
2. Check for N+1 queries
3. Add indexes if needed
4. Scale workers if queued

### 3. Redis Connection Errors

**Symptoms:** `Redis::CannotConnectError`, viewing history broken

**Immediate Actions:**
```bash
# Check Redis status
heroku redis:info --app meme-explorer

# Check connection pool
heroku run bundle exec irb -r ./config/application <<< "Redis.new.ping"

# Restart Redis (last resort)
heroku redis:restart --app meme-explorer
```

**Common Causes:**
- Connection pool exhaustion
- Redis instance restarting
- Network issues
- Memory eviction

**Resolution:**
1. Check connection pool size
2. Look for connection leaks
3. Review Redis memory usage
4. Implement circuit breaker

### 4. Background Jobs Failing

**Symptoms:** Jobs not processing, queue building up

**Immediate Actions:**
```bash
# Check worker status
heroku ps:scale worker=2 --app meme-explorer

# Check failed jobs
heroku run bundle exec rake sidekiq:failed --app meme-explorer

# View worker logs
heroku logs --ps worker --app meme-explorer
```

**Common Causes:**
- Worker dyno crashed
- Reddit API rate limit
- Database deadlock
- Memory leak

**Resolution:**
1. Restart workers
2. Clear failed queue if appropriate
3. Fix underlying issue
4. Add retry logic

### 5. Reddit API Issues

**Symptoms:** No new memes, API errors in logs

**Immediate Actions:**
```bash
# Check Reddit API status
curl -H "User-Agent: MemeExplorer/1.0" https://www.reddit.com/api/v1/me

# Check rate limits
heroku run bundle exec rake reddit:check_limits --app meme-explorer

# Review logs
heroku logs --tail | grep Reddit
```

**Common Causes:**
- Rate limiting (60 requests/minute)
- OAuth token expired
- Reddit API maintenance
- IP blocked

**Resolution:**
1. Implement backoff strategy
2. Rotate OAuth tokens
3. Check Reddit status page
4. Contact Reddit if needed

## War Room Protocol

### When to Activate
- SEV-1 incidents
- SEV-2 lasting > 30 minutes
- Multiple concurrent incidents

### Roles
- **Incident Commander:** Coordinates response
- **Engineer:** Investigates and fixes
- **Communicator:** Updates stakeholders
- **Scribe:** Documents timeline

### Communication
- Create Slack channel: `#incident-YYYY-MM-DD`
- Update status page every 15 minutes
- Notify users if downtime > 15 minutes

## Post-Incident

### Post-Mortem (Within 48 hours)

**Template:**
1. **Timeline:** What happened when?
2. **Impact:** Users affected, duration, data loss?
3. **Root Cause:** Why did it happen?
4. **Resolution:** How was it fixed?
5. **Action Items:** How to prevent recurrence?

### Blame-Free Culture
- Focus on systems, not individuals
- Learn from mistakes
- Implement safeguards
- Share learnings

## Monitoring & Alerts

### Key Metrics to Watch
- Error rate (target: < 0.1%)
- Response time p95 (target: < 300ms)
- Database connections (alert if > 80%)
- Redis memory (alert if > 90%)
- Worker queue depth (alert if > 1000)

### Alert Channels
- PagerDuty for SEV-1/SEV-2
- Slack for SEV-3/SEV-4
- Email for daily summaries

## Useful Commands

```bash
# Emergency scaling
heroku ps:scale web=5 worker=3 --app meme-explorer

# Emergency rollback
heroku releases:rollback --app meme-explorer

# Force restart
heroku restart --app meme-explorer

# Database backup
heroku pg:backups:capture --app meme-explorer

# View metrics
heroku metrics --app meme-explorer

# Console access
heroku run bundle exec irb -r ./config/application --app meme-explorer
```

---

**Last Updated:** July 19, 2026  
**Next Review:** October 19, 2026
