# 🚀 DEPLOY TIER CATEGORIZATION FIX TO PRODUCTION
## July 5, 2026 - Step-by-Step Deployment Guide

## ✅ What Was Fixed (Locally)

The automated script successfully:
1. ✅ Added `categorize_by_tier()` method to MemePoolManager
2. ✅ Added `load_subreddit_tier_map()` method
3. ✅ Added `get_tier_pool()` method  
4. ✅ Replaced `store_in_pool()` with tiered version
5. ✅ Created backup: `lib/services/meme_pool_manager.rb.backup.1783280626`

---

## 📋 DEPLOYMENT STEPS

### Step 1: Commit Changes to Git

```bash
git add lib/services/meme_pool_manager.rb
git add scripts/deploy_tier_categorization_fix_july_5.rb
git add scripts/clear_all_pools.rb
git add TIER_CATEGORIZATION_FIX_COMPLETE_JULY_5_2026.md
git add DEPLOY_TIER_FIX_TO_PRODUCTION.md

git commit -m "Fix: Add tier categorization to MemePoolManager (July 5, 2026)

- Added categorize_by_tier() to separate memes by subreddit tier
- Added load_subreddit_tier_map() to load tier mapping from YAML
- Added get_tier_pool() to retrieve tier-specific pools
- Updated store_in_pool() to use separate Redis keys per tier
- Fixes repetition issue caused by single-pool clustering

Resolves: Meme pool lacking tier diversity
Impact: Enables proper tier distribution (fresh/surprise/diverse)"

git push origin main
```

### Step 2: Deploy to Render

**Option A: Automatic Deploy (if enabled)**
- Push triggers automatic deployment
- Wait ~3-5 minutes for build to complete

**Option B: Manual Deploy**
1. Go to [Render Dashboard](https://dashboard.render.com)
2. Select your `meme-explorer` service
3. Click **"Manual Deploy"** → **"Clear build cache & deploy"**
4. Wait for deployment to complete (~3-5 minutes)

### Step 3: Clear Redis Pools (IMPORTANT!)

Once deployment completes, **immediately** clear all pools via Render Shell:

```bash
# Open Render Shell (Dashboard → Service → Shell tab)

# Run the cleanup script
ruby scripts/clear_all_pools.rb

# You should see:
#   ✅ Cleared: meme_pool
#   ✅ Cleared: meme_pool:count
#   ✅ Cleared: meme_pool:fresh
#   (etc...)
```

### Step 4: Verify the Fix

**Monitor Render logs for these success indicators:**

```
✅ GOOD SIGNS:
📊 [PoolManager] Categorized: fresh=35, surprise=40, diverse=26
   ✅ Stored 35 memes in 'fresh' pool (total: 35)
   ✅ Stored 40 memes in 'surprise' pool (total: 40)
   ✅ Stored 26 memes in 'diverse' pool (total: 26)

❌ BAD SIGNS (should NOT see these anymore):
⚠️  Pool 'fresh' only has 0 memes, using all unseen (99)
⚠️  Pool 'surprise' only has 0 memes
```

**Test on production site:**
1. Visit your live site `/random` endpoint
2. Click through 10-15 memes
3. Verify you see **variety** across different subreddits and content types
4. Should NOT see same memes repeating

---

## 📊 Expected Results

### Before Fix:
```
[PoolManager] Pool empty, bootstrapping with 500 memes...
⚠️  Pool 'fresh' only has 0 memes, using all unseen (99)
⚠️  Pool 'surprise' only has 0 memes, using all unseen (99)
```
**Result**: All 99 memes in single bucket → clustering → repetition

### After Fix:
```
[PoolManager] Pool empty, bootstrapping with 500 memes...
📊 [PoolManager] Categorized: fresh=35, surprise=40, diverse=26
   ✅ Stored 35 memes in 'fresh' pool (total: 35)
   ✅ Stored 40 memes in 'surprise' pool (total: 40)
   ✅ Stored 26 memes in 'diverse' pool (total: 26)
```
**Result**: Proper tier distribution → diversity → no more repetition!

---

## 🔄 Rollback (If Needed)

If something goes wrong:

```bash
# Restore backup
cp lib/services/meme_pool_manager.rb.backup.1783280626 lib/services/meme_pool_manager.rb

# Commit rollback
git add lib/services/meme_pool_manager.rb
git commit -m "Rollback: Revert tier categorization changes"
git push origin main

# Clear Redis pools again
ruby scripts/clear_all_pools.rb
```

---

## 🎯 Summary

**Problem**: MemePoolManager lacked tier categorization, causing all memes to cluster in single pool

**Solution**: Added 3 new methods + updated store_in_pool() to use separate Redis keys per tier

**Impact**: 
- ✅ Proper tier distribution (fresh/surprise/diverse)
- ✅ Diversity Engine can now function correctly
- ✅ No more repetitive memes
- ✅ Better user experience

**Deployment Time**: ~10 minutes (commit → deploy → verify)

---

## 📞 Support

If you see any errors after deployment:
1. Check Render logs for error messages
2. Verify Redis pools were cleared
3. Test `/random` endpoint manually
4. Roll back if needed (see above)

**Backup Location**: `lib/services/meme_pool_manager.rb.backup.1783280626`
