# Service Consolidation Plan
**Week 3:** Code Consolidation  
**Date:** July 26, 2026

## Overview

This plan outlines the step-by-step consolidation of 50+ services down to 20-30 core services.

## Consolidation Rules

1. **Keep Single Responsibility** - Each service should have ONE clear purpose
2. **Merge Similar Concerns** - Services doing related tasks should be combined
3. **Eliminate Duplication** - Remove duplicate code across services
4. **Maintain Backwards Compatibility** - Existing code should continue working

## Service Consolidation Examples

### Example 1: Gamification Services → One Service

**BEFORE** (4 services):
```ruby
# lib/services/milestone_service.rb
# lib/services/surprise_rewards_service.rb
# lib/services/surprise_mechanics_service.rb
# lib/services/near_miss_service.rb
```

**AFTER** (1 service):
```ruby
# File: lib/services/gamification_service.rb
module Services
  class GamificationService
    # Milestones
    def self.check_milestones(user_id)
      # Logic from milestone_service.rb
    end
    
    # Rewards
    def self.trigger_reward(user_id, type)
      # Logic from surprise_rewards_service.rb
    end
    
    # Mechanics
    def self.apply_mechanic(user_id, action)
      # Logic from surprise_mechanics_service.rb
    end
    
    # Near-miss
    def self.near_miss_check(score)
      # Logic from near_miss_service.rb
    end
  end
end
```

**Migration:**
```ruby
# Old code (still works):
MilestoneService.check(user_id)

# Add compatibility aliases:
MilestoneService = Services::GamificationService
SurpriseRewardsService = Services::GamificationService
```

### Example 2: Analytics Services → One Service

**BEFORE** (3 services):
- `metrics_tracker_service.rb`
- `activity_tracker_service.rb`
- `session_tracker_service.rb`

**AFTER** (1 service):
```ruby
# File: lib/services/analytics_service.rb
module Services
  class AnalyticsService
    # Metrics tracking
    def self.track_metric(name, value, tags = {})
      # From metrics_tracker_service.rb
    end
    
    # Activity tracking
    def self.track_activity(user_id, action, data = {})
      # From activity_tracker_service.rb
    end
    
    # Session tracking
    def self.track_session(session_id, event)
      # From session_tracker_service.rb
    end
  end
end
```

## Step-by-Step Consolidation

### Step 1: Create New Consolidated Service
```bash
# Create the new merged service file
touch lib/services/gamification_service.rb
```

### Step 2: Copy & Merge Logic
```ruby
# Copy methods from all related services
# Organize by functionality
# Remove duplicates
# Add clear comments
```

### Step 3: Add Backwards-Compatible Aliases
```ruby
# At bottom of new service file:
MilestoneService = Services::GamificationService
SurpriseRewardsService = Services::GamificationService
```

### Step 4: Test
```bash
# Run tests to ensure nothing broke
bundle exec rspec spec/services/gamification_service_spec.rb
```

### Step 5: Move Old Services to Archive
```bash
mkdir -p lib/services/archived/2026-week3
mv lib/services/milestone_service.rb lib/services/archived/2026-week3/
mv lib/services/surprise_rewards_service.rb lib/services/archived/2026-week3/
```

## Testing Strategy

For each consolidated service:

1. **Unit Tests** - Test all methods work
2. **Integration Tests** - Test service interacts with others
3. **Backwards Compatibility** - Test old code still works
4. **Performance** - Ensure no performance degradation

## Rollback Plan

If consolidation causes issues:

1. **Restore from archive:**
   ```bash
   mv lib/services/archived/2026-week3/*.rb lib/services/
   ```

2. **Remove consolidated service:**
   ```bash
   rm lib/services/gamification_service.rb
   ```

3. **Restart application**

## Benefits

- **Less Files** - Easier to navigate
- **Less Duplication** - DRYer code
- **Faster Onboarding** - New devs learn 20 services, not 50
- **Easier Refactoring** - Changes in one place
- **Better Testing** - Test one service instead of many

## Timeline

- **Monday:** Gamification, Analytics merges (4-6 hours)
- **Tuesday:** Media, Meme services (4-6 hours)
- **Wednesday:** Migration cleanup (4 hours)
- **Thursday-Friday:** Testing & documentation (8 hours)

---
**Next:** See `SERVICE_ANALYSIS_WEEK3.md` for detailed inventory
