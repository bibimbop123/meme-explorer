# Mobile Fix Testing Checklist
## Created: 2026-07-15 13:49

Before deploying, test on these actual devices:

## iPhone SE (375x667) - Smallest modern iPhone
- [ ] Can tap all buttons without zooming
- [ ] Streak badge doesn't overlap meme
- [ ] No horizontal scrolling
- [ ] Hamburger menu works on first tap
- [ ] Like/Next/Save buttons are easy to tap
- [ ] Meme image fills screen nicely

## iPhone 12/13 (390x844) - Most common iPhone
- [ ] Same checks as above
- [ ] Keyboard navigation works
- [ ] Dark mode looks good
- [ ] Ads don't push content off-screen

## Galaxy S21 (360x800) - Popular Android
- [ ] Same checks as above
- [ ] Chrome and Samsung Internet both work
- [ ] No layout breaking
- [ ] Touch targets feel natural

## General Mobile Tests
- [ ] Page loads in < 3 seconds
- [ ] Images lazy load properly
- [ ] No JavaScript errors in console
- [ ] Forms are easy to fill on mobile
- [ ] Share functionality works
- [ ] Can navigate entire site on phone

## Before/After Metrics
- Baseline mobile bounce rate: ___%
- After fix mobile bounce rate: ___%
- Expected improvement: -20% to -30%

## Deployment Notes
- Deployed on: ___________
- Monitored for: 3 days
- User feedback: ___________
- Rollback needed: Yes / No

## Rollback Command (if needed)
```bash
# Restore backups
cp -r public/css/backups_20260715_134947/* public/css/
git add public/css/
git commit -m "Rollback mobile fixes"
git push origin main
```
