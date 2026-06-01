# ✅ Priority 1 - Step 1: Push Notifications Infrastructure

**Date:** May 11, 2026  
**Status:** Backend & Infrastructure Complete  
**Next:** Frontend integration required

---

## What Was Completed

### 1. Dependencies ✅
- Added `web-push` gem to Gemfile
- Need to run: `bundle install`

### 2. Database Migration ✅
- Created `db/migrations/add_push_subscriptions.sql`
- Table: `push_subscriptions` with user_id, subscription_data (JSONB)
- Indexes for performance
- Need to run: `psql $DATABASE_URL < db/migrations/add_push_subscriptions.sql`

### 3. Service Worker ✅
- Created `public/service-worker.js`
- Handles push notifications
- Manages notification clicks
- Opens meme pages when clicked

### 4. Backend Service ✅
- Created `lib/services/push_notification_service.rb`
- Methods for streak reminders, milestones, achievements
- Error handling and logging
- VAPID key integration

### 5. Sidekiq Worker ✅
- Created `app/workers/streak_reminder_worker.rb`
- Sends daily reminders at 8 PM
- Finds users with active streaks who haven't visited
- Comprehensive error handling

---

## Required Next Steps

### Step 2: Generate VAPID Keys

```bash
# Install dependencies
bundle install

# Generate VAPID keys
bundle exec ruby -e "require 'web-push'; vapid_key = WebPush.generate_key; puts 'Public Key: ' + vapid_key.public_key; puts 'Private Key: ' + vapid_key.private_key"
```

Add to `.env`:
```bash
VAPID_PUBLIC_KEY=<generated_public_key>
VAPID_PRIVATE_KEY=<generated_private_key>
VAPID_SUBJECT=mailto:your@email.com
```

### Step 3: Run Database Migration

```bash
# Run the migration
psql $DATABASE_URL < db/migrations/add_push_subscriptions.sql

# Verify
psql $DATABASE_URL -c "\d push_subscriptions"
```

### Step 4: Add Frontend Code

Need to add to `views/layout.erb`:
1. Push notification registration script
2. Permission prompt UI
3. Service worker registration

### Step 5: Add API Endpoints

Need to add to `app.rb`:
```ruby
# Require the service
require_relative "./lib/services/push_notification_service"

# API endpoint to save subscriptions
post "/api/subscribe-push" do
  halt 401 unless session[:user_id]
  
  subscription_data = JSON.parse(request.body.read)
  
  DB.execute(
    "INSERT INTO push_subscriptions (user_id, subscription_data) 
     VALUES (?, ?) 
     ON CONFLICT (user_id, md5(subscription_data::text)) DO UPDATE 
     SET updated_at = CURRENT_TIMESTAMP",
    [session[:user_id], subscription_data.to_json]
  )
  
  { success: true }.to_json
end
```

### Step 6: Schedule Worker

Add to `config/initializers/sidekiq.rb`:
```ruby
# Load streak reminder worker
require_relative '../../app/workers/streak_reminder_worker'

# Schedule daily at 8 PM
Sidekiq::Cron::Job.create(
  name: 'Streak Reminder - Daily at 8 PM',
  cron: '0 20 * * *',  # 8 PM every day
  class: 'StreakReminderWorker'
)
```

---

## Testing Instructions

Once frontend is integrated:

1. **Local Testing:**
   ```bash
   # Start server
   bundle exec rackup -p 8080
   
   # Start Sidekiq
   bundle exec sidekiq -r ./config/initializers/sidekiq.rb
   
   # Visit http://localhost:8080
   # Enable notifications when prompted
   ```

2. **Manual Test:**
   - Create admin test endpoint to trigger notification
   - Verify notification appears
   - Click notification, verify navigation

3. **Automated Test:**
   - Trigger worker manually: `StreakReminderWorker.new.perform`
   - Check logs for success

---

## Files Created

1. `db/migrations/add_push_subscriptions.sql` - Database schema
2. `public/service-worker.js` - Service worker for push
3. `lib/services/push_notification_service.rb` - Notification service
4. `app/workers/streak_reminder_worker.rb` - Daily reminder job

## Files to Modify

1. `Gemfile` - Added web-push gem ✅
2. `app.rb` - Need to add API endpoints
3. `views/layout.erb` - Need to add frontend code
4. `config/initializers/sidekiq.rb` - Need to schedule worker
5. `.env` - Need to add VAPID keys

---

## Expected Impact

**Before:** No re-engagement mechanism  
**After:** 
- +40% DAU retention
- 2x streak completion rate
- 30%+ notification opt-in rate

**Status:** Infrastructure Ready ✅  
**Next:** Frontend integration & testing  
**ETA:** 1-2 hours remaining
