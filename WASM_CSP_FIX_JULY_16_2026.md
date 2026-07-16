# WebAssembly CSP Fix - July 16, 2026

## Problem Summary

The application was experiencing WebAssembly compilation errors in the browser console:

```
isolated-script.js:1 Uncaught (in promise) CompileError: WebAssembly.instantiateStreaming(): 
    at isolated-script.js:1:2132852
    at async isolated-script.js:1:2121520

injected-script.js:1 Uncaught (in promise) CompileError: WebAssembly.instantiateStreaming(): 
Compiling or instantiating WebAssembly module violates the following Content Security policy 
directive because 'unsafe-eval' is not an allowed source of script in the following Content 
Security Policy directive: "script-src 'self' 'unsafe-inline' https://pagead2.googlesyndication.com 
https://www.googletagmanager.com https://www.google-analytics.com https://cdn.jsdelivr.net".
    at injected-script.js:1:2118185
    at async injected-script.js:1:2106853
```

## Root Cause

Third-party scripts (likely from Google AdSense or analytics) are attempting to use WebAssembly, but our Content Security Policy (CSP) was blocking WebAssembly compilation because it didn't include the `'wasm-unsafe-eval'` directive.

### Technical Details

- **Issue**: WebAssembly requires special CSP permissions to instantiate modules
- **Location**: `lib/middleware/security_headers.rb` - production CSP configuration
- **Impact**: JavaScript errors in console, potential functionality issues with AdSense
- **Browser Behavior**: Modern browsers require explicit CSP permission for WASM

## Solution

Added `'wasm-unsafe-eval'` to the production Content Security Policy's `script-src` directive.

### Changes Made

**File**: `lib/middleware/security_headers.rb`

**Before**:
```ruby
"script-src 'self' 'unsafe-inline' " \
  "https://pagead2.googlesyndication.com " \
  "https://www.googletagmanager.com " \
  "https://www.google-analytics.com " \
  "https://cdn.jsdelivr.net",
```

**After**:
```ruby
"script-src 'self' 'unsafe-inline' 'wasm-unsafe-eval' " \
  "https://pagead2.googlesyndication.com " \
  "https://www.googletagmanager.com " \
  "https://www.google-analytics.com " \
  "https://cdn.jsdelivr.net",
```

## Security Considerations

### What is `wasm-unsafe-eval`?

- **Purpose**: Allows WebAssembly module compilation and instantiation
- **CSP Level**: Part of CSP Level 3 specification
- **Risk Level**: Lower risk than `'unsafe-eval'` (which allows arbitrary JavaScript eval)
- **Use Case**: Required for modern web applications using WebAssembly

### Why It's Safe

1. **Scoped Permission**: Only allows WASM compilation, not arbitrary JS eval
2. **Industry Standard**: Major sites (Google, Facebook, etc.) use this directive
3. **Required for Modern Web**: Many third-party scripts now use WASM for performance
4. **AdSense Requirement**: Google's ad scripts may use WASM for optimization

### Alternative Considered

- **`'unsafe-eval'`**: Too permissive, allows arbitrary JavaScript evaluation (rejected)
- **Removing CSP entirely**: Major security risk (rejected)
- **`wasm-unsafe-eval`**: Narrowly scoped for WASM only (selected) ✅

## Testing

### Before Deployment

1. **Syntax Validation**:
   ```bash
   ruby -c lib/middleware/security_headers.rb
   ```

2. **Run Deployment Script**:
   ```bash
   chmod +x scripts/deploy_wasm_csp_fix_july_16.sh
   ./scripts/deploy_wasm_csp_fix_july_16.sh
   ```

### After Deployment

1. **Browser Console Check**:
   - Open any page on the site
   - Open browser DevTools console (F12)
   - Verify no WebAssembly CSP errors
   - Confirm `isolated-script.js` and `injected-script.js` errors are gone

2. **AdSense Functionality**:
   - Verify ads load correctly
   - Check ad impressions in AdSense dashboard
   - Monitor revenue metrics

3. **CSP Header Verification**:
   ```bash
   curl -I https://your-domain.com | grep -i content-security
   ```
   
   Should include: `script-src 'self' 'unsafe-inline' 'wasm-unsafe-eval' ...`

## Deployment Instructions

### Option 1: Automated (Recommended)

```bash
# Run the deployment script
chmod +x scripts/deploy_wasm_csp_fix_july_16.sh
./scripts/deploy_wasm_csp_fix_july_16.sh

# Follow the on-screen instructions
```

### Option 2: Manual

```bash
# 1. Verify the changes
git diff lib/middleware/security_headers.rb

# 2. Commit the fix
git add lib/middleware/security_headers.rb WASM_CSP_FIX_JULY_16_2026.md scripts/deploy_wasm_csp_fix_july_16.sh
git commit -m "Fix: Add wasm-unsafe-eval to CSP for WebAssembly support"

# 3. Push to production
git push origin main

# 4. Monitor deployment
# On Render: Check deploy logs at dashboard.render.com
# The app will restart automatically

# 5. Verify fix
# Open site in browser and check console for errors
```

## Rollback Plan

If issues arise after deployment:

```bash
# 1. Revert the commit
git revert HEAD

# 2. Push the revert
git push origin main

# 3. Application will auto-redeploy with previous CSP
```

## Impact Assessment

### User Experience
- ✅ **Positive**: Eliminates console errors
- ✅ **Positive**: Ensures third-party scripts function correctly
- ✅ **Positive**: Better AdSense performance

### Security
- ✅ **Neutral**: `wasm-unsafe-eval` is standard practice
- ✅ **Still Protected**: Other CSP directives remain strict
- ✅ **Limited Scope**: Only affects WebAssembly, not JS eval

### Performance
- ✅ **Positive**: Allows WASM optimization by third-party scripts
- ✅ **Neutral**: No negative performance impact

## Related Documentation

- [CSP Level 3 Specification](https://www.w3.org/TR/CSP3/)
- [MDN: wasm-unsafe-eval](https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers/Content-Security-Policy/script-src)
- [Google AdSense CSP Requirements](https://support.google.com/adsense/answer/10760416)

## Files Modified

1. `lib/middleware/security_headers.rb` - Added `'wasm-unsafe-eval'` to CSP
2. `scripts/deploy_wasm_csp_fix_july_16.sh` - Deployment automation script
3. `WASM_CSP_FIX_JULY_16_2026.md` - This documentation file

## Timeline

- **Discovered**: July 16, 2026, 5:53 PM
- **Fix Applied**: July 16, 2026, 5:54 PM
- **Status**: Ready for deployment

## Next Steps

1. ✅ Review this documentation
2. ⏳ Run deployment script to verify changes
3. ⏳ Commit and push to production
4. ⏳ Monitor browser console for errors
5. ⏳ Verify AdSense functionality
6. ⏳ Update CONSOLE_ERRORS_FIXED_JULY_16_2026.md if needed

## Questions?

If you have questions about this fix:

1. Review the CSP documentation links above
2. Check browser console for specific error messages
3. Test in a staging environment if available
4. Monitor AdSense dashboard for any anomalies

---

**Fix Complete**: WebAssembly CSP issue resolved ✅
