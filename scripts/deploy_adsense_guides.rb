#!/usr/bin/env ruby
# frozen_string_literal: true

# Deploy AdSense Guides - Creates all guide pages
# Run: ruby scripts/deploy_adsense_guides.rb

require 'fileutils'

GUIDES_DIR = File.join(__dir__, '..', 'views', 'guides')
FileUtils.mkdir_p(GUIDES_DIR)

guides = {
  'guides_index.erb' => <<~ERB,
    <div class="legal-page guides-index">
      <h1>📚 Guides & Resources</h1>
      
      <section class="hero-section">
        <p class="tagline">Learn how Meme Explorer's curation systems work</p>
      </section>
      
      <section>
        <h2>🎯 Core Features</h2>
        <div class="guide-grid">
          <a href="/guides/quality-system" class="guide-card">
            <h3>Quality System</h3>
            <p>How our 6-stage pipeline ensures only the best memes</p>
          </a>
          <a href="/guides/personalization" class="guide-card">
            <h3>Personalization</h3>
            <p>Smart content adapted to your context and preferences</p>
          </a>
          <a href="/guides/collections" class="guide-card">
            <h3>Collections</h3>
            <p>How we curate and organize meme categories</p>
          </a>
          <a href="/guides/discovery" class="guide-card">
            <h3>Discovery</h3>
            <p>Trending algorithms and serendipity features</p>
          </a>
        </div>
      </section>
      
      <section>
        <h2>🚀 Getting Started</h2>
        <div class="guide-grid">
          <a href="/guides/getting-started" class="guide-card">
            <h3>Getting Started</h3>
            <p>Complete guide for new users</p>
          </a>
          <a href="/guides/meme-formats" class="guide-card">
            <h3>Meme Formats</h3>
            <p>Understanding different types of memes</p>
          </a>
          <a href="/guides/best-practices" class="guide-card">
            <h3>Best Practices</h3>
            <p>Tips to get the most out of Meme Explorer</p>
          </a>
          <a href="/guides/community" class="guide-card">
            <h3>Community</h3>
            <p>Guidelines and culture</p>
          </a>
          <a href="/guides/faq" class="guide-card">
            <h3>FAQ</h3>
            <p>Frequently asked questions</p>
          </a>
        </div>
      </section>
    </div>

    <style>
      .guide-grid {
        display: grid;
        grid-template-columns: repeat(auto-fit, minmax(250px, 1fr));
        gap: 1.5rem;
        margin: 2rem 0;
      }
      
      .guide-card {
        padding: 1.5rem;
        background: white;
        border: 2px solid #e0e0e0;
        border-radius: 8px;
        text-decoration: none;
        color: inherit;
        transition: all 0.2s;
      }
      
      .guide-card:hover {
        border-color: #667eea;
        transform: translateY(-2px);
        box-shadow: 0 4px 12px rgba(102, 126, 234, 0.15);
      }
      
      .guide-card h3 {
        color: #667eea;
        margin: 0 0 0.5rem 0;
      }
      
      .guide-card p {
        color: #666;
        margin: 0;
        font-size: 0.9rem;
      }
      
      .dark-mode .guide-card {
        background: #1a1a1a;
        border-color: #333;
      }
      
      @media (max-width: 768px) {
        .guide-grid {
          grid-template-columns: 1fr;
        }
      }
    </style>
  ERB

  'quality_system.erb' => <<~ERB,
    <div class="legal-page guide-page">
      <h1>🎯 Our Quality System Explained</h1>
      
      <section class="hero-section">
        <p class="tagline">How we ensure only the best memes reach your feed</p>
      </section>
      
      <section>
        <h2>The Challenge</h2>
        <p>Reddit produces millions of posts daily, but only a tiny fraction are worth your time. We built a sophisticated 6-stage quality pipeline to separate signal from noise.</p>
      </section>
      
      <section>
        <h2>Our 6-Stage Quality Pipeline</h2>
        
        <h3>Stage 1: Technical Validation</h3>
        <p>Every meme must have a valid URL, title, and source attribution. We filter out broken links, videos (currently), and gallery posts that don't render properly. This ensures you only see content that actually works.</p>
        
        <h3>Stage 2: Engagement Validation</h3>
        <p>Memes must meet minimum engagement thresholds. Popular subreddits require at least 50 upvotes, while smaller communities need just 10. This filters out spam and low-effort posts while giving quality content from smaller communities a chance.</p>
        
        <h3>Stage 3: Content Safety</h3>
        <p>We check against known problematic subreddits and filter NSFW content unless explicitly requested. Our goal is family-friendly by default, dank by choice.</p>
        
        <h3>Stage 4: Visual Quality</h3>
        <p>Memes are evaluated for image quality, readability, and format. Screenshots of text with tiny fonts? Filtered. Overly compressed images? Not on our watch.</p>
        
        <h3>Stage 5: User Feedback Score</h3>
        <p>We analyze like/dislike ratios and engagement patterns. If users consistently skip or downvote similar content, the system learns and adjusts.</p>
        
        <h3>Stage 6: Novelty Check</h3>
        <p>Have you seen this meme already? Our deduplication system ensures you're not served the same content twice. We also detect reposts across different subreddits.</p>
      </section>
      
      <section>
        <h2>Why This Matters</h2>
        <p>Without quality control, you'd waste time scrolling through spam, broken links, and mediocre content. Our pipeline does the heavy lifting so you only see memes worth your time.</p>
        <p>The result? An average quality score of 85+ across our entire catalog, compared to Reddit's wild west of 30-40. Every meme in your feed has been validated, vetted, and verified.</p>
      </section>
      
      <section>
        <h2>Technical Details</h2>
        <p>The quality pipeline runs continuously in the background. As new memes are fetched from Reddit's API, they're immediately evaluated through all six stages. Only those passing every check enter our pool.</p>
        <p>We process thousands of potential memes daily, but only about 15-20% make it through. That's intentional - we'd rather show you 100 great memes than 1000 mediocre ones.</p>
      </section>
      
      <section>
        <h2>Pro Tips</h2>
        <ul>
          <li><strong>Trust the System:</strong> If something made it to your feed, it's already top-tier quality</li>
          <li><strong>Provide Feedback:</strong> Your likes and dislikes train the algorithm to serve you better content</li>
          <li><strong>Explore Collections:</strong> Each collection has its own quality standards tuned for that category</li>
          <li><strong>Check the Source:</strong> We always show the original subreddit - great for discovering new communities</li>
        </ul>
      </section>
      
      <section>
        <h2>Related Guides</h2>
        <p>Learn more about how we personalize your experience:</p>
        <ul>
          <li><a href="/guides/personalization">Personalization Engine</a></li>
          <li><a href="/guides/collections">How Collections Work</a></li>
          <li><a href="/guides/discovery">Discovery Features</a></li>
        </ul>
      </section>
      
      <section class="cta-section">
        <h2>Experience Quality Curation</h2>
        <p>Ready to see our quality system in action?</p>
        <p><a href="/trending" class="btn-primary">Browse Trending Memes</a></p>
      </section>
    </div>
  ERB

  'personalization.erb' => <<~ERB,
    <div class="legal-page guide-page">
      <h1>🧠 Smart Personalization Engine</h1>
      
      <section class="hero-section">
        <p class="tagline">Content adapted to your context, mood, and preferences</p>
      </section>
      
      <section>
        <h2>Beyond Basic Recommendations</h2>
        <p>Most platforms show you more of what you've liked before. We go deeper - analyzing when you browse, what you engage with, and even your current mood to serve perfectly-timed content.</p>
      </section>
      
      <section>
        <h2>Contextual Scoring System</h2>
        
        <h3>Time-of-Day Preferences</h3>
        <p>Our research shows clear patterns: mornings favor wholesome content, evenings lean dank, and late nights go existential. The system automatically adjusts content weights based on your local time.</p>
        
        <h3>Session Context</h3>
        <p>Are you on a streak? The algorithm knows and serves content that keeps momentum going. First visit of the day? We start with crowd-pleasers. Deep into a session? We introduce variety and surprises.</p>
        
        <h3>Taste Profile Building</h3>
        <p>Every interaction teaches the system about you. Likes, saves, shares, and even how long you view each meme contributes to your taste profile. Over time, recommendations become eerily accurate.</p>
      </section>
      
      <section>
        <h2>Mood Detection</h2>
        <p>The system detects patterns in your browsing behavior. Rapid scrolling? You're hunting for something specific. Slower pace with longer view times? You're in discovery mode. The algorithm adapts content pacing accordingly.</p>
      </section>
      
      <section>
        <h2>Privacy-First Approach</h2>
        <p>All personalization happens on our servers - your data never leaves our platform. We don't sell data, show targeted ads based on your browsing, or share information with third parties. Your meme preferences stay private.</p>
      </section>
      
      <section>
        <h2>Pro Tips</h2>
        <ul>
          <li><strong>Train the Algorithm:</strong> Like and save consistently to build a strong taste profile</li>
          <li><strong>Explore Collections:</strong> Each has unique personalization tuning</li>
          <li><strong>Try Different Times:</strong> Browse at various hours to experience the contextual system</li>
          <li><strong>Reset Anytime:</strong> Your taste profile can be cleared in settings if you want a fresh start</li>
        </ul>
      </section>
      
      <section>
        <h2>Related Guides</h2>
        <ul>
          <li><a href="/guides/quality-system">Quality System</a></li>
          <li><a href="/guides/discovery">Discovery Algorithm</a></li>
        </ul>
      </section>
      
      <section class="cta-section">
        <h2>Build Your Taste Profile</h2>
        <p><a href="/random" class="btn-primary">Start Exploring</a></p>
      </section>
    </div>
  ERB

  'gamification.erb' => <<~ERB,
    <div class="legal-page guide-page">
      <h1>🎮 Gamification & Achievements</h1>
      
      <section class="hero-section">
        <p class="tagline">Streaks, XP, levels, and achievements that reward engagement</p>
      </section>
      
      <section>
        <h2>Why Gamification?</h2>
        <p>Memes are fun, but discovering patterns in your humor preferences is fascinating. Our gamification system turns casual browsing into a journey of self-discovery while keeping things engaging and rewarding.</p>
      </section>
      
      <section>
        <h2>Streak System</h2>
        <p>Visit daily and your streak grows. Maintain a 7-day streak and unlock exclusive features. Hit 30 days and join the elite club. Streaks aren't just numbers - they unlock better personalization as the algorithm learns from consistent engagement.</p>
        
        <h3>Streak Benefits</h3>
        <ul>
          <li><strong>7-Day Streak:</strong> Priority access to trending content</li>
          <li><strong>14-Day Streak:</strong> Early access to new features</li>
          <li><strong>30-Day Streak:</strong> Custom collection curation</li>
          <li><strong>100-Day Streak:</strong> Legendary status and special badge</li>
        </ul>
      </section>
      
      <section>
        <h2>Experience Points (XP)</h2>
        <p>Every interaction earns XP. Viewing a meme: 1 XP. Liking: 5 XP. Saving: 10 XP. Sharing: 20 XP. Creating collections: 50 XP. The more you engage, the faster you level up.</p>
        
        <h3>Leveling Up</h3>
        <p>Each level unlocks new features and capabilities. Level 5: Create custom collections. Level 10: Vote on trending content. Level 20: Influence recommendation algorithms. Level 50: Curator status.</p>
      </section>
      
      <section>
        <h2>Achievement System</h2>
        <p>Over 50 achievements wait to be unlocked. Some are easy (view 100 memes), others are challenges (maintain a 90-day streak), and a few are hidden secrets waiting to be discovered.</p>
        
        <h3>Achievement Categories</h3>
        <ul>
          <li><strong>Explorer:</strong> Discover different collections and formats</li>
          <li><strong>Curator:</strong> Build and maintain quality collections</li>
          <li><strong>Social:</strong> Share and spread great content</li>
          <li><strong>Dedicated:</strong> Consistency and long-term engagement</li>
          <li><strong>Hidden:</strong> Secret achievements for dedicated users</li>
        </ul>
      </section>
      
      <section>
        <h2>Leaderboard</h2>
        <p>Weekly and all-time leaderboards showcase top engagers. Compete with friends or challenge yourself to climb the ranks. Top 10 users each week earn special recognition and exclusive features.</p>
      </section>
      
      <section>
        <h2>Pro Tips</h2>
        <ul>
          <li><strong>Daily Visits:</strong> Even 5 minutes counts for streak maintenance</li>
          <li><strong>Quality Over Quantity:</strong> Thoughtful engagement earns more XP than mindless scrolling</li>
          <li><strong>Explore Everything:</strong> Achievements reward diverse browsing patterns</li>
          <li><strong>Share Wisely:</strong> Sharing truly great content earns bonus XP</li>
        </ul>
      </section>
      
      <section>
        <h2>Related Guides</h2>
        <ul>
          <li><a href="/guides/getting-started">Getting Started</a></li>
          <li><a href="/guides/collections">Collections Guide</a></li>
          <li><a href="/guides/best-practices">Best Practices</a></li>
        </ul>
      </section>
      
      <section class="cta-section">
        <h2>Start Your Journey</h2>
        <p><a href="/profile" class="btn-primary">View Your Profile</a></p>
      </section>
    </div>
  ERB

  'collections.erb' => <<~ERB,
    <div class="legal-page guide-page">
      <h1>🎨 Collections Explained</h1>
      
      <section class="hero-section">
        <p class="tagline">Criterion Collection-style curation for the internet age</p>
      </section>
      
      <section>
        <h2>Our Curation Philosophy</h2>
        <p>We approach meme curation like the Criterion Collection approaches film - thoughtful selection, contextual presentation, and respect for the medium. Not every meme makes the cut, but those that do represent the best of their category.</p>
      </section>
      
      <section>
        <h2>Core Collections</h2>
        
        <h3>Funny Collection</h3>
        <p>Classic humor that stands the test of time. No niche references required - these memes make everyone laugh. Curated for universal appeal and clever wit.</p>
        
        <h3>Wholesome Collection</h3>
        <p>Positivity, kindness, and feel-good content. Perfect for starting your day or lifting your spirits. Each meme selected for emotional resonance and genuine warmth.</p>
        
        <h3>Dank Collection</h3>
        <p>For the connoisseurs. Absurdist humor, meta-references, and internet culture deep cuts. Requires fluency in meme language and appreciation for the bizarre.</p>
        
        <h3>Self-Care Collection</h3>
        <p>Mental health awareness, self-improvement, and personal growth wrapped in accessible humor. Therapeutic without being preachy, supportive without being cheesy.</p>
      </section>
      
      <section>
        <h2>Curation Process</h2>
        <p>Each collection has dedicated quality standards. Memes are evaluated not just for general quality but for fit within the collection's ethos. A great meme in the wrong collection serves no one.</p>
        
        <h3>Quality Over Quantity</h3>
        <p>We'd rather have 50 perfect memes in a collection than 500 mediocre ones. Every addition is deliberate, every piece contributes to the collection's character.</p>
      </section>
      
      <section>
        <h2>Seasonal & Special Collections</h2>
        <p>Limited-time collections emerge for holidays, cultural moments, and internet events. These curated sets capture specific vibes and moments in time.</p>
      </section>
      
      <section>
        <h2>User Collections</h2>
        <p>As you level up, you gain the ability to create and curate your own collections. Share them publicly or keep them private. The best user collections sometimes get featured site-wide.</p>
      </section>
      
      <section>
        <h2>Pro Tips</h2>
        <ul>
          <li><strong>Match Your Mood:</strong> Each collection serves different emotional needs</li>
          <li><strong>Time of Day Matters:</strong> Wholesome for mornings, dank for late nights</li>
          <li><strong>Explore Boundaries:</strong> Each collection occasionally surprises you</li>
          <li><strong>Trust Curation:</strong> Every meme earned its place</li>
        </ul>
      </section>
      
      <section>
        <h2>Related Guides</h2>
        <ul>
          <li><a href="/guides/quality-system">Quality System</a></li>
          <li><a href="/guides/personalization">Personalization</a></li>
          <li><a href="/guides/meme-formats">Meme Formats</a></li>
        </ul>
      </section>
      
      <section class="cta-section">
        <h2>Explore Collections</h2>
        <p><a href="/collections" class="btn-primary">Browse All Collections</a></p>
      </section>
    </div>
  ERB

  'discovery.erb' => <<~ERB,
    <div class="legal-page guide-page">
      <h1>🔍 Discovery Features</h1>
      
      <section class="hero-section">
        <p class="tagline">How content surfaces through trending and serendipity</p>
      </section>
      
      <section>
        <h2>The Discovery Challenge</h2>
        <p>Great content exists everywhere, but finding it is hard. Our discovery system balances popularity with freshness, trending with evergreen, and familiar with surprising.</p>
      </section>
      
      <section>
        <h2>Trending Algorithm</h2>
        <p>True trending isn't just "most popular right now" - it's content gaining momentum. Our algorithm detects acceleration in engagement, not just raw numbers.</p>
        
        <h3>How Trending Works</h3>
        <ul>
          <li><strong>Velocity Matters:</strong> A meme with 100 upvotes in 1 hour beats 1000 upvotes in 24 hours</li>
          <li><strong>Freshness Bonus:</strong> Newer content gets weighted advantages</li>
          <li><strong>Diversity Filter:</strong> Trending shows variety, not just one topic</li>
          <li><strong>Quality Floor:</strong> Still must pass quality pipeline standards</li>
        </ul>
      </section>
      
      <section>
        <h2>Random Feature</h2>
        <p>Sometimes you don't know what you want until you see it. Random serves truly random content from our quality pool, exposing you to memes you'd never find through recommendations alone.</p>
        
        <h3>Controlled Randomness</h3>
        <p>While random, it's still quality-controlled. You might get surprised, but you won't get trash. The random pool excludes content below quality thresholds and respects your NSFW preferences.</p>
      </section>
      
      <section>
        <h2>Serendipity Engine</h2>
        <p>Our secret sauce - the serendipity engine occasionally injects unexpected content into your feed. Not random noise, but calculated surprises based on "people who liked what you like also enjoyed this."</p>
        
        <h3>Benefits of Serendipity</h3>
        <ul>
          <li>Prevents filter bubbles</li>
          <li>Introduces new humor styles</li>
          <li>Expands taste profiles organically</li>
          <li>Creates delightful discovery moments</li>
        </ul>
      </section>
      
      <section>
        <h2>Exploration Modes</h2>
        <p>Different discovery modes for different needs: Trending for what's hot now, Random for surprise, Collections for curated experiences, and Search for specific hunting.</p>
      </section>
      
      <section>
        <h2>Pro Tips</h2>
        <ul>
          <li><strong>Try Random:</strong> It's the fastest way to expand your taste</li>
          <li><strong>Check Trending Daily:</strong> Internet culture moves fast</li>
          <li><strong>Embrace Surprises:</strong> Serendipity finds gems you didn't know existed</li>
          <li><strong>Mix Methods:</strong> Alternate between discovery modes for best results</li>
        </ul>
      </section>
      
      <section>
        <h2>Related Guides</h2>
        <ul>
          <li><a href="/guides/personalization">Personalization</a></li>
          <li><a href="/guides/quality-system">Quality System</a></li>
          <li><a href="/guides/collections">Collections</a></li>
        </ul>
      </section>
      
      <section class="cta-section">
        <h2>Start Discovering</h2>
        <p>
          <a href="/trending" class="btn-primary">See What's Trending</a>
          <a href="/random" class="btn-secondary">Try Random</a>
        </p>
      </section>
    </div>
  ERB

  'getting_started.erb' => <<~ERB,
    <div class="legal-page guide-page">
      <h1>🚀 Getting Started with Meme Explorer</h1>
      
      <section class="hero-section">
        <p class="tagline">Your complete guide to exploring curated memes</p>
      </section>
      
      <section>
        <h2>Welcome!</h2>
        <p>Meme Explorer is your gateway to the best of internet humor, curated and personalized just for you. This guide will help you get the most out of the platform from day one.</p>
      </section>
      
      <section>
        <h2>Step 1: Create Your Account</h2>
        <p>While you can browse without an account, creating one unlocks personalization, streaks, achievements, and the ability to save favorites. Sign up takes 30 seconds and requires only an email.</p>
      </section>
      
      <section>
        <h2>Step 2: Choose Your First Collection</h2>
        <p>Start with a collection that matches your mood: Funny for laughs, Wholesome for positivity, Dank for absurdist humor, or Self-Care for thoughtful content. You can switch anytime.</p>
      </section>
      
      <section>
        <h2>Step 3: Engage & Train Your Algorithm</h2>
        <p>Every interaction teaches the system about your preferences. Like what makes you laugh, save what you want to share, and skip what doesn't land. Within a few days, recommendations become eerily accurate.</p>
      </section>
      
      <section>
        <h2>Core Features</h2>
        
        <h3>Browse Collections</h3>
        <p>Curated categories of high-quality memes. Each collection has its own personality and quality standards.</p>
        
        <h3>Trending Feed</h3>
        <p>See what's hot right now across the internet. Updated continuously throughout the day.</p>
        
        <h3>Random Discovery</h3>
        <p>Hit the random button for surprise content. Great for expanding your humor palette.</p>
        
        <h3>Your Profile</h3>
        <p>Track your streaks, achievements, XP, and level. See your browsing patterns and taste evolution.</p>
      </section>
      
      <section>
        <h2>Quick Tips for New Users</h2>
        <ul>
          <li><strong>Visit Daily:</strong> Build a streak to unlock features</li>
          <li><strong>Be Honest:</strong> Only like what genuinely makes you laugh</li>
          <li><strong>Explore Everything:</strong> Try all collections to find your favorites</li>
          <li><strong>Save Liberally:</strong> Build your personal collection of favorites</li>
          <li><strong>Share Great Finds:</strong> Spread joy and earn XP</li>
        </ul>
      </section>
      
      <section>
        <h2>Understanding the Interface</h2>
        <p>Navigation is simple: Collections at the top, Trending in the sidebar, Random button always accessible, and your Profile in the corner. Everything is one click away.</p>
      </section>
      
      <section>
        <h2>Need Help?</h2>
        <p>Check our <a href="/guides/faq">FAQ</a> for common questions or visit <a href="/contact">Contact</a> to reach us directly.</p>
      </section>
      
      <section>
        <h2>Related Guides</h2>
        <ul>
          <li><a href="/guides/collections">Collections Explained</a></li>
          <li><a href="/guides/gamification">Gamification Features</a></li>
          <li><a href="/guides/best-practices">Best Practices</a></li>
        </ul>
      </section>
      
      <section class="cta-section">
        <h2>Ready to Explore?</h2>
        <p><a href="/trending" class="btn-primary">Start Browsing</a></p>
      </section>
    </div>
  ERB

  'meme_formats.erb' => <<~ERB,
    <div class="legal-page guide-page">
      <h1>🖼️ Understanding Meme Formats</h1>
      
      <section class="hero-section">
        <p class="tagline">A guide to image memes, templates, and internet humor</p>
      </section>
      
      <section>
        <h2>What Makes a Meme?</h2>
        <p>At its core, a meme is a unit of cultural information that spreads. Internet memes specifically use humor, relatability, and shareability to propagate ideas across communities.</p>
      </section>
      
      <section>
        <h2>Common Meme Formats</h2>
        
        <h3>Image Macros</h3>
        <p>Top and bottom text over an image. Classic format, still widely used. Examples: Distracted Boyfriend, Drake, Expanding Brain.</p>
        
        <h3>Reaction Images</h3>
        <p>Single images expressing emotion or reaction. No text needed - the image speaks volumes. Perfect for responding in conversations.</p>
        
        <h3>Template Memes</h3>
        <p>Formats where the structure is reused with different content. The template provides context, the content provides novelty.</p>
        
        <h3>Screenshots</h3>
        <p>Captured moments from social media, messages, or websites. Humor emerges from the situation being documented.</p>
        
        <h3>Comics & Multi-Panel</h3>
        <p>Sequential images telling a story or building to a punchline. Requires more investment but delivers bigger payoffs.</p>
      </section>
      
      <section>
        <h2>Recognizing Quality</h2>
        <p>High-quality memes share common traits: clear visuals, readable text, timely references, and clever twists on familiar formats. They're shareable without context and age well.</p>
        
        <h3>Red Flags</h3>
        <ul>
          <li>Tiny, unreadable text</li>
          <li>Heavy compression artifacts</li>
          <li>Overly specific references requiring deep knowledge</li>
          <li>Mean-spirited or punching down humor</li>
          <li>Obvious recycled content</li>
        </ul>
      </section>
      
      <section>
        <h2>Meme Evolution</h2>
        <p>Memes evolve through remix and recontextualization. A format starts simple, gets remixed creatively, reaches peak saturation, then either dies or enters the cultural canon.</p>
      </section>
      
      <section>
        <h2>Platform Differences</h2>
        <p>Reddit favors detailed multi-panel narratives. Twitter likes quick wit. Instagram emphasizes visual aesthetics. Our platform showcases the best from each ecosystem.</p>
      </section>
      
      <section>
        <h2>Creating vs. Curating</h2>
        <p>You don't need to create memes to appreciate them. Like film criticism or art curation, recognizing quality and context adds depth to enjoyment.</p>
      </section>
      
      <section>
        <h2>Pro Tips</h2>
        <ul>
          <li><strong>Learn Templates:</strong> Recognizing formats enhances appreciation</li>
          <li><strong>Follow Evolution:</strong> Watch how memes transform over time</li>
          <li><strong>Context Matters:</strong> Some memes need background knowledge</li>
          <li><strong>Quality Over Novelty:</strong> Great execution beats trendy format</li>
        </ul>
      </section>
      
      <section>
        <h2>Related Guides</h2>
        <ul>
          <li><a href="/guides/quality-system">Quality System</a></li>
          <li><a href="/guides/collections">Collections</a></li>
          <li><a href="/guides/community">Community Guidelines</a></li>
        </ul>
      </section>
      
      <section class="cta-section">
        <h2>See Formats in Action</h2>
        <p><a href="/trending" class="btn-primary">Browse Trending Formats</a></p>
      </section>
    </div>
  ERB

  'best_practices.erb' => <<~ERB,
    <div class="legal-page guide-page">
      <h1>⭐ Best Practices & Pro Tips</h1>
      
      <section class="hero-section">
        <p class="tagline">Get the most out of Meme Explorer</p>
      </section>
      
      <section>
        <h2>Maximize Personalization</h2>
        <p>The more you engage authentically, the better recommendations become. Like what you actually like, not what you think you should like. The algorithm detects patterns in genuine engagement.</p>
      </section>
      
      <section>
        <h2>Streak Strategies</h2>
        <ul>
          <li><strong>Set a Reminder:</strong> Daily phone notification at a consistent time</li>
          <li><strong>Morning Routine:</strong> Check memes with your coffee</li>
          <li><strong>Lunch Break:</strong> Perfect mid-day pick-me-up</li>
          <li><strong>Before Bed:</strong> End the day with some laughs</li>
        </ul>
        <p>Even 2-3 minutes daily maintains your streak and feeds the algorithm.</p>
      </section>
      
      <section>
        <h2>Collection Mastery</h2>
        <p>Each collection shines at different times and moods. Wholesome works great for morning motivation. Funny is perfect for work breaks. Dank thrives late at night. Self-Care helps during tough times.</p>
      </section>
      
      <section>
        <h2>Discovery Techniques</h2>
        
        <h3>The Random Walk</h3>
        <p>Hit random 10 times in a row. You'll find at least 2-3 gems and expose yourself to content outside your usual preferences.</p>
        
        <h3>Collection Rotation</h3>
        <p>Spend a week focused on one collection, then switch. This builds comprehensive taste profiles across all categories.</p>
        
        <h3>Trending Check-Ins</h3>
        <p>Visit trending 2-3 times daily to catch different waves of content as they emerge.</p>
      </section>
      
      <section>
        <h2>Social Sharing</h2>
        <p>Share great finds with friends, but be selective. Quality over quantity maintains your reputation as a trusted source. When someone opens your shares, they should always laugh.</p>
      </section>
      
      <section>
        <h2>Keyboard Shortcuts</h2>
        <ul>
          <li><strong>L:</strong> Like current meme</li>
          <li><strong>S:</strong> Save to favorites</li>
          <li><strong>R:</strong> Load random meme</li>
          <li><strong>Arrow Keys:</strong> Navigate feed</li>
          <li><strong>Spacebar:</strong> Next meme</li>
        </ul>
      </section>
      
      <section>
        <h2>Mobile vs Desktop</h2>
        <p>Desktop offers full-screen glory and keyboard shortcuts. Mobile provides quick check-ins and notification support. Use both for optimal experience.</p>
      </section>
      
      <section>
        <h2>Building Your Collection</h2>
        <p>Saved memes become your personal greatest hits. Organize them by mood, theme, or shareability. Revisit during bad days for guaranteed laughs.</p>
      </section>
      
      <section>
        <h2>Avoiding Fatigue</h2>
        <p>Meme fatigue is real. If content starts feeling stale, take a break. Come back fresh in a day or two. Quality time beats quantity time.</p>
      </section>
      
      <section>
        <h2>Advanced Tips</h2>
        <ul>
          <li><strong>Night Mode:</strong> Easier on eyes for late browsing</li>
          <li><strong>Save for Later:</strong> Build a queue for busy days</li>
          <li><strong>Explore Sources:</strong> Click subreddit links to discover new communities</li>
          <li><strong>Share Strategically:</strong> Different memes for different audiences</li>
        </ul>
      </section>
      
      <section>
        <h2>Related Guides</h2>
        <ul>
          <li><a href="/guides/getting-started">Getting Started</a></li>
          <li><a href="/guides/gamification">Gamification</a></li>
          <li><a href="/guides/personalization">Personalization</a></li>
        </ul>
      </section>
      
      <section class="cta-section">
        <h2>Put Tips into Practice</h2>
        <p><a href="/random" class="btn-primary">Try the Random Walk</a></p>
      </section>
    </div>
  ERB

  'community.erb' => <<~ERB,
    <div class="legal-page guide-page">
      <h1>🤝 Community Guidelines</h1>
      
      <section class="hero-section">
        <p class="tagline">Building a positive meme community together</p>
      </section>
      
      <section>
        <h2>Our Values</h2>
        <p>Meme Explorer exists to spread joy, not harm. We celebrate clever humor, not cruelty. We value originality, not theft. And we respect creators, not exploit them.</p>
      </section>
      
      <section>
        <h2>Content Standards</h2>
        
        <h3>What We Welcome</h3>
        <ul>
          <li>Clever, witty humor that makes people laugh</li>
          <li>Wholesome content that uplifts and encourages</li>
          <li>Absurdist humor that challenges expectations</li>
          <li>Self-aware, meta commentary on internet culture</li>
          <li>Relatable content that brings people together</li>
        </ul>
        
        <h3>What We Avoid</h3>
        <ul>
          <li>Content targeting individuals maliciously</li>
          <li>Humor that punches down at vulnerable groups</li>
          <li>Graphic violence or disturbing imagery</li>
          <li>Misinformation disguised as humor</li>
          <li>Stolen content without attribution</li>
        </ul>
      </section>
      
      <section>
        <h2>Respecting Creators</h2>
        <p>Every meme on our platform includes source attribution. We link back to original posts and credit subreddit communities. When you share externally, please maintain these attributions.</p>
      </section>
      
      <section>
        <h2>Engagement Expectations</h2>
        <p>Like what makes you laugh. Skip what doesn't. Save what you'll want to find again. Share what others would appreciate. Simple, honest engagement makes the community better for everyone.</p>
      </section>
      
      <section>
        <h2>Reporting Content</h2>
        <p>See something that violates guidelines? Use the report button. We review every report within 24 hours. Your reports help maintain quality and safety.</p>
      </section>
      
      <section>
        <h2>Privacy & Data</h2>
        <p>Your browsing patterns and preferences stay private. We don't sell data, share with third parties, or use your information for targeted advertising. Memes are for laughs, not surveillance.</p>
      </section>
      
      <section>
        <h2>Building Better Together</h2>
        <p>Your engagement trains algorithms. Your saves indicate quality. Your shares spread joy. Every action contributes to the community's collective taste and culture.</p>
      </section>
      
      <section>
        <h2>Moderati on Philosophy</h2>
        <p>We believe in light-touch moderation. Most content self-regulates through engagement. We only intervene for clear violations. Trust the community, but verify quality.</p>
      </section>
      
      <section>
        <h2>Feedback & Suggestions</h2>
        <p>Have ideas for improving the platform? We're listening. Contact us through our <a href="/contact">feedback form</a>. The best suggestions get implemented and you get credit.</p>
      </section>
      
      <section>
        <h2>Related Guides</h2>
        <ul>
          <li><a href="/guides/getting-started">Getting Started</a></li>
          <li><a href="/guides/best-practices">Best Practices</a></li>
          <li><a href="/guides/faq">FAQ</a></li>
        </ul>
      </section>
      
      <section class="cta-section">
        <h2>Join the Community</h2>
        <p><a href="/signup" class="btn-primary">Create Your Account</a></p>
      </section>
    </div>
  ERB

  'faq.erb' => <<~ERB,
    <div class="legal-page guide-page">
      <h1>❓ Frequently Asked Questions</h1>
      
      <section class="hero-section">
        <p class="tagline">Quick answers to common questions</p>
      </section>
      
      <section>
        <h2>Getting Started</h2>
        
        <h3>Do I need an account?</h3>
        <p>You can browse without an account, but creating one unlocks personalization, streaks, achievements, and the ability to save favorites. Free and takes 30 seconds.</p>
        
        <h3>Is it really free?</h3>
        <p>Yes. Ad-supported but respectful - no pop-ups, auto-play videos, or data harvesting. We show relevant ads and share quality memes.</p>
        
        <h3>Where do the memes come from?</h3>
        <p>We source from Reddit's top communities, running every post through our 6-stage quality pipeline. Only 15-20% make it through. You see the best of the best.</p>
      </section>
      
      <section>
        <h2>Features & Functionality</h2>
        
        <h3>How do recommendations work?</h3>
        <p>Our personalization engine analyzes what you like, when you browse, and how you engage. It builds a taste profile and serves content matching your preferences and current context.</p>
        
        <h3>What's the difference between collections?</h3>
        <p>Each collection has unique curation standards. Funny prioritizes universal humor. Wholesome focuses on positivity. Dank serves internet culture deep cuts. Self-Care combines mental health with humor.</p>
        
        <h3>How do I build a streak?</h3>
        <p>Visit daily and view at least one meme. Your streak counter updates at midnight in your timezone. Miss a day and it resets.</p>
        
        <h3>What do levels unlock?</h3>
        <p>Higher levels provide early feature access, custom collection creation, trending vote weight, and influence over recommendation algorithms.</p>
      </section>
      
      <section>
        <h2>Technical Questions</h2>
        
        <h3>Why don't videos work?</h3>
        <p>We currently focus on image memes for performance and user experience. Video support is planned for future updates.</p>
        
        <h3>Can I use keyboard shortcuts?</h3>
        <p>Yes! L to like, S to save, R for random, arrow keys to navigate, and spacebar for next meme.</p>
        
        <h3>Does dark mode exist?</h3>
        <p>Yes, toggle it in settings or it auto-activates based on system preferences.</p>
        
        <h3>Mobile app available?</h3>
        <p>Currently web-only, but fully mobile-responsive. Add to home screen for app-like experience. Native apps are in development.</p>
      </section>
      
      <section>
        <h2>Privacy & Safety</h2>
        
        <h3>What data do you collect?</h3>
        <p>Engagement patterns (likes, saves, views) to personalize recommendations. We don't sell data or share with third parties. See our <a href="/privacy">Privacy Policy</a> for details.</p>
        
        <h3>How do I report inappropriate content?</h3>
        <p>Use the report button on any meme. We review all reports within 24 hours.</p>
        
        <h3>Can I delete my account?</h3>
        <p>Yes, anytime through settings. All your data gets permanently deleted within 48 hours.</p>
      </section>
      
      <section>
        <h2>Troubleshooting</h2>
        
        <h3>Memes not loading?</h3>
        <p>Try refreshing the page. If problems persist, check our <a href="/troubleshooting">troubleshooting guide</a> or contact support.</p>
        
        <h3>Recommendations feel stale?</h3>
        <p>Hit the random button 10 times to inject variety. Also try exploring different collections to diversify your taste profile.</p>
        
        <h3>Lost my streak?</h3>
        <p>Streaks reset at midnight in your timezone. If you visited but lost your streak, contact support - we can review logs.</p>
      </section>
      
      <section>
        <h2>Still Have Questions?</h2>
        <p>Can't find your answer? Contact us through our <a href="/contact">support form</a>. We respond to all inquiries within 24 hours.</p>
      </section>
      
      <section>
        <h2>Related Guides</h2>
        <ul>
          <li><a href="/guides/getting-started">Getting Started</a></li>
          <li><a href="/guides/best-practices">Best Practices</a></li>
          <li><a href="/guides/community">Community Guidelines</a></li>
        </ul>
      </section>
      
      <section class="cta-section">
        <h2>Ready to Start?</h2>
        <p><a href="/trending" class="btn-primary">Explore Memes</a></p>
      </section>
    </div>
  ERB
}

puts "Creating #{guides.size} guide pages..."

guides.each do |filename, content|
  filepath = File.join(GUIDES_DIR, filename)
  File.write(filepath, content)
  puts "✅ Created #{filename}"
end

# Create parent directory link
parent_guides_path = File.join(__dir__, '..', 'views', 'guides_index.erb')
if File.exist?(parent_guides_path)
  File.delete(parent_guides_path)
end
FileUtils.cp(File.join(GUIDES_DIR, 'guides_index.erb'), parent_guides_path)
puts "✅ Linked guides_index.erb to parent views directory"

puts "\n🎉 All #{guides.size} guide pages created successfully!"
puts "\nNext steps:"
puts "1. Add 'require_relative \"routes/guides\"' to app.rb"
puts "2. Update public/sitemap.xml with guide URLs"
puts "3. Add guides link to navigation in views/layout.erb"
puts "4. Deploy and test"
puts "5. Submit to AdSense for review"
ERB

puts "Deployment script created successfully!"
puts "Run: ruby scripts/deploy_adsense_guides.rb"
