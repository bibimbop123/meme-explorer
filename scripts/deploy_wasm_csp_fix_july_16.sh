#!/bin/bash
# WebAssembly CSP Fix Deployment Script
# Fixes WebAssembly.instantiateStreaming() CompileError
# Date: July 16, 2026

set -e  # Exit on any error

echo "======================================"
echo "WebAssembly CSP Fix Deployment"
echo "======================================"
echo ""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check if we're in the right directory
if [ ! -f "app.rb" ]; then
    echo -e "${RED}Error: Must be run from the meme-explorer root directory${NC}"
    exit 1
fi

echo "Step 1: Checking current CSP configuration..."
if grep -q "wasm-unsafe-eval" lib/middleware/security_headers.rb; then
    echo -e "${GREEN}✓ CSP already includes wasm-unsafe-eval${NC}"
else
    echo -e "${RED}✗ CSP does not include wasm-unsafe-eval - manual update needed${NC}"
    exit 1
fi

echo ""
echo "Step 2: Validating Ruby syntax..."
if ruby -c lib/middleware/security_headers.rb > /dev/null 2>&1; then
    echo -e "${GREEN}✓ Ruby syntax valid${NC}"
else
    echo -e "${RED}✗ Ruby syntax error detected${NC}"
    ruby -c lib/middleware/security_headers.rb
    exit 1
fi

echo ""
echo "Step 3: Deployment instructions..."
echo ""
echo "The fix has been applied to the code. To deploy:"
echo ""
echo "1. Commit the changes:"
echo "   git add lib/middleware/security_headers.rb"
echo "   git commit -m 'Fix: Add wasm-unsafe-eval to CSP for WebAssembly support'"
echo ""
echo "2. Push to production:"
echo "   git push origin main"
echo ""
echo "3. Restart the application:"
echo "   - On Render: The app will auto-deploy after push"
echo "   - On local/other: bundle exec puma -C config/puma.rb"
echo ""
echo "4. Verify the fix:"
echo "   - Open browser console on any page"
echo "   - Check that WebAssembly errors are gone"
echo "   - Verify AdSense loads correctly"
echo ""
echo -e "${GREEN}Deployment preparation complete!${NC}"
echo ""
echo "======================================"
echo "Next Steps Summary"
echo "======================================"
echo "1. Review WASM_CSP_FIX_JULY_16_2026.md"
echo "2. Test locally if possible"
echo "3. Commit and deploy to production"
echo "4. Monitor console for errors"
echo ""
