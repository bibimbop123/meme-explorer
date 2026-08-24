// Create: public/js/modules/meme-utils.js
export class ConsoleFilter {
  constructor() {
    this.init();
  }
  
  init() {
    // Copy lines 172-207 here
    // The console.warn/console.log override logic
    
    (function() {
        const originalWarn = console.warn;
        const originalLog = console.log;
        
        // List of patterns to filter out (browser extensions)
        const suppressPatterns = [
          /installHook\.js/i,
          /EternlDomAPI/i,
          /initEternlDomAPI/i,
          /overrideMethod/i,
          /chrome-extension:/i,
          /moz-extension:/i
        ];
        
        // Override console.warn to filter out extension warnings
        console.warn = function(...args) {
          const message = args.join(' ');
          const shouldSuppress = suppressPatterns.some(pattern => pattern.test(message));
          
          if (!shouldSuppress) {
            originalWarn.apply(console, args);
          }
        };
        
        // Override console.log to filter out extension logs
        console.log = function(...args) {
          const message = args.join(' ');
          const shouldSuppress = suppressPatterns.some(pattern => pattern.test(message));
          
          if (!shouldSuppress) {
            originalLog.apply(console, args);
          }
        };
        
        console.log('🧹 [CONSOLE] Extension warning filter active');
      })();
  }
}


// Add to meme-utils.js
export async function cachedFetch(url, options = {}) {
  // Copy lines 212-248 here
  // The request caching logic

  const requestCache = new Map();
  const pendingRequests = new Map();
  
  async function cachedFetch(url, options = {}) {
    const cacheKey = `${url}:${JSON.stringify(options)}`;
    
    // Return cached result if available and fresh (< 5s)
    if (requestCache.has(cacheKey)) {
      const { data, timestamp } = requestCache.get(cacheKey);
      if (Date.now() - timestamp < 5000) {
        console.log(`✅ [CACHE HIT] ${url}`);
        return data;
      }
    }
    
    // Return pending request if already in flight (deduplicate)
    if (pendingRequests.has(cacheKey)) {
      console.log(`⏳ [DEDUP] Waiting for in-flight request: ${url}`);
      return pendingRequests.get(cacheKey);
    }
    
    // New request - add to pending
    const promise = fetch(url, options)
      .then(r => r.json())
      .then(data => {
        requestCache.set(cacheKey, { data, timestamp: Date.now() });
        pendingRequests.delete(cacheKey);
        return data;
      })
      .catch(err => {
        pendingRequests.delete(cacheKey);
        throw err;
      });
    
    pendingRequests.set(cacheKey, promise);
    return promise;
  }
}
