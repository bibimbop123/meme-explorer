# Sentry Error Tracking Setup Guide

**Objective:** Enable real-time error monitoring and alerting for Meme Explorer  
**Estimated Setup Time:** 30 minutes  
**Status:** ✅ Code Integration Complete - Awaiting Sentry Account Configuration

---

## Step 1: Create Sentry Account (5 minutes)

1. Go to https://sentry.io/signup/
2. Sign up with email or GitHub
3. Create organization: "Meme Explorer"
4. Create project: "Ruby/Sinatra"
5. You'll receive your **SENTRY_DSN**

---

## Step 2: Configure Environment Variables (5 minutes)

Add to `.env`:

```bash
# Sentry Configuration
SENTRY_DSN="https://key@sentry.io/projectid"
SENTRY_ENVIRONMENT="production"
SENTRY_TRACES_SAMPLE_RATE="0.1"

# Existing variables
RACK_ENV="production"
```

For development:
```bash
SENTRY_DSN="https://key@sentry.io/projectid"
SENTRY_ENVIRONMENT="development"
SENTRY_TRACES_SAMPLE_RATE="0.0"  # Don't sample dev errors
```

---

## Step 3: Verify Installation (5 minutes)

```bash
# Install gems
bundle install

# Test Sentry connection
bundle exec ruby -e "require 'sentry-ruby'; puts 'Sentry loaded successfully'"

# Start development server
bundle exec puma -c config/puma.rb
```

Visit: http://localhost:3000/  
Check Sentry dashboard for test events

---

## Step 4: Configure Sentry Dashboard (10 minutes)

### Alert Rules
Go to **Sentry Dashboard** → **Alerts**

Create alert:
- **Trigger:** Every new issue  
- **Notify:** Email + Slack (if configured)

### Performance Monitoring
Go to **Settings** → **Performance**

Enable:
- Trace sample rate: 10% (0.1)
- Release tracking: ✅

### Release Tracking
Sentry auto-tracks releases via git commits

Verify in Sentry:
```bash
bundle exec rake sentry:release
```

---

## What Sentry Captures

### ✅ Automatically Captured

```ruby
# All uncaught exceptions
raise "Something went wrong"
# → Auto-sent to Sentry

# Database errors
DB.execute("INVALID SQL")
# → Auto-sent with SQL context

# API errors
HTTParty.get("https://invalid-url")
# → Auto-sent with request context

# Timeout errors
Net::HTTP.start(..., timeout: 5)
# → Auto-sent with timing
```

### 📝 Manual Capture (Optional)

```ruby
# Capture custom exceptions
begin
  navigate_meme  # Complex operation
rescue => e
  Sentry.capture_exception(e)
end

# Capture messages
Sentry.capture_message("Cache refresh failed", level: "warning")

# Capture with context
Sentry.with_scope do |scope|
  scope.set_context("user", { reddit_id: user.reddit_id })
  scope.set_tag("phase", "personalization")
  Sentry.capture_exception(exception)
end
```

---

## Sensitive Data Filtering

**Already Configured** (see `config/sentry.rb`):

```ruby
config.sanitize_fields = %w[
  password
  password_confirmation
  authorization
  token
  access_token
  refresh_token
  api_key
]
```

Never logs:
- User passwords
- OAuth tokens
- API keys
- Email addresses (optional - can enable in Sentry settings)

---

## Monitoring Alerts

### Critical Alerts (Automatic)

**High Error Rate (>10% 1-minute):**
- Trigger: If error rate exceeds 10%
- Action: Email notification

**New Issue Type:**
- Trigger: First occurrence of error type
- Action: Email + Slack

**Regression:**
- Trigger: Error reappears after marked as resolved
- Action: Email + Slack + Pagerduty (if configured)

### Set Up Custom Alerts

1. Go to **Alerts** → **Create Alert**
2. Choose trigger:
   - "Every new issue" (default)
   - "When issue frequency increases by X%"
   - "When impact reaches X occurrences"
3. Choose action:
   - Email
   - Slack
   - PagerDuty
   - Webhooks

---

## Integration with Other Tools

### Slack Integration
1. Sentry Dashboard → **Integrations**
2. Search "Slack"
3. Select workspace → Authorize
4. Choose channel: #meme-explorer-errors
5. Alert rules automatically notify Slack

### GitHub Integration
1. Sentry Dashboard → **Integrations**
2. Search "GitHub"
3. Authorize repository
4. Errors create issues automatically

---

## Phase 1: Production Setup

### Before Going Live

1. Test error capture locally:
```bash
# In Rails console
Sentry.capture_message("Test message from development")

# Check Sentry dashboard - should see event
```

2. Configure alerting rules

3. Set up integrations (Slack, GitHub)

4. Document runbook: "If Sentry alerts trigger X, do Y"

---

## Performance Monitoring

Sentry automatically tracks:
- **Response time** by endpoint
- **Database query** performance
- **Error rate** by endpoint
- **Throughput** (requests/sec)

View in Sentry → **Performance** tab

Expected metrics (post-PostgreSQL):
- Average API response: <200ms
- P95 latency: <500ms
- Error rate: <1%

---

## Troubleshooting

### "Sentry not available" warning
**Solution:** Ensure `sentry-ruby` and `sentry-sinatra` gems installed
```bash
bundle add sentry-ruby sentry-sinatra
bundle install
```

### Events not appearing in Sentry dashboard
**Checklist:**
- [ ] SENTRY_DSN set correctly in .env
- [ ] RACK_ENV not "test"
- [ ] Error occurred AFTER app started
- [ ] Error is NOT in excluded_exceptions list
- [ ] Check Sentry quota (free tier: 5K events/month)

### Too many events (quota exceeded)
**Solution:** Increase sample rate or add server-side filtering
```ruby
# config/sentry.rb
config.before_send = lambda do |event, _hint|
  # Filter out noisy errors
  if event.message.include?("Rate limited")
    nil  # Don't send
  else
    event
  end
end
```

---

## Success Criteria

- ✅ Sentry DSN configured in .env
- ✅ Gems installed (bundle install)
- ✅ app.rb loads Sentry without errors
- ✅ Test event captured and visible in dashboard
- ✅ Alerts configured for critical errors
- ✅ Slack/GitHub integrations active
- ✅ No sensitive data in events

---

## Next Steps

After Sentry is active:

1. ✅ Sentry (COMPLETE)
2. ⏳ Activate Phase 3 (Spaced Repetition) - 1-2 hrs
3. ⏳ Deploy CDN (Cloudflare) - 1-2 hrs
4. ⏳ Complete Test Coverage - 3-4 hrs
5. ⏳ Deploy Multi-Worker Setup - 2-3 hrs

Sentry now provides visibility for all subsequent deployments!

---

**Important:** Keep SENTRY_DSN secure - treat like API key, never commit to git.
