# Ad Insertion Helpers
# Provides methods to intelligently insert ads into meme feeds
# Default: Every 12 memes (configurable via ENV)

module AdHelpers
  # ADSENSE POLICY COMPLIANCE: Pages that should never show ads
  # Per Google's policy, ads cannot appear on:
  # - Authentication/behavioral pages
  # - API endpoints
  # - Pages without substantial content
  PAGES_WITHOUT_ADS = [
    '/login',
    '/signup',
    '/auth/reddit',
    '/auth/reddit/callback',
    '/logout',
    '/api/',
    '.json'
  ].freeze
  
  # Minimum number of content items before showing ads
  # Ensures pages have "substantial publisher content" per AdSense policy
  MIN_ITEMS_FOR_ADS = 6
  
  # Get ad frequency from environment or use default
  def ad_frequency
    ENV['AD_FREQUENCY']&.to_i || 12
  end
  
  # Check if user should see ads
  def should_show_ads?
    # Check if ads are globally disabled
    return false if ENV['DISABLE_ADS'] == 'true'
    
    # ADSENSE COMPLIANCE: Check if current page should not have ads
    begin
      current_path = request.path_info
      return false if PAGES_WITHOUT_ADS.any? { |path| current_path.start_with?(path) || current_path.include?(path) }
    rescue => e
      AppLogger.warn("[AdHelpers] Error checking ad eligibility: #{e.message}")
      return false
    end
    
    # All users see ads (no premium subscription feature)
    true
  end
  
  # Check if ads should be shown for specific content
  # ADSENSE COMPLIANCE: Only show ads when sufficient content exists
  def should_show_ads_for_content?(items)
    return false unless should_show_ads?
    return false if items.nil? || items.empty?
    return false if items.size < MIN_ITEMS_FOR_ADS
    true
  end
  
  # Determine if an ad should be shown at this position
  # @param index [Integer] Current item index (0-based)
  # @return [Boolean] True if ad should be shown before this item
  def show_ad_at_position?(index)
    return false if index == 0 # Never show ad as first item
    return false unless should_show_ads?
    
    # Show ad every N memes (e.g., positions 11, 23, 35... for frequency=12)
    ((index + 1) % ad_frequency) == 0
  end
  
  # Generate ad HTML for insertion
  # @param ad_index [Integer] Sequential ad number (for tracking)
  # @param format [String] Ad format: 'banner', 'square', 'native'
  # @param position [String] Grid position: 'top', 'bottom', 'left', 'right', 'left-1', 'left-2', 'right-1', 'right-2', etc.
  # @return [String] HTML for ad unit
  # NOTE on "relevance": AdSense does not accept a publisher-supplied
  # content-category attribute on the ad tag (verified against Google's
  # own docs - "How ads are targeted to your site"). Its contextual
  # targeting is entirely automatic: it crawls the real, visible text on
  # the page (keywords, headings, link structure) to decide what ads to
  # serve. There is no `data-*` shortcut around that. The one thing we
  # actually control that affects ad relevance is making sure real,
  # readable content - the meme's subreddit/category and title - is
  # genuinely present as visible text near the ad slot for AdSense's
  # crawler to read, which views/random/metadata.erb already renders
  # (collection_name_for_subreddit, the meme title). No fabricated
  # attribute belongs here.
  def render_ad_unit(ad_index = 0, format: 'square', position: nil)
    ad_id = "ad-unit-#{ad_index}"

    case format
    when 'banner'
      width = '728px'
      height = '90px'
      slot_id = ENV['GOOGLE_AD_SLOT_BANNER'] || 'BANNER_SLOT_ID'
    when 'native'
      width = '100%'
      height = 'auto'
      slot_id = ENV['GOOGLE_AD_SLOT_NATIVE'] || 'NATIVE_SLOT_ID'
    when 'vertical'
      # BUG FIX: this format was passed by views/random.erb for the left/
      # right sidebar ad columns, but this case statement never handled
      # it - it silently fell through to the `else` (square) branch,
      # rendering a fixed 300x250 unit inside a narrow vertical column
      # that /css/ads.css's own .ad-sidebar-sticky rule sizes at 300px
      # wide with room for a taller unit. Use the real IAB "half page"
      # vertical dimensions instead.
      width = '300px'
      height = '600px'
      slot_id = ENV['GOOGLE_AD_SLOT_VERTICAL'] || ENV['GOOGLE_AD_SLOT_SQUARE'] || 'VERTICAL_SLOT_ID'
    else # square (default for meme feeds)
      width = '300px'
      height = '250px'
      slot_id = ENV['GOOGLE_AD_SLOT_SQUARE'] || 'SQUARE_SLOT_ID'
    end

    # Add grid position attribute if specified
    position_attr = position ? " data-position=\"#{position}\"" : ""

    # Return placeholder if AdSense not configured
    unless ENV['GOOGLE_ADSENSE_CLIENT']
      return render_ad_placeholder(ad_id, width, height, position)
    end

    # Render actual AdSense unit
    <<-HTML
      <div class="ad-container" data-ad-index="#{ad_index}"#{position_attr}>
        <div class="ad-label">Advertisement</div>
        <ins class="adsbygoogle"
             style="display:inline-block;width:#{width};height:#{height}"
             data-ad-client="#{ENV['GOOGLE_ADSENSE_CLIENT']}"
             data-ad-slot="#{slot_id}"
             data-ad-format="#{format == 'native' ? 'auto' : 'rectangle'}"
             data-full-width-responsive="#{format == 'native' ? 'true' : 'false'}"></ins>
      </div>
    HTML
  end

  # Render placeholder ad (for development/testing)
  def render_ad_placeholder(ad_id, width, height, position = nil)
    position_attr = position ? " data-position=\"#{position}\"" : ""

    <<-HTML
      <div class="ad-container ad-placeholder" id="#{ad_id}" data-width="#{width}" data-height="#{height}"#{position_attr}>
        <div class="ad-label">Advertisement</div>
        <div class="ad-demo-content" style="width:#{width};height:#{height};">
          <div class="ad-demo-text">
            <strong>Ad Placeholder</strong><br>
            <small>Configure GOOGLE_ADSENSE_CLIENT in .env</small><br>
            <span style="font-size: 11px; opacity: 0.7;">#{width} × #{height}</span>
            #{position ? "<br><span style='font-size: 10px; color: #999;'>Grid: #{position}</span>" : ""}
          </div>
        </div>
      </div>
    HTML
  end
  
  # Insert ads into an array of items
  # @param items [Array] Array of memes or other content
  # @return [Array] Items with ads inserted at appropriate positions
  def insert_ads_into_array(items)
    # ADSENSE COMPLIANCE: No ads on empty or low-content pages
    return items if items.nil? || items.empty?
    return items if items.size < MIN_ITEMS_FOR_ADS
    return items unless should_show_ads?
    
    result = []
    ad_count = 0
    
    items.each_with_index do |item, index|
      # Insert ad before this item if appropriate
      if show_ad_at_position?(index)
        result << { type: 'ad', ad_index: ad_count, format: 'square' }
        ad_count += 1
      end
      
      # Add the actual item
      result << { type: 'meme', data: item }
    end
    
    result
  end
  
  # Get ad analytics tracking attributes
  def ad_tracking_attributes(ad_index)
    {
      'data-track-event': 'ad_impression',
      'data-ad-position': ad_index,
      'data-ad-frequency': ad_frequency
    }
  end
  
  # Check if ad blocker is detected (client-side)
  def ad_blocker_detection_script
    <<-HTML
      <script>
        // Ad blocker detection
        (function() {
          var adBlockDetected = false;
          var testAd = document.createElement('div');
          testAd.innerHTML = '&nbsp;';
          testAd.className = 'adsbox ad-placement ad-placeholder';
          testAd.style.position = 'absolute';
          testAd.style.left = '-9999px';
          document.body.appendChild(testAd);
          
          setTimeout(function() {
            if (testAd.offsetHeight === 0 || testAd.clientHeight === 0) {
              adBlockDetected = true;
              console.log('ℹ️ [ADS] Ad blocker detected');
              
              // Track for analytics
              if (window.activityTracker) {
                window.activityTracker.track('ad_blocker_detected');
              }
            }
            document.body.removeChild(testAd);
          }, 100);
        })();
      </script>
    HTML
  end
# ============================================
# REVENUE OPTIMIZATION METHODS - Added 2026-06-04
# ============================================

# NOTE: this file used to also define `render_ad`, which called
# `RevenueTracker.record_ad_impression` and rendered `erb :_ad` - neither
# `RevenueTracker` nor `views/_ad.erb` exist anywhere in this codebase.
# `render_ad` was never actually called by any view, so it never crashed
# in practice, but it was a landmine for the next person who wired it up.
# Removed rather than left as dead code referencing two things that don't
# exist. render_sidebar_ad/render_hero_ad/render_trending_ad/
# render_anchor_ad below are real and functional (they only call
# render_ad_unit, defined above) - render_anchor_ad is now wired into
# views/random.erb as the mobile ad surface, since side ads are correctly
# hidden on mobile via /css/ads.css and mobile had no ad slot at all
# without it.

def render_sidebar_ad
  return '' unless should_show_ads?
  
  <<-HTML
    <div class="sidebar-ad-container">
      <div class="ad-sidebar-sticky">
        #{render_ad_unit(999, format: 'square', position: 'sidebar')}
      </div>
    </div>
  HTML
end

# Render hero/top ad (premium position)
def render_hero_ad
  return '' unless should_show_ads?
  
  <<-HTML
    <div class="ad-hero-position">
      #{render_ad_unit(1, format: 'banner', position: 'hero')}
    </div>
  HTML
end

# Render after-trending ad
def render_trending_ad
  return '' unless should_show_ads?
  
  <<-HTML
    <div class="ad-after-trending">
      #{render_ad_unit(2, format: 'square', position: 'trending')}
    </div>
  HTML
end

# Render anchor/footer ad
def render_anchor_ad
  return '' unless should_show_ads?

  # 'native' here, not 'banner': this sticky bar spans full width on both
  # mobile (its actual, primary use case - see views/random.erb) and
  # desktop. 'banner' renders a fixed 728x90 unit with
  # data-full-width-responsive="false" - correct for a real desktop
  # leaderboard slot, but a fixed-width unit that would either overflow
  # or leave awkward empty space in a sticky bar meant to fit any
  # viewport. 'native' is the one format in render_ad_unit that's
  # actually responsive (width: 100%, data-full-width-responsive="true").
  <<-HTML
    <div class="ad-anchor-bottom">
      #{render_ad_unit(998, format: 'native', position: 'anchor')}
    </div>
  HTML
end

end