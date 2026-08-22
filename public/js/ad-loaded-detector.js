// Ad Loaded Detector - Remove skeleton when ad appears
// Prevents CLS by pre-reserving space, then removing skeleton

(function() {
  'use strict';
  
  // Monitor for ad elements loading
  const adSelectors = [
    '[data-zone]',
    '[id*="propeller"]',
    '[id*="monetag"]',
    '.ad-container',
    '.ad-placement'
  ];
  
  function markAdAsLoaded(element) {
    // Only mark if it has actual content
    if (element.children.length > 0 || element.innerHTML.trim().length > 100) {
      element.classList.add('ad-loaded');
      console.log('✅ Ad loaded, removing skeleton:', element);
    }
  }
  
  // Use MutationObserver to detect when ads load
  const observer = new MutationObserver((mutations) => {
    mutations.forEach((mutation) => {
      mutation.addedNodes.forEach((node) => {
        if (node.nodeType === 1) { // Element node
          adSelectors.forEach(selector => {
            // Check if the node itself matches
            if (node.matches && node.matches(selector)) {
              setTimeout(() => markAdAsLoaded(node), 100);
            }
            // Check children
            node.querySelectorAll && node.querySelectorAll(selector).forEach(ad => {
              setTimeout(() => markAdAsLoaded(ad), 100);
            });
          });
        }
      });
    });
  });
  
  // Start observing
  observer.observe(document.body, {
    childList: true,
    subtree: true
  });
  
  // Also check existing elements on load
  document.addEventListener('DOMContentLoaded', () => {
    adSelectors.forEach(selector => {
      document.querySelectorAll(selector).forEach(ad => {
        setTimeout(() => markAdAsLoaded(ad), 500);
      });
    });
  });
  
  console.log('🎯 Ad Loaded Detector initialized - CLS prevention active');
})();
