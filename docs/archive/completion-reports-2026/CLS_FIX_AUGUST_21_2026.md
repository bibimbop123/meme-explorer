# CLS (Cumulative Layout Shift) Fix - August 21, 2026

## Issue Detected
**Current CLS:** 0.309 (needs improvement)  
**Target CLS:** <0.1 (good)  
**Source:** Cookie consent banner + ad placements

## Root Causes

### 1. Cookie Consent Banner ⚠️
- Animation causes visual shift even though `position: fixed`
- Solution: Use `will-change` and `contain` properties

### 2. Ad Placements 🚨 MAIN ISSUE
- Monetag ads load asynchronously
- No space reserved before ad loads
- Content shifts down when ads appear
- Solution: Reserve space with min-height skeleton

### 3. Images Without Dimensions
- Images load without explicit width/height
- Solution: Add aspect-ratio CSS

## Fixes Applied

### Fix 1: Optimize Cookie Banner
- Add `will-change: transform` for GPU acceleration
- Add `contain: layout` to prevent layout recalculation
- Use `transform` instead of position changes

### Fix 2: Reserve Ad Space (CRITICAL)
- Add min-height to ad containers
- Show skeleton loader while ad loads
- Use CSS containment
- Prevent reflow when ad appears

### Fix 3: Image Aspect Ratios
- Add `aspect-ratio` CSS property
- Prevent CLS from image loads

### Fix 4: Content Visibility
- Use `content-visibility: auto` for off-screen content
- Reduce layout calculation overhead

## Implementation

See: `scripts/fix_cls_august_21_2026.rb`

## Expected Results
- CLS reduced from 0.309 to <0.1
- Better Core Web Vitals score
- Improved SEO rankings
- Better user experience
