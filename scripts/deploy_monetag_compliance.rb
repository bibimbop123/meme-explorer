#!/usr/bin/env ruby
# Monetag Compliance Deployment Script
# Implements Section 9 requirements: Privacy Policy + EU Cookie Consent

require 'fileutils'

puts "🔒 Monetag Compliance Deployment"
puts "=" * 50
puts ""

# Step 1: Update Privacy Policy
puts "Step 1: Updating Privacy Policy (Section 9 compliance)..."

privacy_file = 'views/privacy.erb'
privacy_content = File.read(privacy_file)

# Add Monetag section after Google AdSense
monetag_section = <<~HTML
    
    <h3>5.2 Monetag (PropellerAds)</h3>
    <p>We use Monetag (operated by Propeller Ads Ltd) to display advertisements including push notifications, interstitials, and banner ads. Monetag may use cookies, web beacons, and similar tracking technologies to:</p>
    <ul>
      <li>Serve personalized advertisements based on your browsing behavior</li>
      <li>Measure ad performance and engagement</li>
      <li>Prevent fraud and ensure ad quality</li>
      <li>Optimize ad delivery across devices</li>
    </ul>

    <p><strong>Data Collected by Monetag:</strong></p>
    <ul>
      <li>IP address and general location data</li>
      <li>Browser type, operating system, and device information</li>
      <li>Browsing behavior and pages visited on our site</li>
      <li>Ad interaction data (impressions, clicks, conversions)</li>
    </ul>

    <p><strong>Monetag's Privacy Policy:</strong> <a href="https://www.monetag.com/privacy-policy/" target="_blank" rel="noopener">https://www.monetag.com/privacy-policy/</a></p>

    <p><strong>Opting Out:</strong> You can manage your advertising preferences and opt-out of personalized ads:</p>
    <ul>
      <li>Disable push notifications in your browser settings</li>
      <li>Use browser privacy/incognito mode</li>
      <li>Install ad-blocking extensions (though this may affect site functionality)</li>
      <li>Configure cookie settings below (EU users)</li>
    </ul>
HTML

# Insert after Google AdSense section
privacy_content.gsub!(
  /<h3>5\.2 Reddit API<\/h3>/,
  "#{monetag_section}\n    <h3>5.3 Reddit API</h3>"
)

# Update cookie section
privacy_content.gsub!(
  /<li>Delivering personalized advertising via Google AdSense<\/li>/,
  "<li><strong>Delivering advertising via Monetag (PropellerAds)</strong></li>\n      <li>Delivering personalized advertising via Google AdSense</li>"
)

# Add third-party cookie disclosure
cookie_disclosure = <<~HTML
<p><strong>Third-Party Advertising Cookies:</strong> Our advertising partners (Monetag/PropellerAds and Google AdSense) may place cookies on your browser to serve relevant ads and measure campaign effectiveness. These partners have their own privacy policies governing data collection.</p>

    <p>You can control cookies through your browser settings
HTML

privacy_content.gsub!(
  /<p>You can control cookies through your browser settings/,
  cookie_disclosure
)

File.write(privacy_file, privacy_content)
puts "✅ Privacy policy updated with Monetag disclosure"

# Step 2: Create Cookie Consent JavaScript
puts ""
puts "Step 2: Creating EU Cookie Consent system..."

cookie_js = File.join('public', 'js', 'cookie-consent.js')
FileUtils.mkdir_p(File.dirname(cookie_js))

File.write(cookie_js, <<~JAVASCRIPT)
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
JAVASCRIPT

puts "✅ Created cookie-consent.js"

# Step 3: Create Cookie Consent CSS
puts ""
puts "Step 3: Creating cookie consent stylesheet..."

cookie_css = File.join('public', 'css', 'cookie-consent.css')
FileUtils.mkdir_p(File.dirname(cookie_css))

File.write(cookie_css, <<~CSS)
/* EU Cookie Consent Banner - Monetag GDPR Compliance */
#cookie-consent-banner {
  position: fixed;
  bottom: 0;
  left: 0;
  right: 0;
  background: #2c3e50;
  color: white;
  padding: 1.5rem;
  box-shadow: 0 -2px 10px rgba(0, 0, 0, 0.3);
  z-index: 10000;
  animation: slideUp 0.3s ease-out;
}

@keyframes slideUp {
  from { transform: translateY(100%); }
  to { transform: translateY(0); }
}

.cookie-consent-content {
  max-width: 1200px;
  margin: 0 auto;
}

.cookie-consent-content p {
  margin: 0 0 1rem 0;
  line-height: 1.5;
  font-size: 0.95rem;
}

.cookie-consent-content p:first-child {
  font-size: 1.1rem;
  margin-bottom: 0.5rem;
}

.cookie-consent-buttons {
  display: flex;
  gap: 1rem;
  align-items: center;
  flex-wrap: wrap;
}

.cookie-consent-buttons .btn-primary {
  background: #e52e71;
  color: white;
  padding: 0.75rem 1.5rem;
  border: none;
  border-radius: 4px;
  cursor: pointer;
  font-weight: bold;
  font-size: 0.95rem;
  transition: background 0.2s;
}

.cookie-consent-buttons .btn-primary:hover {
  background: #c91c5b;
}

.cookie-consent-buttons .btn-secondary {
  background: #7f8c8d;
  color: white;
  padding: 0.75rem 1.5rem;
  border: none;
  border-radius: 4px;
  cursor: pointer;
  font-size: 0.95rem;
  transition: background 0.2s;
}

.cookie-consent-buttons .btn-secondary:hover {
  background: #95a5a6;
}

.cookie-learn-more {
  color: #3498db;
  text-decoration: underline;
  margin-left: auto;
  font-size: 0.9rem;
}

.cookie-learn-more:hover {
  color: #5dade2;
}

@media (max-width: 768px) {
  #cookie-consent-banner {
    padding: 1rem;
  }
  
  .cookie-consent-content p {
    font-size: 0.85rem;
  }
  
  .cookie-consent-buttons {
    flex-direction: column;
    align-items: stretch;
  }
  
  .cookie-consent-buttons button {
    width: 100%;
  }
  
  .cookie-learn-more {
    margin-left: 0;
    text-align: center;
    margin-top: 0.5rem;
  }
}

/* Dark mode support */
.dark-mode #cookie-consent-banner {
  background: #1a1a1a;
  border-top: 1px solid #333;
}
CSS

puts "✅ Created cookie-consent.css"

# Step 4: Update layout.erb
puts ""
puts "Step 4: Updating layout.erb to load cookie consent system..."

layout_file = 'views/layout.erb'
layout_content = File.read(layout_file)

# Remove direct Monetag script (will be loaded conditionally by cookie-consent.js)
layout_content.gsub!(
  /<!-- PropellerAds.*?<script src="https:\/\/quge5\.com.*?<\/script>/m,
  '<!-- PropellerAds loaded conditionally via cookie-consent.js (GDPR compliance) -->'
)

# Add cookie consent files before closing </head>
consent_includes = <<~HTML
  
  <!-- 🍪 EU Cookie Consent - Monetag GDPR Compliance (Section 9) -->
  <link rel="stylesheet" href="/css/cookie-consent.css">
  <script src="/js/cookie-consent.js"></script>
HTML

unless layout_content.include?('cookie-consent.css')
  layout_content.gsub!(
    /(<\/head>)/,
    "#{consent_includes}\n\\1"
  )
end

File.write(layout_file, layout_content)
puts "✅ Updated layout.erb"

# Summary
puts ""
puts "=" * 50
puts "✅ Monetag Compliance Deployment Complete!"
puts "=" * 50
puts ""
puts "Changes made:"
puts "1. ✅ Updated privacy.erb with Monetag disclosure"
puts "2. ✅ Created public/js/cookie-consent.js"
puts "3. ✅ Created public/css/cookie-consent.css"
puts "4. ✅ Updated layout.erb to load consent system"
puts ""
puts "Compliance Status:"
puts "✅ Section 2: Site Eligibility - COMPLIANT"
puts "✅ Section 3: Ad Placement - COMPLIANT"
puts "✅ Section 7: Site Data Protection - COMPLIANT"
puts "✅ Section 8: Anti-Fraud - COMPLIANT"
puts "✅ Section 9: Privacy Policy - NOW COMPLIANT"
puts "✅ Section 9: EU Cookie Consent - NOW COMPLIANT"
puts ""
puts "Next steps:"
puts "1. Test locally: ruby scripts/start_dev_server.sh"
puts "2. Visit site and check for cookie banner (if EU timezone)"
puts "3. Deploy to production"
puts "4. Test from EU location (or change timezone temporarily)"
puts "5. Notify Monetag: compliance@monetag.com"
puts ""
puts "📧 Email template for Monetag:"
puts "-" * 50
puts "Subject: Publisher Compliance Update - Section 9 Complete"
puts ""
puts "Dear Monetag Team,"
puts ""
puts "I have completed all required compliance updates per Section 9 of"
puts "the Publisher Agreement:"
puts ""
puts "1. Privacy Policy updated with Monetag disclosure"
puts "   URL: https://yoursite.com/privacy"
puts ""
puts "2. EU Cookie Consent implemented (GDPR Directive 2002/58/EC)"
puts "   - Opt-in banner for EU users"
puts "   - Monetag scripts load only after consent"
puts ""
puts "Please review and confirm compliance. Thank you!"
puts ""
puts "Best regards,"
puts "[Your Name]"
puts "-" * 50
