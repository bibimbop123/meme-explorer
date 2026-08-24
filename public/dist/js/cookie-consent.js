// EU Cookie Consent - Monetag Compliance (Section 9 GDPR)
class CookieConsent {
  constructor() {
    this.consentKey = 'meme_explorer_cookie_consent';
    this.consentValue = localStorage.getItem(this.consentKey);
    this.isEU = this.detectEUUser();
    
    // For EU users without consent, show banner and block ads
    if (this.isEU && !this.consentValue) {
      this.showBanner();
      this.blockMonetag();
    } else if (this.consentValue === 'accepted' || !this.isEU) {
      // Non-EU users or users who accepted: allow ads
      this.loadMonetag();
    }
    // If rejected, don't load Monetag
  }
  
  detectEUUser() {
    // Basic EU detection via timezone
    const euTimezones = [
      'Europe/London', 'Europe/Paris', 'Europe/Berlin', 'Europe/Rome',
      'Europe/Madrid', 'Europe/Amsterdam', 'Europe/Brussels', 'Europe/Vienna',
      'Europe/Stockholm', 'Europe/Warsaw', 'Europe/Prague', 'Europe/Budapest',
      'Europe/Athens', 'Europe/Lisbon', 'Europe/Dublin', 'Europe/Helsinki',
      'Europe/Copenhagen', 'Europe/Bucharest', 'Europe/Sofia', 'Europe/Zagreb',
      'Europe/Vilnius', 'Europe/Riga', 'Europe/Tallinn', 'Europe/Ljubljana',
      'Europe/Bratislava', 'Europe/Luxembourg', 'Europe/Valletta', 'Europe/Nicosia'
    ];
    
    try {
      const userTimezone = Intl.DateTimeFormat().resolvedOptions().timeZone;
      return euTimezones.includes(userTimezone);
    } catch (e) {
      console.warn('Cookie Consent: Could not detect timezone, assuming non-EU');
      return false;
    }
  }
  
  showBanner() {
    const banner = document.createElement('div');
    banner.id = 'cookie-consent-banner';
    banner.innerHTML = `
      <div class="cookie-consent-content">
        <p><strong>🍪 This Site Uses Cookies</strong></p>
        <p>We and our advertising partners (Monetag/PropellerAds, Google AdSense) use cookies and similar technologies to personalize content and ads, provide social media features, and analyze our traffic. By clicking "Accept", you consent to our use of cookies.</p>
        <div class="cookie-consent-buttons">
          <button id="cookie-accept" class="btn-primary">Accept All Cookies</button>
          <button id="cookie-reject" class="btn-secondary">Reject Non-Essential</button>
          <a href="/privacy" class="cookie-learn-more">Learn More</a>
        </div>
      </div>
    `;
    
    document.body.appendChild(banner);
    
    document.getElementById('cookie-accept').addEventListener('click', () => this.accept());
    document.getElementById('cookie-reject').addEventListener('click', () => this.reject());
  }
  
  accept() {
    localStorage.setItem(this.consentKey, 'accepted');
    this.hideBanner();
    this.loadMonetag();
    
    // Track consent acceptance
    if (window.activityTracker) {
      window.activityTracker.track('cookie_consent_accepted', { type: 'eu_user' });
    }
  }
  
  reject() {
    localStorage.setItem(this.consentKey, 'rejected');
    this.hideBanner();
    
    // Track consent rejection
    if (window.activityTracker) {
      window.activityTracker.track('cookie_consent_rejected', { type: 'eu_user' });
    }
    
    console.log('🍪 Cookie Consent: User rejected non-essential cookies. Monetag ads will not load.');
  }
  
  hideBanner() {
    const banner = document.getElementById('cookie-consent-banner');
    if (banner) {
      banner.remove();
    }
  }
  
  blockMonetag() {
    // Remove any existing Monetag scripts if they loaded before consent check
    document.addEventListener('DOMContentLoaded', () => {
      document.querySelectorAll('script[src*="quge5.com"], script[src*="3nbf4.com"]').forEach(script => {
        script.remove();
        console.log('🛡️ Cookie Consent: Blocked Monetag script (awaiting consent)');
      });
    });
  }
  
  loadMonetag() {
    // Only load if not already loaded and user consented (or is non-EU)
    if (!document.querySelector('script[src*="quge5.com"]')) {
      const script = document.createElement('script');
      script.src = 'https://quge5.com/88/tag.min.js';
      script.setAttribute('data-zone', '271359');
      script.async = true;
      script.setAttribute('data-cfasync', 'false');
      document.head.appendChild(script);
      console.log('✅ Cookie Consent: Monetag ads loaded (consent granted or non-EU user)');
    }
  }
}

// Initialize on page load
if (document.readyState === 'loading') {
  document.addEventListener('DOMContentLoaded', () => new CookieConsent());
} else {
  new CookieConsent();
}
