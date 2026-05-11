# 🎯 P2 Implementation Plan (THIS MONTH)
**Date:** May 11, 2026  
**Timeline:** 2-4 weeks  
**Goal:** Improve architecture, scalability, and data-driven decisions

---

## 📋 P2 Priorities (Ranked by Impact)

### Priority 1: SQL Query Optimization ⚡
**Effort:** 2-4 hours  
**Impact:** HIGH  
**Status:** READY TO IMPLEMENT

**Quick Wins:**
1. Move sorting from Ruby to SQL
2. Use calculated columns for trending scores
3. Add aggregation at database level
4. Remove N+1 query patterns

### Priority 2: App.rb Refactoring 🏗️
**Effort:** 8-12 hours  
**Impact:** HIGH (long-term)  
**Status:** REQUIRES PLANNING

**Approach:**
- Phase 1: Extract routes to modules (2 hours)
- Phase 2: Create proper controllers (4 hours)
- Phase 3: Extract models (2 hours)
- Phase 4: Clean up helpers (2 hours)

### Priority 3: A/B Testing Framework 🧪
**Effort:** 4-6 hours  
**Impact:** MEDIUM  
**Status:** READY TO IMPLEMENT

**Features:**
- Variant assignment (consistent hashing)
- Conversion tracking
- Simple analytics
- Admin dashboard

### Priority 4: Background Jobs (Sidekiq) 🔄
**Effort:** 4-6 hours  
**Impact:** MEDIUM  
**Status:** REQUIRES SETUP

**Requirements:**
- Redis (already available)
- Sidekiq gem
- Worker classes
- Job scheduling

### Priority 5: Monitoring 📊
**Effort:** 2-3 hours  
**Impact:** MEDIUM  
**Status:** READY TO IMPLEMENT

**Options:**
- New Relic (free tier)
- Scout APM (Rails-focused)
- Sentry Performance (already have Sentry)

---

## 🚀 Implementation Order

### Week 1: Quick Wins (4-6 hours)
- [ ] SQL query optimization
- [ ] A/B testing framework
- [ ] Basic monitoring setup

### Week 2: Architecture (8-12 hours)
- [ ] Extract routes to modules
- [ ] Create controller structure
- [ ] Begin model extraction

### Week 3: Scalability (4-6 hours)
- [ ] Add Sidekiq
- [ ] Convert threads to workers
- [ ] Job scheduling

### Week 4: Polish (2-4 hours)
- [ ] Documentation
- [ ] Testing
- [ ] Deployment

---

## ✅ TODAY: Start with SQL Optimization

This provides immediate value with minimal risk.

**Target Queries:**
1. Trending memes (sort in Ruby → SQL)
2. Leaderboard (already good with indexes)
3. Search results (add relevance scoring)
4. Profile stats (aggregate in SQL)

**Estimated Time:** 2 hours  
**Risk:** LOW  
**Benefit:** 20-30% additional performance gain
