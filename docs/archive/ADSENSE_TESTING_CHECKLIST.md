# 🧪 AdSense Policy Compliance - Testing Checklist

## Quick Reference

**Date**: May 17, 2026  
**Tester**: _________________  
**Environment**: ☐ Local  ☐ Staging  ☐ Production

---

## ✅ Pre-Testing Setup

- [ ] Server is running (`bundle exec puma`)
- [ ] Browser DevTools console is open (F12)
- [ ] AdSense credentials are configured in `.env` (or placeholder mode)
- [ ] Test user account created (if needed)

---

## 🔒 Authentication Pages (MUST NOT have ads)

### 1. Login Page (`/login`)

- [ ] Visit http://localhost:3000/login
- [ ] **Visual Check**: No ad containers visible
- [ ] **Console Check**: See message "Ads disabled for this page: /login"
- [ ] **HTML Check**: Inspect page source, no `.ad-container` elements
- [ ] **Result**: ☐ PASS  ☐ FAIL

**Notes**: _____________________________

### 2. Signup Page (`/signup`)

- [ ] Visit http://localhost:3000/signup
- [ ] **Visual Check**: No ad containers visible
- [ ] **Console Check**: See message "Ads disabled for this page: /signup"
- [ ] **HTML Check**: Inspect page source, no `.ad-container` elements
- [ ] **Result**: ☐ PASS  ☐ FAIL

**Notes**: _____________________________

### 3. OAuth Flow (`/auth/reddit` & `/auth/reddit/callback`)

- [ ] Click "Login with Reddit"
- [ ] **During Redirect**: No ads shown
- [ ] **On Callback**: No ads shown
- [ ] **Console Check**: See disabled messages during flow
- [ ] **Result**: ☐ PASS  ☐ FAIL

**Notes**: _____________________________

### 4. Logout Page (`/logout`)

- [ ] Click logout link
- [ ] **During Logout**: No ads shown
- [ ] **Result**: ☐ PASS  ☐ FAIL

**Notes**: _____________________________

---

## 🚫 Empty State Pages (MUST NOT have ads)

### 5. Empty Search Results

- [ ] Visit http://localhost:3000/search?q=xyz999impossible
- [ ] **Visual Check**: "No memes found" message displayed
- [ ] **Visual Check**: No ad containers visible
- [ ] **Console Check**: No ad insertion messages
- [ ] **HTML Check**: No `.ad-container` elements
- [ ] **Result**: ☐ PASS  ☐ FAIL

**Notes**: _____________________________

### 6. Profile with No Saved Memes

- [ ] Create fresh user account
- [ ] Visit http://localhost:3000/profile
- [ ] **Visual Check**: "No saved memes yet" message
- [ ] **Visual Check**: No ad containers visible
- [ ] **Console Check**: See "Insufficient content" message
- [ ] **Result**: ☐ PASS  ☐ FAIL

**Notes**: _____________________________

### 7. Trending with Low Content (<6 memes)

⚠️ **Note**: This test requires temporarily limiting meme pool

- [ ] Visit trending page with <6 memes available
- [ ] **Visual Check**: Memes displayed but no ads
- [ ] **Console Check**: See "Insufficient content (X < 6)" message
- [ ] **Result**: ☐ PASS  ☐ FAIL  ☐ SKIP (can't test)

**Notes**: _____________________________

---

## ✅ Content-Rich Pages (SHOULD have ads)

### 8. Trending Page with Content

- [ ] Visit http://localhost:3000/trending
- [ ] **Content Check**: Page displays 12+ memes
- [ ] **Visual Check**: Ads appear every 12 memes
- [ ] **Console Check**: See "Initialized: {enabled: true}"
- [ ] **Console Check**: See "Inserted X ads" message
- [ ] **Ad Count**: _____ ads inserted for _____ memes
- [ ] **Result**: ☐ PASS  ☐ FAIL

**Notes**: _____________________________

### 9. Search Results with Content

- [ ] Visit http://localhost:3000/search?q=funny
- [ ] **Content Check**: Results show 6+ memes
- [ ] **Visual Check**: Ads appear in results grid
- [ ] **Console Check**: See ad insertion messages
- [ ] **Ad Spacing**: Ads appear every 12 items
- [ ] **Result**: ☐ PASS  ☐ FAIL

**Notes**: _____________________________

### 10. Profile with Saved Memes

- [ ] Save 6+ memes to profile
- [ ] Visit http://localhost:3000/profile
- [ ] **Content Check**: Saved memes section shows 6+ items
- [ ] **Visual Check**: Ads appear in collection
- [ ] **Console Check**: See ad insertion messages
- [ ] **Result**: ☐ PASS  ☐ FAIL

**Notes**: _____________________________

---

## 🔄 API & JSON Endpoints (MUST NOT have ads)

### 11. JSON API Endpoints

- [ ] Visit http://localhost:3000/random.json
- [ ] **Response Check**: Returns pure JSON (no HTML)
- [ ] **Console Check**: See "Ads disabled" or no ad messages
- [ ] **Result**: ☐ PASS  ☐ FAIL

- [ ] Visit http://localhost:3000/api/search.json?q=test
- [ ] **Response Check**: Returns pure JSON (no HTML)
- [ ] **Result**: ☐ PASS  ☐ FAIL

**Notes**: _____________________________

---

## 🎯 Edge Cases & Boundary Testing

### 12. Exactly 6 Memes (Threshold Test)

- [ ] Create page with exactly 6 memes
- [ ] **Expected**: No ads yet (first ad at position 12)
- [ ] **Actual**: ☐ No ads  ☐ Ads present
- [ ] **Result**: ☐ PASS  ☐ FAIL

**Notes**: _____________________________

### 13. Exactly 12 Memes (First Ad Test)

- [ ] Create page with exactly 12 memes
- [ ] **Expected**: First ad should appear after 12th meme
- [ ] **Actual**: ☐ 1 ad  ☐ Other: _____
- [ ] **Result**: ☐ PASS  ☐ FAIL

**Notes**: _____________________________

### 14. Dynamic Content Loading (Infinite Scroll)

- [ ] Visit trending page
- [ ] Scroll down to trigger infinite scroll
- [ ] **Check**: New memes load
- [ ] **Check**: Ads inserted for new content batches
- [ ] **Console Check**: See "Inserted X ads" on each load
- [ ] **Result**: ☐ PASS  ☐ FAIL

**Notes**: _____________________________

---

## 🔧 Premium User Testing

### 15. Premium User (No Ads)

- [ ] Set user subscription_tier to 'premium' in database
- [ ] Visit trending page
- [ ] **Visual Check**: No ads displayed
- [ ] **Console Check**: See "Ads disabled" message
- [ ] **Result**: ☐ PASS  ☐ FAIL  ☐ SKIP (no premium feature)

**Notes**: _____________________________

---

## 📱 Mobile Responsiveness

### 16. Mobile View

- [ ] Open DevTools responsive mode (375x667 - iPhone)
- [ ] Visit trending page
- [ ] **Visual Check**: Ads display correctly
- [ ] **Ad Size**: 300×250 (square) renders properly
- [ ] **Layout**: Ads don't break grid layout
- [ ] **Result**: ☐ PASS  ☐ FAIL

**Notes**: _____________________________

---

## 🐛 Error Scenarios

### 17. AdSense Not Configured

- [ ] Remove GOOGLE_ADSENSE_CLIENT from .env
- [ ] Restart server
- [ ] Visit trending page
- [ ] **Visual Check**: Placeholder ads show
- [ ] **Placeholder Text**: Shows "Configure GOOGLE_ADSENSE_CLIENT"
- [ ] **No Errors**: Console shows no JavaScript errors
- [ ] **Result**: ☐ PASS  ☐ FAIL

**Notes**: _____________________________

### 18. AdSense Script Blocked

- [ ] Install ad blocker (uBlock Origin)
- [ ] Visit trending page
- [ ] **Console Check**: See "Ad blocker detected" message
- [ ] **No Errors**: No JavaScript errors thrown
- [ ] **Graceful Degradation**: Page still functions
- [ ] **Result**: ☐ PASS  ☐ FAIL

**Notes**: _____________________________

---

## 📊 Test Results Summary

### Overall Statistics

- **Total Tests**: 18
- **Tests Passed**: _____
- **Tests Failed**: _____
- **Tests Skipped**: _____
- **Pass Rate**: _____% 

### Critical Issues Found

1. _____________________________
2. _____________________________
3. _____________________________

### Minor Issues Found

1. _____________________________
2. _____________________________
3. _____________________________

---

## ✅ Sign-Off

### Compliance Verification

- [ ] No ads appear on authentication pages
- [ ] No ads appear on pages with <6 items
- [ ] No ads appear on API/JSON endpoints
- [ ] Ads appear correctly on content-rich pages
- [ ] Ad spacing follows configured frequency (12 memes)
- [ ] Mobile display works correctly
- [ ] Premium users see no ads

### Approved By

**Name**: _________________  
**Role**: _________________  
**Date**: _________________  
**Signature**: _________________

---

## 🚀 Next Steps

If all tests pass:
- [ ] Document test results
- [ ] Commit changes to git
- [ ] Deploy to staging
- [ ] Perform staging tests
- [ ] Deploy to production
- [ ] Monitor AdSense dashboard for 48 hours

If tests fail:
- [ ] Document failures in detail
- [ ] Create GitHub issues for bugs
- [ ] Fix issues
- [ ] Re-run failed tests
- [ ] Repeat until all tests pass

---

## 📝 Notes & Observations

_____________________________________________
_____________________________________________
_____________________________________________
_____________________________________________
_____________________________________________

---

**Testing Complete**: ☐ YES  ☐ NO  
**Ready for Production**: ☐ YES  ☐ NO
