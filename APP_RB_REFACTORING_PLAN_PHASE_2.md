# app.rb Refactoring Plan - Phase 2
## Senior Developer Analysis & Incremental Execution

**Date:** June 2, 2026  
**Current State:** 2,607 lines, 61 inline helper methods  
**Target State:** ~500 lines (configuration + class definition only)  
**Approach:** Small, safe, incremental changes with testing

---

## 📊 Current Architecture Analysis

### What app.rb Actually Contains
```
Lines 1-100:    Requires, dependencies, module setup
Lines 100-300:  Configuration (Redis, cache, Sidekiq)
Lines 300-527:  Middleware, before/after filters, concerns
Lines 528-593:  Helper registrations + inline helper blocks (3 blocks)
Lines 593-2607: 61 inline helper methods + some routes
```

### ✅ What's Already Good
- Routes ARE being extracted (routes/ directory exists with separate files)
- Services exist (lib/services/)
- Helpers exist (lib/helpers/)
- Concerns exist (lib/concerns/)

### ❌ What Needs Refactoring
1. **61 inline helper methods** (should be in lib/helpers/)
2. **3 inline `helpers do` blocks** (lines 540, 589, 593)
3. **Complex before/after filters** (business logic should be in concerns)
4. **Configuration scattered** (should be in config/)

---

## 🎯 Refactoring Strategy (Incremental Chunks)

### **Chunk 1: Extract Session Helpers** (Week 1, Day 1-2)
**Lines to extract:** ~50-80 lines  
**Risk:** LOW (session management is isolated)  
**Impact:** Immediate readability improvement

**Steps:**
1. Identify all session-related helper methods
2. Create `lib/helpers/session_helpers.rb`
3. Move methods one at a time
4. Test after each move
5. Remove from app.rb
6. Require new file
7. Run tests
8. Commit

**Expected reduction:** 50-80 lines

---

### **Chunk 2: Extract Request/Response Helpers** (Week 1, Day 3-4)
**Lines to extract:** ~40-60 lines  
**Risk:** LOW (utility methods)  
**Impact:** Better organization

**Steps:**
1. Identify HTTP/request helper methods
2. Create `lib/helpers/request_helpers.rb`
3. Move methods incrementally
4. Test continuously
5. Commit

**Expected reduction:** 40-60 lines

---

### **Chunk 3: Extract Before/After Filter Logic** (Week 1, Day 5)
**Lines to extract:** ~100-150 lines  
**Risk:** MEDIUM (touches every request)  
**Impact:** Major maintainability improvement

**Steps:**
1. Create `lib/concerns/request_lifecycle.rb`
2. Extract before filter logic to concern methods
3. Extract after filter logic to concern methods
4. Keep filters in app.rb but call concern methods
5. Test thoroughly
6. Commit

**Expected reduction:** 100-150 lines

---

### **Chunk 4: Extract Cache Helpers** (Week 2, Day 1-2)
**Lines to extract:** ~60-80 lines  
**Risk:** LOW (caching is isolated)  
**Impact:** Better cache management

**Steps:**
1. Create `lib/helpers/cache_helpers.rb`
2. Move cache-related helpers
3. Test cache functionality
4. Commit

**Expected reduction:** 60-80 lines

---

### **Chunk 5: Extract User/Auth Helpers** (Week 2, Day 3-4)
**Lines to extract:** ~80-100 lines  
**Risk:** MEDIUM (authentication critical)  
**Impact:** Better security organization

**Steps:**
1. Create `lib/helpers/auth_helpers.rb` (if not exists)
2. Move user authentication helpers
3. Move authorization helpers
4. Test auth flows thoroughly
5. Commit

**Expected reduction:** 80-100 lines

---

### **Chunk 6: Consolidate Configuration** (Week 2, Day 5)
**Lines to extract:** ~150-200 lines  
**Risk:** LOW (one-time startup)  
**Impact:** Cleaner app.rb

**Steps:**
1. Create `config/initializers/redis.rb`
2. Create `config/initializers/cache.rb`
3. Create `config/initializers/middleware.rb`
4. Move configuration blocks
5. Test startup
6. Commit

**Expected reduction:** 150-200 lines

---

### **Chunk 7: Extract Remaining Helpers** (Week 3, Day 1-3)
**Lines to extract:** ~200-300 lines  
**Risk:** LOW-MEDIUM (various helpers)  
**Impact:** Final cleanup

**Steps:**
1. Identify all remaining inline helper methods
2. Group by functionality
3. Create appropriate helper files
4. Move systematically
5. Test each group
6. Commit frequently

**Expected reduction:** 200-300 lines

---

### **Chunk 8: Final Cleanup** (Week 3, Day 4-5)
**Lines to clean:** ~100-200 lines  
**Risk:** LOW (comments, whitespace, organization)  
**Impact:** Polish

**Steps:**
1. Remove dead code
2. Organize requires alphabetically
3. Add section comments
4. Remove duplicate requires
5. Final testing
6. Commit

**Expected reduction:** 100-200 lines

---

## 📈 Expected Progress

| Chunk | Days | Lines Removed | Cumulative | app.rb Size | Risk  |
|-------|------|---------------|------------|-------------|-------|
| Start | -    | 0             | 0          | 2,607       | -     |
| 1     | 2    | 65            | 65         | 2,542       | LOW   |
| 2     | 2    | 50            | 115        | 2,492       | LOW   |
| 3     | 1    | 125           | 240        | 2,367       | MED   |
| 4     | 2    | 70            | 310        | 2,297       | LOW   |
| 5     | 2    | 90            | 400        | 2,207       | MED   |
| 6     | 1    | 175           | 575        | 2,032       | LOW   |
| 7     | 3    | 250           | 825        | 1,782       | LOW   |
| 8     | 2    | 150           | 975        | 1,632       | LOW   |

**Target:** 1,500-1,600 lines removed  
**Timeline:** ~3 weeks of careful, incremental work  
**Final app.rb:** ~500-1,100 lines (configuration + class structure)

---

## 🛡️ Safety Protocols

### Before Each Chunk
1. ✅ Run full test suite
2. ✅ Git commit current state
3. ✅ Create feature branch

### During Each Chunk
1. ✅ Move ONE method at a time
2. ✅ Test after each move
3. ✅ Keep app running locally
4. ✅ Check for errors continuously

### After Each Chunk
1. ✅ Run full test suite
2. ✅ Test in browser (manual smoke test)
3. ✅ Git commit with descriptive message
4. ✅ Merge to main
5. ✅ Deploy to staging (optional)

---

## 🎯 Success Criteria

### Chunk Completion
- [ ] All tests pass
- [ ] App runs without errors
- [ ] No functionality broken
- [ ] Code is cleaner
- [ ] Git commit created

### Phase 2 Completion
- [ ] app.rb < 1,000 lines
- [ ] All inline helpers extracted
- [ ] Configuration organized
- [ ] Before/after filters simplified
- [ ] Full test suite passes
- [ ] Production deployment successful

---

## 🚀 Chunk 1: READY TO EXECUTE

**Target:** Session Helpers  
**Estimated Time:** 2-4 hours  
**Lines:** ~50-80  
**Risk:** LOW

**Ready to start Chunk 1?** I'll create the extraction plan with exact code changes.

---

## 💡 Senior Dev Principles Applied

1. **Small Batches** - Never move more than one concern at a time
2. **Continuous Testing** - Test after EVERY change
3. **Git Discipline** - Commit after each successful chunk
4. **Reversibility** - Every change can be rolled back
5. **Documentation** - Track progress as we go
6. **Production Safety** - Never break production
7. **Incremental Value** - Each chunk provides immediate benefit
8. **Team Communication** - Document what changed and why

---

**Next Action:** Approve to start Chunk 1, or request modifications to the plan.
