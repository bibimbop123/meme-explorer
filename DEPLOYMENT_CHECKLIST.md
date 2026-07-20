# Deployment Checklist

## Pre-Deployment

### Code Quality
- [ ] All tests passing (`bundle exec rspec`)
- [ ] RuboCop checks passing (`bundle exec rubocop`)
- [ ] Security scan clean (`bundle exec brakeman`)
- [ ] Dependency audit clean (`bundle audit`)
- [ ] Code reviewed and approved

### Database
- [ ] Migrations are reversible
- [ ] Migration tested on staging
- [ ] Backup strategy confirmed
- [ ] Index creation won't lock tables
- [ ] Data migration scripts tested

### Configuration
- [ ] Environment variables documented in `.env.example`
- [ ] Secrets rotated if needed
- [ ] Feature flags configured
- [ ] Rate limits reviewed
- [ ] Monitoring alerts configured

### Documentation
- [ ] CHANGELOG.md updated
- [ ] API documentation updated
- [ ] README updated if needed
- [ ] Runbook updated

## Deployment Process

### 1. Staging Deployment
```bash
# Deploy to staging
git push staging main

# Run migrations
heroku run bundle exec rake db:migrate --app meme-explorer-staging

# Smoke test
curl https://staging.memeexplorer.com/health
```

- [ ] Staging deployment successful
- [ ] Smoke tests passed
- [ ] Feature testing completed
- [ ] Performance acceptable

### 2. Production Deployment

```bash
# Enable maintenance mode
heroku maintenance:on --app meme-explorer

# Deploy to production
git push production main

# Run migrations
heroku run bundle exec rake db:migrate --app meme-explorer

# Restart workers
heroku ps:restart worker --app meme-explorer

# Disable maintenance mode
heroku maintenance:off --app meme-explorer
```

- [ ] Production deployment successful
- [ ] Health check passing
- [ ] Error rate normal
- [ ] Response times acceptable

## Post-Deployment

### Immediate (0-15 minutes)
- [ ] Health endpoint responding
- [ ] Error rate < 0.1%
- [ ] Response time p95 < 300ms
- [ ] No spike in error logs
- [ ] Critical user flows working (random meme, login, trending)

### Short-term (15-60 minutes)
- [ ] Background workers processing
- [ ] Redis pool healthy
- [ ] Database connection pool stable
- [ ] Memory usage normal
- [ ] No user complaints

### Medium-term (1-24 hours)
- [ ] Daily metrics normal
- [ ] No performance degradation
- [ ] AdSense revenue stable
- [ ] User retention normal

## Rollback Plan

### If Issues Detected

**Minor Issues (Error rate < 1%)**
- Monitor for 30 minutes
- Prepare hotfix if needed

**Major Issues (Error rate > 1% or critical feature broken)**
```bash
# Immediate rollback
git revert HEAD
git push production main

# Or revert to previous release
heroku releases:rollback --app meme-explorer

# Notify team
# Post-mortem within 24 hours
```

- [ ] Rollback executed
- [ ] System stable
- [ ] Post-mortem scheduled

## Monitoring Commands

```bash
# View logs
heroku logs --tail --app meme-explorer

# Check dyno status
heroku ps --app meme-explorer

# View recent releases
heroku releases --app meme-explorer

# Database status
heroku pg:info --app meme-explorer

# Redis status
heroku redis:info --app meme-explorer

# Worker queue depth
heroku run bundle exec rake sidekiq:stats --app meme-explorer
```

## Emergency Contacts

- **On-Call Engineer:** [Phone/Slack]
- **Database Admin:** [Contact]
- **DevOps Lead:** [Contact]
- **Product Manager:** [Contact]

## Post-Mortem Template

If rollback needed:

1. **What happened?**
2. **When was it detected?**
3. **What was the impact?**
4. **Root cause?**
5. **How was it resolved?**
6. **Action items to prevent recurrence**

---

**Last Updated:** July 19, 2026
